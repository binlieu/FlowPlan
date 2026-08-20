import Foundation

public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case income
    case expense
    case transfer
    case savings
}

public enum BillAmountType: String, Codable, CaseIterable, Sendable {
    case fixed
    case estimated
    case variable
}

public struct PlannedIncome: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let expectedAmount: Decimal
    public let recurrence: RecurrenceRule
    public let isActive: Bool

    public init(
        id: UUID,
        name: String,
        expectedAmount: Decimal,
        recurrence: RecurrenceRule,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.expectedAmount = expectedAmount
        self.recurrence = recurrence
        self.isActive = isActive
    }
}

public struct PlannedBill: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let amount: Decimal
    public let amountType: BillAmountType
    public let category: String
    public let recurrence: RecurrenceRule
    public let isAutoPay: Bool
    public let isActive: Bool

    public init(
        id: UUID,
        name: String,
        amount: Decimal,
        amountType: BillAmountType,
        category: String,
        recurrence: RecurrenceRule,
        isAutoPay: Bool,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.amountType = amountType
        self.category = category
        self.recurrence = recurrence
        self.isAutoPay = isAutoPay
        self.isActive = isActive
    }
}

public struct BudgetAllocation: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let category: String
    public let monthlyLimit: Decimal

    public init(id: UUID, category: String, monthlyLimit: Decimal) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
    }
}

public struct SavingsPlan: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let monthlyTarget: Decimal

    public init(id: UUID, name: String, monthlyTarget: Decimal) {
        self.id = id
        self.name = name
        self.monthlyTarget = monthlyTarget
    }
}

public struct TransactionSnapshot: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let amount: Decimal
    public let type: TransactionType
    public let category: String
    public let detail: String
    public let settlesBillID: UUID?
    public let settlesDebtID: UUID?
    public let settlesIncomeID: UUID?

    public init(
        id: UUID,
        date: Date,
        amount: Decimal,
        type: TransactionType,
        category: String,
        detail: String,
        settlesBillID: UUID? = nil,
        settlesDebtID: UUID? = nil,
        settlesIncomeID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.category = category
        self.detail = detail
        self.settlesBillID = settlesBillID
        self.settlesDebtID = settlesDebtID
        self.settlesIncomeID = settlesIncomeID
    }
}
