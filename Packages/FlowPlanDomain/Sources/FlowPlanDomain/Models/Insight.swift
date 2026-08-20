import Foundation

public struct Insight: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case spending(category: String, percentageChange: Decimal)
        case savings(monthlyTarget: Decimal)
        case subscriptions(monthlyTotal: Decimal)
        case projection(month: Int, varianceFromPlan: Decimal)
        case income(received: Decimal, expected: Decimal, remaining: Decimal)
    }

    public let id: String
    public let kind: Kind

    public init(id: String, kind: Kind) {
        self.id = id
        self.kind = kind
    }
}
