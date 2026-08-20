import Foundation
import Observation
import OSLog
import SwiftData
import FlowPlanDomain

enum FinanceRepositoryError: Error, Equatable {
    case duplicateAccountName
    case emptyAccountName
    case dataLoadFailed
    case invalidBudgetScope
    case invalidBillOccurrence
    case invalidIncomeOccurrence
    case nonPositiveAmount
    case recordNotFound
    case settlementAlreadyRecorded
    case settlementMustUseDedicatedMethod
}

extension FinanceRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .duplicateAccountName:
            return "An account with this name already exists."
        case .emptyAccountName:
            return "The account name is empty."
        case .dataLoadFailed:
            return "The saved data could not be loaded."
        case .invalidBudgetScope:
            return "The budget month is invalid."
        case .invalidBillOccurrence:
            return "The selected bill occurrence is invalid."
        case .invalidIncomeOccurrence:
            return "The selected income occurrence is invalid."
        case .nonPositiveAmount:
            return "The amount must be greater than zero."
        case .recordNotFound:
            return "The record no longer exists."
        case .settlementAlreadyRecorded:
            return "This payment or deposit was already recorded."
        case .settlementMustUseDedicatedMethod:
            return "This planned payment or deposit must be recorded from its matching occurrence."
        }
    }
}

struct StartingBalanceResolution: Equatable {
    enum Source: Equatable {
        case explicit
        case rolledOver(from: MonthKey)
        case unset
    }

    let amount: Decimal
    let source: Source
}

@Observable
@MainActor
final class FinanceRepository {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let shouldFailReads: () -> Bool
    @ObservationIgnored private var successfulWriteHandler: () -> Void = {}

