import Foundation
import SwiftData
import FlowPlanDomain

struct Account: Identifiable, Hashable {
    let id: UUID
    let name: String
}

enum AccountName {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func identity(_ value: String) -> String {
        trimmed(value)
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

@Model
final class AccountEntity {
    #Unique<AccountEntity>([\.id])

    var id: UUID
    var name: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    func toValue() -> Account {
        Account(id: id, name: name)
    }
}

@Model
final class TransactionEntity {
    #Unique<TransactionEntity>([\.id])

    var id: UUID
    var date: Date
    var amount: Decimal
    var typeRaw: String
    var category: String
    var detail: String
    var note: String
    var account: String
    var settlesBillID: UUID?
    var settlesDebtID: UUID?
    var settlesIncomeID: UUID?
    var isAutoRecorded: Bool = false
    var createdAt: Date
    var updatedAt: Date

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Decimal,
        type: TransactionType,
        category: String,
        detail: String,
        note: String = "",
        account: String = "",
        settlesBillID: UUID? = nil,
        settlesDebtID: UUID? = nil,
        settlesIncomeID: UUID? = nil,
        isAutoRecorded: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount.positiveMagnitude
        self.typeRaw = type.rawValue
        self.category = category
        self.detail = detail
        self.note = note
        self.account = account
        self.settlesBillID = settlesBillID
        self.settlesDebtID = settlesDebtID
        self.settlesIncomeID = settlesIncomeID
        self.isAutoRecorded = isAutoRecorded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        domain: TransactionSnapshot,
        note: String = "",
        account: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        id = domain.id
        date = domain.date
        amount = domain.amount.positiveMagnitude
        typeRaw = domain.type.rawValue
        category = domain.category
        detail = domain.detail
        self.note = note
        self.account = account
        settlesBillID = domain.settlesBillID
        settlesDebtID = domain.settlesDebtID
        settlesIncomeID = domain.settlesIncomeID
        isAutoRecorded = domain.isAutoRecorded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> TransactionSnapshot {
        TransactionSnapshot(
            id: id,
            date: date,
            amount: amount.positiveMagnitude,
            type: type,
            category: category,
            detail: detail,
            settlesBillID: settlesBillID,
            settlesDebtID: settlesDebtID,
            settlesIncomeID: settlesIncomeID,
            isAutoRecorded: isAutoRecorded
        )
    }
}

@Model
final class IncomeSourceEntity {
    #Unique<IncomeSourceEntity>([\.id])

    var id: UUID
    var name: String
    var expectedAmount: Decimal
    var frequencyRaw: String
    var anchorDate: Date
    var endDate: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        expectedAmount: Decimal,
        frequency: RecurrenceFrequency,
        anchorDate: Date,
        endDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.expectedAmount = expectedAmount.positiveMagnitude
        frequencyRaw = frequency.rawValue
        self.anchorDate = anchorDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        domain: PlannedIncome,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        id = domain.id
        name = domain.name
        expectedAmount = domain.expectedAmount.positiveMagnitude
        frequencyRaw = domain.recurrence.frequency.rawValue
        anchorDate = domain.recurrence.anchorDate
        endDate = domain.recurrence.endDate
        isActive = domain.isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> PlannedIncome {
        PlannedIncome(
            id: id,
            name: name,
            expectedAmount: expectedAmount.positiveMagnitude,
            recurrence: RecurrenceRule(
                frequency: frequency,
                anchorDate: anchorDate,
                endDate: endDate
            ),
            isActive: isActive
        )
    }
}

@Model
final class RecurringBillEntity {
    #Unique<RecurringBillEntity>([\.id])

