import Foundation

public struct Debt: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let currentBalance: Decimal
    public let annualInterestRate: Decimal
    public let monthlyPayment: Decimal
    public let category: String

    /// Day of the month the payment is due. Months with fewer days use their final day.
    public let dueDay: Int

    /// When true, Monthly Bills already includes this payment. The debt remains visible for
    /// tracking, but must not add another obligation to a projection.
    public let isPaidThroughBills: Bool
    public let isActive: Bool

    public init(
        id: UUID,
        name: String,
        currentBalance: Decimal,
        annualInterestRate: Decimal,
        monthlyPayment: Decimal,
        category: String,
        dueDay: Int = 1,
        isPaidThroughBills: Bool,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.currentBalance = currentBalance
        self.annualInterestRate = annualInterestRate
        self.monthlyPayment = monthlyPayment
        self.category = category
        self.dueDay = min(31, max(1, dueDay))
        self.isPaidThroughBills = isPaidThroughBills
        self.isActive = isActive
    }
}
