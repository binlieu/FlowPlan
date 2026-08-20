import Foundation

public struct Insight: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case spending
        case savings
        case subscriptions
        case projection
        case income
    }

    public let id: String
    public let kind: Kind
    public let message: String
    public let symbolName: String

    public init(id: String, kind: Kind, message: String, symbolName: String) {
        self.id = id
        self.kind = kind
        self.message = message
        self.symbolName = symbolName
    }
}