    var id: UUID
    var name: String
    var amount: Decimal
    var amountTypeRaw: String
    var category: String
    var frequencyRaw: String
    var anchorDate: Date
    var endDate: Date?
    var isAutoPay: Bool
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    var amountType: BillAmountType {
        get { BillAmountType(rawValue: amountTypeRaw) ?? .fixed }
        set { amountTypeRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        amountType: BillAmountType,
        category: String,
        frequency: RecurrenceFrequency,
        anchorDate: Date,
        endDate: Date? = nil,
        isAutoPay: Bool = false,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount.positiveMagnitude
        amountTypeRaw = amountType.rawValue
        self.category = category
        frequencyRaw = frequency.rawValue
        self.anchorDate = anchorDate
        self.endDate = endDate
        self.isAutoPay = isAutoPay
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        domain: PlannedBill,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        id = domain.id
        name = domain.name
        amount = domain.amount.positiveMagnitude
        amountTypeRaw = domain.amountType.rawValue
        category = domain.category
        frequencyRaw = domain.recurrence.frequency.rawValue
        anchorDate = domain.recurrence.anchorDate
        endDate = domain.recurrence.endDate
        isAutoPay = domain.isAutoPay
        isActive = domain.isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> PlannedBill {
        PlannedBill(
            id: id,
            name: name,
            amount: amount.positiveMagnitude,
            amountType: amountType,
            category: category,
            recurrence: RecurrenceRule(
                frequency: frequency,
                anchorDate: anchorDate,
                endDate: endDate
            ),
            isAutoPay: isAutoPay,
            isActive: isActive
        )
    }
}

@Model
final class DebtEntity {
    #Unique<DebtEntity>([\.id])

    var id: UUID
    var name: String
    var currentBalance: Decimal
    var originalBalance: Decimal
    var annualInterestRate: Decimal
    var monthlyPayment: Decimal
    var category: String
    var firstPaymentYear: Int? = nil
    var firstPaymentMonthNumber: Int? = nil
    var dueDay: Int = 1
    var isAutoPay: Bool = false
    var isPaidThroughBills: Bool
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        currentBalance: Decimal,
        originalBalance: Decimal? = nil,
        annualInterestRate: Decimal,
        monthlyPayment: Decimal,
        category: String,
        firstPaymentMonth: MonthKey? = nil,
        dueDay: Int = 1,
        isAutoPay: Bool = false,
        isPaidThroughBills: Bool,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let normalizedBalance = currentBalance.positiveMagnitude
        self.id = id
        self.name = name
        self.currentBalance = normalizedBalance
        self.originalBalance = max(
            normalizedBalance,
            originalBalance?.positiveMagnitude ?? normalizedBalance
        )
        self.annualInterestRate = annualInterestRate.positiveMagnitude
        self.monthlyPayment = monthlyPayment.positiveMagnitude
        self.category = category
        firstPaymentYear = firstPaymentMonth?.year
        firstPaymentMonthNumber = firstPaymentMonth?.month
        self.dueDay = min(31, max(1, dueDay))
        self.isAutoPay = isAutoPay
        self.isPaidThroughBills = isPaidThroughBills
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        domain: Debt,
        originalBalance: Decimal? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let normalizedBalance = domain.currentBalance.positiveMagnitude
        id = domain.id
        name = domain.name
        currentBalance = normalizedBalance
        self.originalBalance = max(
            normalizedBalance,
            originalBalance?.positiveMagnitude ?? normalizedBalance
        )
        annualInterestRate = domain.annualInterestRate.positiveMagnitude
        monthlyPayment = domain.monthlyPayment.positiveMagnitude
        category = domain.category
        firstPaymentYear = domain.firstPaymentMonth?.year
        firstPaymentMonthNumber = domain.firstPaymentMonth?.month
        dueDay = domain.dueDay
        isAutoPay = domain.isAutoPay
        isPaidThroughBills = domain.isPaidThroughBills
        isActive = domain.isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> Debt {
        Debt(
            id: id,
            name: name,
            currentBalance: currentBalance.positiveMagnitude,
            annualInterestRate: annualInterestRate.positiveMagnitude,
            monthlyPayment: monthlyPayment.positiveMagnitude,
            category: category,
            firstPaymentMonth: firstPaymentMonth,
            dueDay: dueDay,
            isAutoPay: isAutoPay,
            isPaidThroughBills: isPaidThroughBills,
            isActive: isActive
        )
    }

    var firstPaymentMonth: MonthKey? {
        guard let firstPaymentYear, let firstPaymentMonthNumber else {
            return nil
        }

        return MonthKey(year: firstPaymentYear, month: firstPaymentMonthNumber)
    }
}

enum AutoRecordExclusionKind: String {
    case bill
    case debt
}

@Model
final class AutoRecordExclusionEntity {
    #Unique<AutoRecordExclusionEntity>([\.id])

    var id: UUID
    var kindRaw: String
    var sourceID: UUID
    var occurrenceDate: Date
    var createdAt: Date

    var kind: AutoRecordExclusionKind? {
        AutoRecordExclusionKind(rawValue: kindRaw)
    }

    init(
        id: UUID = UUID(),
        kind: AutoRecordExclusionKind,
        sourceID: UUID,
        occurrenceDate: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        kindRaw = kind.rawValue
        self.sourceID = sourceID
        self.occurrenceDate = occurrenceDate
        self.createdAt = createdAt
    }
}

@Model
final class BudgetEntity {
    #Unique<BudgetEntity>([\.id])

    var id: UUID
    var category: String
    var monthlyLimit: Decimal
    var scopeYear: Int?
    var scopeMonth: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: String,
        monthlyLimit: Decimal,
        scopeYear: Int? = nil,
        scopeMonth: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit.positiveMagnitude
        self.scopeYear = scopeYear
        self.scopeMonth = scopeMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        domain: BudgetAllocation,
        scopeYear: Int? = nil,
        scopeMonth: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        id = domain.id
        category = domain.category
        monthlyLimit = domain.monthlyLimit.positiveMagnitude
        self.scopeYear = scopeYear
        self.scopeMonth = scopeMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> BudgetAllocation {
        BudgetAllocation(
            id: id,
            category: category,
            monthlyLimit: monthlyLimit.positiveMagnitude
        )
    }
}

@Model
final class SavingsGoalEntity {
    #Unique<SavingsGoalEntity>([\.id])

    var id: UUID
    var name: String
    var targetAmount: Decimal
    var monthlyTarget: Decimal
    var currentAmount: Decimal
    var targetDate: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        monthlyTarget: Decimal,
        currentAmount: Decimal = .zero,
        targetDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount.positiveMagnitude
        self.monthlyTarget = monthlyTarget.positiveMagnitude
        self.currentAmount = currentAmount.positiveMagnitude
        self.targetDate = targetDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        domain: SavingsPlan,
        targetAmount: Decimal? = nil,
        currentAmount: Decimal = .zero,
        targetDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        id = domain.id
        name = domain.name
        self.targetAmount = (targetAmount ?? domain.monthlyTarget).positiveMagnitude
        monthlyTarget = domain.monthlyTarget.positiveMagnitude
        self.currentAmount = currentAmount.positiveMagnitude
        self.targetDate = targetDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> SavingsPlan {
        SavingsPlan(id: id, name: name, monthlyTarget: monthlyTarget.positiveMagnitude)
    }
}

@Model
final class MonthSettingsEntity {
    #Unique<MonthSettingsEntity>([\.id], [\.year, \.month])

    var id: UUID
    var year: Int
    var month: Int
    var startingBalance: Decimal
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        startingBalance: Decimal,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let monthKey = MonthKey(year: year, month: month)
        self.id = id
        self.year = monthKey.year
        self.month = monthKey.month
        self.startingBalance = startingBalance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> (month: MonthKey, startingBalance: Decimal) {
        (MonthKey(year: year, month: month), startingBalance)
    }
}

private extension Decimal {
    var positiveMagnitude: Decimal {
        self < .zero ? -self : self
    }
}
