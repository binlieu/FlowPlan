import Foundation
import Observation
import OSLog
import SwiftData
import FlowPlanDomain

enum FinanceRepositoryError: Error, Equatable {
    case dataLoadFailed
    case invalidBudgetScope
    case invalidBillOccurrence
    case invalidIncomeOccurrence
    case nonPositiveAmount
    case recordNotFound
    case settlementAlreadyRecorded
    case settlementMustUseDedicatedMethod
}

@Observable
@MainActor
final class FinanceRepository {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let shouldFailReads: () -> Bool

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FlowPlan",
        category: "Repository"
    )

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        shouldFailReads: @escaping () -> Bool = { false }
    ) {
        self.context = context
        self.calendar = calendar
        self.now = now
        self.shouldFailReads = shouldFailReads
    }

    func projectionInput(
        for month: MonthKey,
        referenceDate: Date,
        configuration: ProjectionConfiguration
    ) -> ProjectionInput {
        switch projectionInputResult(
            for: month,
            referenceDate: referenceDate,
            configuration: configuration
        ) {
        case .success(let input):
            return input
        case .failure:
            return emptyProjectionInput(
                for: month,
                referenceDate: referenceDate,
                configuration: configuration
            )
        }
    }

    func projectionInputResult(
        for month: MonthKey,
        referenceDate: Date,
        configuration: ProjectionConfiguration
    ) -> Result<ProjectionInput, FinanceRepositoryError> {
        do {
            return .success(
                ProjectionInput(
                    month: month,
                    referenceDate: referenceDate,
                    startingBalance: try startingBalanceValue(for: month),
                    incomeSources: try incomeSourceValues(),
                    bills: try billValues(),
                    budgets: try budgetValues(for: month),
                    savingsPlans: try savingsPlanValues(),
                    transactions: try transactionValues(in: month),
                    calendar: calendar,
                    configuration: configuration
                )
            )
        } catch {
            Self.logger.error("Unable to load projection data.")
            return .failure((error as? FinanceRepositoryError) ?? .dataLoadFailed)
        }
    }

    func transactions(in month: MonthKey) -> [TransactionSnapshot] {
        read(or: []) {
            try transactionValues(in: month)
        }
    }

    private func transactionValues(in month: MonthKey) throws -> [TransactionSnapshot] {
        let startDate = month.startDate(calendar: calendar)
        let monthEnd = month.endDate(calendar: calendar)
        guard let endExclusiveDate = calendar.date(byAdding: .second, value: 1, to: monthEnd) else {
            throw FinanceRepositoryError.dataLoadFailed
        }

        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.date >= startDate && transaction.date < endExclusiveDate
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\TransactionEntity.date, order: .reverse)]
        )
        return try fetchOrThrow(descriptor).map { $0.toDomain() }
    }

    func incomeSources() -> [PlannedIncome] {
        read(or: []) {
            try incomeSourceValues()
        }
    }

    private func incomeSourceValues() throws -> [PlannedIncome] {
        let descriptor = FetchDescriptor<IncomeSourceEntity>(
            sortBy: [SortDescriptor(\IncomeSourceEntity.name)]
        )
        return try fetchOrThrow(descriptor).map { $0.toDomain() }
    }

    func bills() -> [PlannedBill] {
        read(or: []) {
            try billValues()
        }
    }

    private func billValues() throws -> [PlannedBill] {
        let descriptor = FetchDescriptor<RecurringBillEntity>(
            sortBy: [SortDescriptor(\RecurringBillEntity.name)]
        )
        return try fetchOrThrow(descriptor).map { $0.toDomain() }
    }

    func savingsPlans() -> [SavingsPlan] {
        read(or: []) {
            try savingsPlanValues()
        }
    }

    private func savingsPlanValues() throws -> [SavingsPlan] {
        let predicate = #Predicate<SavingsGoalEntity> { goal in
            goal.isActive
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\SavingsGoalEntity.name)]
        )
        return try fetchOrThrow(descriptor).map { $0.toDomain() }
    }

    func budgets(for month: MonthKey) -> [BudgetAllocation] {
        read(or: []) {
            try budgetValues(for: month)
        }
    }

    private func budgetValues(for month: MonthKey) throws -> [BudgetAllocation] {
        let year = month.year
        let monthNumber = month.month
        let overridePredicate = #Predicate<BudgetEntity> { budget in
            budget.scopeYear == year && budget.scopeMonth == monthNumber
        }
        let overrideDescriptor = FetchDescriptor(
            predicate: overridePredicate,
            sortBy: [SortDescriptor(\BudgetEntity.category)]
        )
        let overrides: [BudgetEntity] = try fetchOrThrow(overrideDescriptor)

        if !overrides.isEmpty {
            return overrides.map { $0.toDomain() }
        }

        let defaultPredicate = #Predicate<BudgetEntity> { budget in
            budget.scopeYear == nil && budget.scopeMonth == nil
        }
        let defaultDescriptor = FetchDescriptor(
            predicate: defaultPredicate,
            sortBy: [SortDescriptor(\BudgetEntity.category)]
        )
        return try fetchOrThrow(defaultDescriptor).map { $0.toDomain() }
    }

    func startingBalance(for month: MonthKey) -> Decimal {
        read(or: .zero) {
            try startingBalanceValue(for: month)
        }
    }

    private func startingBalanceValue(for month: MonthKey) throws -> Decimal {
        let year = month.year
        let monthNumber = month.month
        let predicate = #Predicate<MonthSettingsEntity> { settings in
            settings.year == year && settings.month == monthNumber
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try fetchOrThrow(descriptor).first?.startingBalance ?? .zero
    }

    func addTransaction(_ transaction: TransactionEntity) throws {
        guard transaction.settlesBillID == nil, transaction.settlesIncomeID == nil else {
            throw FinanceRepositoryError.settlementMustUseDedicatedMethod
        }

        transaction.amount = transaction.amount.positiveMagnitude
        transaction.category = try canonicalCategory(transaction.category)
        transaction.updatedAt = now()
        context.insert(transaction)
        try context.save()
    }

    func updateTransaction(_ transaction: TransactionEntity) throws {
        guard transaction.settlesBillID == nil, transaction.settlesIncomeID == nil else {
            throw FinanceRepositoryError.settlementMustUseDedicatedMethod
        }

        let stored: TransactionEntity = try existing(id: transaction.id)
        stored.date = transaction.date
        stored.amount = transaction.amount.positiveMagnitude
        stored.type = transaction.type
        stored.category = try canonicalCategory(transaction.category)
        stored.detail = transaction.detail
        stored.note = transaction.note
        stored.account = transaction.account
        stored.updatedAt = now()
        try context.save()
    }

    func deleteTransaction(id: UUID) throws {
        let transaction: TransactionEntity = try existing(id: id)
        transaction.updatedAt = now()
        context.delete(transaction)
        try context.save()
    }

    func addIncomeSource(_ source: IncomeSourceEntity) throws {
        source.expectedAmount = source.expectedAmount.positiveMagnitude
        source.updatedAt = now()
        context.insert(source)
        try context.save()
    }

    func updateIncomeSource(_ source: IncomeSourceEntity) throws {
        let stored: IncomeSourceEntity = try existing(id: source.id)
        stored.name = source.name
        stored.expectedAmount = source.expectedAmount.positiveMagnitude
        stored.frequency = source.frequency
        stored.anchorDate = source.anchorDate
        stored.endDate = source.endDate
        stored.isActive = source.isActive
        stored.updatedAt = now()
        try context.save()
    }

    func deleteIncomeSource(id: UUID) throws {
        let source: IncomeSourceEntity = try existing(id: id)
        let linkedTransactions = try transactionsLinkedToIncome(id)
        let timestamp = now()

        for transaction in linkedTransactions {
            transaction.settlesIncomeID = nil
            transaction.updatedAt = timestamp
        }

        source.updatedAt = timestamp
        context.delete(source)
        try context.save()
    }

    func addBill(_ bill: RecurringBillEntity) throws {
        bill.amount = bill.amount.positiveMagnitude
        bill.category = try canonicalCategory(bill.category)
        bill.updatedAt = now()
        context.insert(bill)
        try context.save()
    }

    func updateBill(_ bill: RecurringBillEntity) throws {
        let stored: RecurringBillEntity = try existing(id: bill.id)
        stored.name = bill.name
        stored.amount = bill.amount.positiveMagnitude
        stored.amountType = bill.amountType
        stored.category = try canonicalCategory(bill.category)
        stored.frequency = bill.frequency
        stored.anchorDate = bill.anchorDate
        stored.endDate = bill.endDate
        stored.isAutoPay = bill.isAutoPay
        stored.isActive = bill.isActive
        stored.updatedAt = now()
        try context.save()
    }

    func deleteBill(id: UUID) throws {
        let bill: RecurringBillEntity = try existing(id: id)
        let linkedTransactions = try transactionsLinkedToBill(id)
        let timestamp = now()

        for transaction in linkedTransactions {
            transaction.settlesBillID = nil
            transaction.updatedAt = timestamp
        }

        bill.updatedAt = timestamp
        context.delete(bill)
        try context.save()
    }

    func addBudget(_ budget: BudgetEntity) throws {
        try validateScope(year: budget.scopeYear, month: budget.scopeMonth)
        budget.monthlyLimit = budget.monthlyLimit.positiveMagnitude
        budget.category = try canonicalCategory(budget.category)
        budget.updatedAt = now()
        context.insert(budget)
        try context.save()
    }

    func updateBudget(_ budget: BudgetEntity) throws {
        try validateScope(year: budget.scopeYear, month: budget.scopeMonth)
        let stored: BudgetEntity = try existing(id: budget.id)
        stored.category = try canonicalCategory(budget.category)
        stored.monthlyLimit = budget.monthlyLimit.positiveMagnitude
        stored.scopeYear = budget.scopeYear
        stored.scopeMonth = budget.scopeMonth
        stored.updatedAt = now()
        try context.save()
    }

    func deleteBudget(id: UUID) throws {
        let budget: BudgetEntity = try existing(id: id)
        budget.updatedAt = now()
        context.delete(budget)
        try context.save()
    }

    func addSavingsGoal(_ goal: SavingsGoalEntity) throws {
        normalize(goal)
        goal.updatedAt = now()
        context.insert(goal)
        try context.save()
    }

    func updateSavingsGoal(_ goal: SavingsGoalEntity) throws {
        let stored: SavingsGoalEntity = try existing(id: goal.id)
        stored.name = goal.name
        stored.targetAmount = goal.targetAmount.positiveMagnitude
        stored.monthlyTarget = goal.monthlyTarget.positiveMagnitude
        stored.currentAmount = goal.currentAmount.positiveMagnitude
        stored.targetDate = goal.targetDate
        stored.isActive = goal.isActive
        stored.updatedAt = now()
        try context.save()
    }

    func deleteSavingsGoal(id: UUID) throws {
        let goal: SavingsGoalEntity = try existing(id: id)
        goal.updatedAt = now()
        context.delete(goal)
        try context.save()
    }

    func setStartingBalance(_ balance: Decimal, for month: MonthKey) throws {
        let year = month.year
        let monthNumber = month.month
        let predicate = #Predicate<MonthSettingsEntity> { settings in
            settings.year == year && settings.month == monthNumber
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let timestamp = now()

        if let settings = try context.fetch(descriptor).first {
            settings.startingBalance = balance
            settings.updatedAt = timestamp
        } else {
            context.insert(
                MonthSettingsEntity(
                    year: year,
                    month: monthNumber,
                    startingBalance: balance,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }

        try context.save()
    }

    func markBillPaid(
        billID: UUID,
        occurrence: Date,
        amount: Decimal,
        on date: Date
    ) throws {
        guard amount > .zero else {
            throw FinanceRepositoryError.nonPositiveAmount
        }

        let bill: RecurringBillEntity = try existing(id: billID)
        let occurrenceMonth = MonthKey(date: occurrence, calendar: calendar)
        guard MonthKey(date: date, calendar: calendar) == occurrenceMonth else {
            throw FinanceRepositoryError.invalidBillOccurrence
        }

        let occurrences = bill.toDomain().recurrence.occurrences(
            in: occurrenceMonth,
            calendar: calendar
        )
        guard let occurrenceIndex = occurrences.firstIndex(of: occurrence) else {
            throw FinanceRepositoryError.invalidBillOccurrence
        }

        let settlementCount = try transactionValues(in: occurrenceMonth).count {
            $0.settlesBillID == billID
        }
        guard settlementCount == occurrenceIndex else {
            throw FinanceRepositoryError.settlementAlreadyRecorded
        }

        let timestamp = now()
        let transaction = TransactionEntity(
            date: date,
            amount: amount,
            type: .expense,
            category: try canonicalCategory(bill.category),
            detail: bill.name,
            settlesBillID: billID,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        context.insert(transaction)
        try context.save()
    }

    func markIncomeReceived(incomeID: UUID, amount: Decimal, on date: Date) throws {
        guard amount > .zero else {
            throw FinanceRepositoryError.nonPositiveAmount
        }

        let source: IncomeSourceEntity = try existing(id: incomeID)
        let month = MonthKey(date: date, calendar: calendar)
        let occurrences = source.toDomain().recurrence.occurrences(in: month, calendar: calendar)
        let settlementCount = try transactionValues(in: month).count {
            $0.settlesIncomeID == incomeID
        }
        guard settlementCount < occurrences.count else {
            throw FinanceRepositoryError.settlementAlreadyRecorded
        }

        try markIncomeReceived(
            incomeID: incomeID,
            occurrence: occurrences[settlementCount],
            amount: amount,
            on: date
        )
    }

    func markIncomeReceived(
        incomeID: UUID,
        occurrence: Date,
        amount: Decimal,
        on date: Date
    ) throws {
        guard amount > .zero else {
            throw FinanceRepositoryError.nonPositiveAmount
        }

        let source: IncomeSourceEntity = try existing(id: incomeID)
        let occurrenceMonth = MonthKey(date: occurrence, calendar: calendar)
        guard MonthKey(date: date, calendar: calendar) == occurrenceMonth else {
            throw FinanceRepositoryError.invalidIncomeOccurrence
        }

        let occurrences = source.toDomain().recurrence.occurrences(
            in: occurrenceMonth,
            calendar: calendar
        )
        guard let occurrenceIndex = occurrences.firstIndex(of: occurrence) else {
            throw FinanceRepositoryError.invalidIncomeOccurrence
        }

        let settlementCount = try transactionValues(in: occurrenceMonth).count {
            $0.settlesIncomeID == incomeID
        }
        guard settlementCount == occurrenceIndex else {
            throw FinanceRepositoryError.settlementAlreadyRecorded
        }

        let timestamp = now()
        let transaction = TransactionEntity(
            date: date,
            amount: amount,
            type: .income,
            category: "Income",
            detail: source.name,
            settlesIncomeID: incomeID,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        context.insert(transaction)
        try context.save()
    }

    func add(_ transaction: TransactionEntity) throws {
        try addTransaction(transaction)
    }

    func add(_ source: IncomeSourceEntity) throws {
        try addIncomeSource(source)
    }

    func add(_ bill: RecurringBillEntity) throws {
        try addBill(bill)
    }

    func add(_ budget: BudgetEntity) throws {
        try addBudget(budget)
    }

    func add(_ goal: SavingsGoalEntity) throws {
        try addSavingsGoal(goal)
    }

    func update(_ transaction: TransactionEntity) throws {
        try updateTransaction(transaction)
    }

    func update(_ source: IncomeSourceEntity) throws {
        try updateIncomeSource(source)
    }

    func update(_ bill: RecurringBillEntity) throws {
        try updateBill(bill)
    }

    func update(_ budget: BudgetEntity) throws {
        try updateBudget(budget)
    }

    func update(_ goal: SavingsGoalEntity) throws {
        try updateSavingsGoal(goal)
    }

    func delete(_ transaction: TransactionEntity) throws {
        try deleteTransaction(id: transaction.id)
    }

    func delete(_ source: IncomeSourceEntity) throws {
        try deleteIncomeSource(id: source.id)
    }

    func delete(_ bill: RecurringBillEntity) throws {
        try deleteBill(id: bill.id)
    }

    func delete(_ budget: BudgetEntity) throws {
        try deleteBudget(id: budget.id)
    }

    func delete(_ goal: SavingsGoalEntity) throws {
        try deleteSavingsGoal(id: goal.id)
    }

    private func validateScope(year: Int?, month: Int?) throws {
        guard (year == nil) == (month == nil) else {
            throw FinanceRepositoryError.invalidBudgetScope
        }

        if let year, let month {
            let normalized = MonthKey(year: year, month: month)
            guard normalized.year == year, normalized.month == month else {
                throw FinanceRepositoryError.invalidBudgetScope
            }
        }
    }

    private func normalize(_ goal: SavingsGoalEntity) {
        goal.targetAmount = goal.targetAmount.positiveMagnitude
        goal.monthlyTarget = goal.monthlyTarget.positiveMagnitude
        goal.currentAmount = goal.currentAmount.positiveMagnitude
    }

    private func canonicalCategory(_ category: String) throws -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCategory.isEmpty else {
            return trimmedCategory
        }

        let storedCategories = try fetchOrThrow(FetchDescriptor<BudgetEntity>()).map(\.category)
            + fetchOrThrow(FetchDescriptor<RecurringBillEntity>()).map(\.category)
            + fetchOrThrow(FetchDescriptor<TransactionEntity>()).map(\.category)
        let identity = categoryIdentity(trimmedCategory)

        return storedCategories.first {
            categoryIdentity($0) == identity
        }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmedCategory
    }

    private func categoryIdentity(_ category: String) -> String {
        category
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private func transactionsLinkedToBill(_ id: UUID) throws -> [TransactionEntity] {
        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.settlesBillID == id
        }
        return try fetchOrThrow(FetchDescriptor(predicate: predicate))
    }

    private func transactionsLinkedToIncome(_ id: UUID) throws -> [TransactionEntity] {
        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.settlesIncomeID == id
        }
        return try fetchOrThrow(FetchDescriptor(predicate: predicate))
    }

    private func existing<Model: IdentifiedPersistentModel>(id: UUID) throws -> Model {
        let predicate = #Predicate<Model> { model in
            model.id == id
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let model = try fetchOrThrow(descriptor).first else {
            throw FinanceRepositoryError.recordNotFound
        }
        return model
    }

    private func fetchOrThrow<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>
    ) throws -> [Model] {
        guard !shouldFailReads() else {
            throw FinanceRepositoryError.dataLoadFailed
        }

        do {
            return try context.fetch(descriptor)
        } catch {
            throw FinanceRepositoryError.dataLoadFailed
        }
    }

    private func read<Value>(or fallback: Value, _ operation: () throws -> Value) -> Value {
        do {
            return try operation()
        } catch {
            Self.logger.error("A repository read failed.")
            return fallback
        }
    }

    private func emptyProjectionInput(
        for month: MonthKey,
        referenceDate: Date,
        configuration: ProjectionConfiguration
    ) -> ProjectionInput {
        ProjectionInput(
            month: month,
            referenceDate: referenceDate,
            startingBalance: .zero,
            calendar: calendar,
            configuration: configuration
        )
    }
}

private protocol IdentifiedPersistentModel: PersistentModel {
    var id: UUID { get }
}

extension TransactionEntity: IdentifiedPersistentModel {}
extension IncomeSourceEntity: IdentifiedPersistentModel {}
extension RecurringBillEntity: IdentifiedPersistentModel {}
extension BudgetEntity: IdentifiedPersistentModel {}
extension SavingsGoalEntity: IdentifiedPersistentModel {}

private extension Decimal {
    var positiveMagnitude: Decimal {
        self < .zero ? -self : self
    }
}