    private static let carryBalanceForwardKey = "carryBalanceForward"
    private static let rolloverMonthLimit = 24

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FlowPlan",
        category: "Repository"
    )

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        shouldFailReads: @escaping () -> Bool = { false }
    ) {
        self.context = context
        self.calendar = calendar
        self.userDefaults = userDefaults
        self.now = now
        self.shouldFailReads = shouldFailReads

        do {
            try seedAccountsFromTransactions()
        } catch {
            Self.logger.error("Unable to seed account names from existing transactions.")
        }
    }

    func setSuccessfulWriteHandler(_ handler: @escaping () -> Void) {
        successfulWriteHandler = handler
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
                    debts: try debtValuesForProjection(
                        startingIn: min(
                            month,
                            MonthKey(date: referenceDate, calendar: calendar)
                        )
                    ),
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
        try transactionEntities(in: month).map { $0.toDomain() }
    }

    private func transactionEntities(in month: MonthKey) throws -> [TransactionEntity] {
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
        return try fetchOrThrow(descriptor)
    }

    func transactionAccountNames(in month: MonthKey) -> [UUID: String] {
        read(or: [:]) {
            Dictionary(
                uniqueKeysWithValues: try transactionEntities(in: month).map {
                    ($0.id, $0.account)
                }
            )
        }
    }

    func accounts() -> [Account] {
        read(or: []) {
            let descriptor = FetchDescriptor<AccountEntity>(
                sortBy: [SortDescriptor(\AccountEntity.name)]
            )
            return try fetchOrThrow(descriptor)
                .map { $0.toValue() }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        }
    }

    func addAccount(named name: String) throws {
        try write {
            let trimmedName = AccountName.trimmed(name)
            guard !trimmedName.isEmpty else {
                throw FinanceRepositoryError.emptyAccountName
            }

            let identity = AccountName.identity(trimmedName)
            let existingAccounts = try fetchOrThrow(FetchDescriptor<AccountEntity>())
            guard !existingAccounts.contains(where: {
                AccountName.identity($0.name) == identity
            }) else {
                throw FinanceRepositoryError.duplicateAccountName
            }

            context.insert(AccountEntity(name: trimmedName, createdAt: now()))
        }
    }

    func deleteAccount(_ account: Account) throws {
        try write {
            let stored: AccountEntity = try existing(id: account.id)
            let identity = AccountName.identity(stored.name)
            let timestamp = now()
            let transactions = try fetchOrThrow(FetchDescriptor<TransactionEntity>())

            // Deleting an account only removes its label. Financial transactions are never deleted.
            for transaction in transactions
                where AccountName.identity(transaction.account) == identity {
                transaction.account = ""
                transaction.updatedAt = timestamp
            }

            context.delete(stored)
        }
    }

    func transactionCount(forAccount account: Account) -> Int {
        transactionCount(forAccount: account.name)
    }

    func transactionCount(forAccount accountName: String) -> Int {
        read(or: 0) {
            let identity = AccountName.identity(accountName)
            return try fetchOrThrow(FetchDescriptor<TransactionEntity>()).count {
                AccountName.identity($0.account) == identity
            }
        }
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

    func debts() -> [Debt] {
        read(or: []) {
            try debtValues()
        }
    }

    private func debtValues() throws -> [Debt] {
        try debtEntities().map { $0.toDomain() }
    }

    private func debtEntities() throws -> [DebtEntity] {
        let descriptor = FetchDescriptor<DebtEntity>(
            sortBy: [SortDescriptor(\DebtEntity.name)]
        )
        return try fetchOrThrow(descriptor)
    }

    private func debtValuesForProjection(startingIn month: MonthKey) throws -> [Debt] {
        let debtPayments = try transactionValues(in: month).filter {
            $0.type == .expense && $0.settlesDebtID != nil
        }
        let paymentsByDebtID = Dictionary(grouping: debtPayments) { $0.settlesDebtID }
        let schedule = DebtSchedule()

        return try debtEntities().map { entity in
            let debt = entity.toDomain()
            let payments = paymentsByDebtID[debt.id, default: []]
            let projectionBalance = payments.reduce(debt.currentBalance) { balance, payment in
                schedule.balanceBeforePayment(
                    of: payment.amount,
                    remainingBalance: balance,
                    annualInterestRate: debt.annualInterestRate
                )
            }

            return Debt(
                id: debt.id,
                name: debt.name,
                currentBalance: projectionBalance,
                annualInterestRate: debt.annualInterestRate,
                monthlyPayment: debt.monthlyPayment,
                category: debt.category,
                dueDay: debt.dueDay,
                isAutoPay: debt.isAutoPay,
                isPaidThroughBills: debt.isPaidThroughBills,
                isActive: debt.isActive
            )
        }
    }

    func debtOriginalBalances() -> [UUID: Decimal] {
        read(or: [:]) {
            Dictionary(
                uniqueKeysWithValues: try fetchOrThrow(FetchDescriptor<DebtEntity>()).map {
                    ($0.id, $0.originalBalance)
                }
            )
        }
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
        startingBalanceResolution(for: month).amount
    }

    func startingBalanceResolution(for month: MonthKey) -> StartingBalanceResolution {
        read(or: StartingBalanceResolution(amount: .zero, source: .unset)) {
            try startingBalanceResolutionValue(for: month)
        }
    }

    private func startingBalanceValue(for month: MonthKey) throws -> Decimal {
        try startingBalanceResolutionValue(for: month).amount
    }

    private func startingBalanceResolutionValue(
        for month: MonthKey
    ) throws -> StartingBalanceResolution {
        let earliestMonth = month.adding(months: -Self.rolloverMonthLimit)
        let earliestYear = earliestMonth.year
        let earliestMonthNumber = earliestMonth.month
        let targetYear = month.year
        let targetMonthNumber = month.month
        let predicate = #Predicate<MonthSettingsEntity> { settings in
            (settings.year > earliestYear
                || (settings.year == earliestYear && settings.month >= earliestMonthNumber))
                && (settings.year < targetYear
                    || (settings.year == targetYear && settings.month <= targetMonthNumber))
        }
        let settings = try fetchOrThrow(FetchDescriptor(predicate: predicate))
        let settingsByMonth = Dictionary(
            uniqueKeysWithValues: settings.map { entity in
                let value = entity.toDomain()
                return (value.month, value.startingBalance)
            }
        )

        if let explicitBalance = settingsByMonth[month] {
            return StartingBalanceResolution(amount: explicitBalance, source: .explicit)
        }

        guard carryBalanceForward else {
            return StartingBalanceResolution(amount: .zero, source: .unset)
        }

        let anchorMonth = (1...Self.rolloverMonthLimit)
            .lazy
            .map { month.adding(months: -$0) }
            .first { settingsByMonth[$0] != nil }

        guard
            let anchorMonth,
            let anchorBalance = settingsByMonth[anchorMonth]
        else {
            return StartingBalanceResolution(
                amount: .zero,
                source: .rolledOver(from: month.previous)
            )
        }

        let startDate = anchorMonth.startDate(calendar: calendar)
        let endDate = month.startDate(calendar: calendar)
        let transactionPredicate = #Predicate<TransactionEntity> { transaction in
            transaction.date >= startDate && transaction.date < endDate
        }
        let transactions = try fetchOrThrow(
            FetchDescriptor(predicate: transactionPredicate)
        )
        let transactionsByMonth = Dictionary(grouping: transactions.map { $0.toDomain() }) {
            MonthKey(date: $0.date, calendar: calendar)
        }

        let engine = MonthlyProjectionEngine()
        var resolvedBalances = [anchorMonth: anchorBalance]
        var resolvedMonth = anchorMonth

        while resolvedMonth < month {
            guard let openingBalance = resolvedBalances[resolvedMonth] else {
                throw FinanceRepositoryError.dataLoadFailed
            }

            let projection = engine.project(
                ProjectionInput(
                    month: resolvedMonth,
                    referenceDate: resolvedMonth.endDate(calendar: calendar),
                    startingBalance: openingBalance,
                    transactions: transactionsByMonth[resolvedMonth, default: []],
                    calendar: calendar
                )
            )

            // Carry actual closing cash only. currentAvailableBalance already subtracts completed
            // savings, which must stay excluded because savings are not spendable cash.
            resolvedBalances[resolvedMonth.next] = projection.currentAvailableBalance
            resolvedMonth = resolvedMonth.next
        }

        return StartingBalanceResolution(
            amount: resolvedBalances[month] ?? .zero,
            source: .rolledOver(from: month.previous)
        )
    }

    private var carryBalanceForward: Bool {
        guard userDefaults.object(forKey: Self.carryBalanceForwardKey) != nil else {
            return true
        }

        return userDefaults.bool(forKey: Self.carryBalanceForwardKey)
    }

    func addTransaction(_ transaction: TransactionEntity) throws {
        try write {
            guard
                transaction.settlesBillID == nil,
                transaction.settlesDebtID == nil,
                transaction.settlesIncomeID == nil
            else {
                throw FinanceRepositoryError.settlementMustUseDedicatedMethod
            }

            transaction.amount = transaction.amount.positiveMagnitude
            transaction.category = try canonicalCategory(transaction.category)
            transaction.updatedAt = now()
            context.insert(transaction)
        }
    }

    func updateTransaction(_ transaction: TransactionEntity) throws {
        try write {
            guard
                transaction.settlesBillID == nil,
                transaction.settlesDebtID == nil,
                transaction.settlesIncomeID == nil
            else {
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
        }
    }

    func deleteTransaction(id: UUID) throws {
        try write {
            let transaction: TransactionEntity = try existing(id: id)
            context.delete(transaction)
        }
    }

    func addIncomeSource(_ source: IncomeSourceEntity) throws {
        try write {
            source.expectedAmount = source.expectedAmount.positiveMagnitude
            source.updatedAt = now()
            context.insert(source)
        }
    }

    func updateIncomeSource(_ source: IncomeSourceEntity) throws {
        try write {
            let stored: IncomeSourceEntity = try existing(id: source.id)
            stored.name = source.name
            stored.expectedAmount = source.expectedAmount.positiveMagnitude
            stored.frequency = source.frequency
            stored.anchorDate = source.anchorDate
            stored.endDate = source.endDate
            stored.isActive = source.isActive
            stored.updatedAt = now()
        }
    }

    func deleteIncomeSource(id: UUID) throws {
        try write {
            let source: IncomeSourceEntity = try existing(id: id)
            let linkedTransactions = try transactionsLinkedToIncome(id)
            let timestamp = now()

            for transaction in linkedTransactions {
                transaction.settlesIncomeID = nil
                transaction.updatedAt = timestamp
            }

            context.delete(source)
        }
    }

    func addBill(_ bill: RecurringBillEntity) throws {
        try write {
            bill.amount = bill.amount.positiveMagnitude
            bill.category = try canonicalCategory(bill.category)
            bill.updatedAt = now()
            context.insert(bill)
        }
    }

    func updateBill(_ bill: RecurringBillEntity) throws {
        try write {
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
        }
    }

    func deleteBill(id: UUID) throws {
        try write {
            let bill: RecurringBillEntity = try existing(id: id)
            let linkedTransactions = try transactionsLinkedToBill(id)
            let timestamp = now()

            for transaction in linkedTransactions {
                transaction.settlesBillID = nil
                transaction.updatedAt = timestamp
            }

            context.delete(bill)
        }
    }

    func addDebt(_ debt: DebtEntity) throws {
        try write {
            normalize(debt)
            debt.category = try canonicalCategory(defaultDebtCategory(for: debt.category))
            debt.updatedAt = now()
            context.insert(debt)
        }
    }

    func updateDebt(_ debt: DebtEntity) throws {
        try write {
            let stored: DebtEntity = try existing(id: debt.id)
            let normalizedBalance = debt.currentBalance.positiveMagnitude
            stored.name = debt.name
            stored.currentBalance = normalizedBalance
            stored.originalBalance = max(stored.originalBalance, normalizedBalance)
            stored.annualInterestRate = debt.annualInterestRate.positiveMagnitude
            stored.monthlyPayment = debt.monthlyPayment.positiveMagnitude
            stored.category = try canonicalCategory(defaultDebtCategory(for: debt.category))
            stored.dueDay = min(31, max(1, debt.dueDay))
            stored.isAutoPay = debt.isAutoPay
            stored.isPaidThroughBills = debt.isPaidThroughBills
            stored.isActive = debt.isActive
            stored.updatedAt = now()
        }
    }

    func deleteDebt(id: UUID) throws {
        try write {
            let debt: DebtEntity = try existing(id: id)
            let linkedTransactions = try transactionsLinkedToDebt(id)
            let timestamp = now()

            for transaction in linkedTransactions {
                transaction.settlesDebtID = nil
                transaction.updatedAt = timestamp
            }

            context.delete(debt)
        }
    }

    func addBudget(_ budget: BudgetEntity) throws {
        try write {
            try validateScope(year: budget.scopeYear, month: budget.scopeMonth)
            budget.monthlyLimit = budget.monthlyLimit.positiveMagnitude
            budget.category = try canonicalCategory(budget.category)
            budget.updatedAt = now()
            context.insert(budget)
        }
    }

    func updateBudget(_ budget: BudgetEntity) throws {
        try write {
            try validateScope(year: budget.scopeYear, month: budget.scopeMonth)
            let stored: BudgetEntity = try existing(id: budget.id)
            stored.category = try canonicalCategory(budget.category)
            stored.monthlyLimit = budget.monthlyLimit.positiveMagnitude
            stored.scopeYear = budget.scopeYear
            stored.scopeMonth = budget.scopeMonth
            stored.updatedAt = now()
        }
    }

    func deleteBudget(id: UUID) throws {
        try write {
            let budget: BudgetEntity = try existing(id: id)
            context.delete(budget)
        }
    }

    func addSavingsGoal(_ goal: SavingsGoalEntity) throws {
        try write {
            normalize(goal)
            goal.updatedAt = now()
            context.insert(goal)
        }
    }

    func updateSavingsGoal(_ goal: SavingsGoalEntity) throws {
        try write {
            let stored: SavingsGoalEntity = try existing(id: goal.id)
            stored.name = goal.name
            stored.targetAmount = goal.targetAmount.positiveMagnitude
            stored.monthlyTarget = goal.monthlyTarget.positiveMagnitude
            stored.currentAmount = goal.currentAmount.positiveMagnitude
            stored.targetDate = goal.targetDate
            stored.isActive = goal.isActive
            stored.updatedAt = now()
        }
    }

    func deleteSavingsGoal(id: UUID) throws {
        try write {
            let goal: SavingsGoalEntity = try existing(id: id)
            context.delete(goal)
        }
    }

    func setStartingBalance(_ balance: Decimal, for month: MonthKey) throws {
        try write {
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
        }
    }

    func deleteStartingBalance(for month: MonthKey) throws {
        try write {
            let year = month.year
            let monthNumber = month.month
            let predicate = #Predicate<MonthSettingsEntity> { settings in
                settings.year == year && settings.month == monthNumber
            }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            guard let settings = try fetchOrThrow(descriptor).first else {
                return
            }

            context.delete(settings)
        }
    }

    func markBillPaid(
        billID: UUID,
        occurrence: Date,
        amount: Decimal,
        on date: Date,
        account: String = ""
    ) throws {
        try write {
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
                account: AccountName.trimmed(account),
                settlesBillID: billID,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            context.insert(transaction)
        }
    }

    func markDebtPaymentMade(
        debtID: UUID,
        amount: Decimal,
        on date: Date,
        account: String = ""
    ) throws {
        try write {
            guard amount > .zero else {
                throw FinanceRepositoryError.nonPositiveAmount
            }

            let debt: DebtEntity = try existing(id: debtID)
            let month = MonthKey(date: date, calendar: calendar)
            let settlementCount = try transactionValues(in: month).count {
                $0.settlesDebtID == debtID
            }
            guard settlementCount == 0 else {
                throw FinanceRepositoryError.settlementAlreadyRecorded
            }

            let timestamp = now()
            let transaction = TransactionEntity(
                date: date,
                amount: amount,
                type: .expense,
                category: try canonicalCategory(debt.category),
                detail: debt.name,
                account: AccountName.trimmed(account),
                settlesDebtID: debtID,
                createdAt: timestamp,
                updatedAt: timestamp
            )

            debt.currentBalance = DebtSchedule().remainingBalance(
                afterPaymentOf: amount,
                for: debt.toDomain()
            )
            debt.updatedAt = timestamp
            context.insert(transaction)
        }
    }

    func markIncomeReceived(
        incomeID: UUID,
        amount: Decimal,
        on date: Date,
        account: String = ""
    ) throws {
        try write {
            guard amount > .zero else {
                throw FinanceRepositoryError.nonPositiveAmount
            }

            let source: IncomeSourceEntity = try existing(id: incomeID)
            let month = MonthKey(date: date, calendar: calendar)
            let occurrences = source.toDomain().recurrence.occurrences(
                in: month,
                calendar: calendar
            )
            let settlementCount = try transactionValues(in: month).count {
                $0.settlesIncomeID == incomeID
            }
            guard settlementCount < occurrences.count else {
                throw FinanceRepositoryError.settlementAlreadyRecorded
            }

            try recordIncomeReceived(
                source: source,
                incomeID: incomeID,
                occurrence: occurrences[settlementCount],
                amount: amount,
                on: date,
                account: account
            )
        }
    }

    func markIncomeReceived(
        incomeID: UUID,
        occurrence: Date,
        amount: Decimal,
        on date: Date,
        account: String = ""
    ) throws {
        try write {
            let source: IncomeSourceEntity = try existing(id: incomeID)
            try recordIncomeReceived(
                source: source,
                incomeID: incomeID,
                occurrence: occurrence,
                amount: amount,
                on: date,
                account: account
            )
        }
    }

    private func recordIncomeReceived(
        source: IncomeSourceEntity,
        incomeID: UUID,
        occurrence: Date,
        amount: Decimal,
        on date: Date,
        account: String
    ) throws {
        guard amount > .zero else {
            throw FinanceRepositoryError.nonPositiveAmount
        }

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
            account: AccountName.trimmed(account),
            settlesIncomeID: incomeID,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        context.insert(transaction)
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

    func add(_ debt: DebtEntity) throws {
        try addDebt(debt)
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

    func update(_ debt: DebtEntity) throws {
        try updateDebt(debt)
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

    func delete(_ debt: DebtEntity) throws {
        try deleteDebt(id: debt.id)
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

    private func normalize(_ debt: DebtEntity) {
        debt.currentBalance = debt.currentBalance.positiveMagnitude
        debt.originalBalance = max(
            debt.currentBalance,
            debt.originalBalance.positiveMagnitude
        )
        debt.annualInterestRate = debt.annualInterestRate.positiveMagnitude
        debt.monthlyPayment = debt.monthlyPayment.positiveMagnitude
        debt.dueDay = min(31, max(1, debt.dueDay))
    }

    private func defaultDebtCategory(for category: String) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCategory.isEmpty ? "Debt" : trimmedCategory
    }

    private func canonicalCategory(_ category: String) throws -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCategory.isEmpty else {
            return trimmedCategory
        }

        let storedCategories = try fetchOrThrow(FetchDescriptor<BudgetEntity>()).map(\.category)
            + fetchOrThrow(FetchDescriptor<RecurringBillEntity>()).map(\.category)
            + fetchOrThrow(FetchDescriptor<DebtEntity>()).map(\.category)
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

    private func seedAccountsFromTransactions() throws {
        try write {
            let transactions = try fetchOrThrow(
                FetchDescriptor<TransactionEntity>(
                    sortBy: [SortDescriptor(\TransactionEntity.createdAt)]
                )
            )
            let accounts = try fetchOrThrow(FetchDescriptor<AccountEntity>())
            var knownIdentities = Set(accounts.map { AccountName.identity($0.name) })

            for transaction in transactions {
                let name = AccountName.trimmed(transaction.account)
                let identity = AccountName.identity(name)
                guard !identity.isEmpty, knownIdentities.insert(identity).inserted else {
                    continue
                }

                context.insert(
                    AccountEntity(
                        name: name,
                        createdAt: transaction.createdAt
                    )
                )
            }
        }
    }

    private func transactionsLinkedToBill(_ id: UUID) throws -> [TransactionEntity] {
        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.settlesBillID == id
        }
        return try fetchOrThrow(FetchDescriptor(predicate: predicate))
    }

    private func transactionsLinkedToDebt(_ id: UUID) throws -> [TransactionEntity] {
        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.settlesDebtID == id
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

    /// Runs a mutation and commits it. On any failure the context is rolled back before the error
    /// is rethrown, so a failed write cannot leave mutated objects behind. Without this, one
    /// failure makes every later save() fail, because save() commits the whole context.
    private func write<Value>(_ body: () throws -> Value) throws -> Value {
        do {
            let result = try body()
            try context.save()
            successfulWriteHandler()
            return result
        } catch {
            let underlyingError = error as NSError
            Self.logger.error(
                "Repository write failed. Error domain: \(underlyingError.domain, privacy: .public); code: \(underlyingError.code)."
            )
            context.rollback()
            throw error
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
extension DebtEntity: IdentifiedPersistentModel {}
extension BudgetEntity: IdentifiedPersistentModel {}
extension SavingsGoalEntity: IdentifiedPersistentModel {}
extension AccountEntity: IdentifiedPersistentModel {}

private extension Decimal {
    var positiveMagnitude: Decimal {
        self < .zero ? -self : self
    }
}
