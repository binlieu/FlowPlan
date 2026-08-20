import Foundation
import FlowPlanDomain

struct TransactionFilter: Hashable {
    var type: TransactionTypeFilter = .all
    var categories: Set<String> = []
    var account: String?

    var isActive: Bool {
        type != .all || !categories.isEmpty || account != nil
    }

    mutating func toggleCategory(_ category: String) {
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
    }

    mutating func clear() {
        self = TransactionFilter()
    }

    func matches(_ transaction: TransactionSnapshot, account transactionAccount: String = "") -> Bool {
        type.matches(transaction.type)
            && (categories.isEmpty || categories.contains(transaction.category))
            && matchesAccount(transactionAccount)
    }

    private func matchesAccount(_ transactionAccount: String) -> Bool {
        guard let account else {
            return true
        }

        return AccountName.identity(account) == AccountName.identity(transactionAccount)
    }
}

enum TransactionTypeFilter: String, CaseIterable, Identifiable {
    case all
    case income
    case expense
    case savings
    case transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .income:
            return "Income"
        case .expense:
            return "Expense"
        case .savings:
            return "Savings"
        case .transfer:
            return "Transfer"
        }
    }

    func matches(_ transactionType: TransactionType) -> Bool {
        switch self {
        case .all:
            return true
        case .income:
            return transactionType == .income
        case .expense:
            return transactionType == .expense
        case .savings:
            return transactionType == .savings
        case .transfer:
            return transactionType == .transfer
        }
    }
}

extension TransactionType {
    var displayName: String {
        switch self {
        case .income:
            return "Income"
        case .expense:
            return "Expense"
        case .savings:
            return "Savings"
        case .transfer:
            return "Transfer"
        }
    }

    var systemImage: String {
        switch self {
        case .income:
            return "arrow.down.circle"
        case .expense:
            return "arrow.up.circle"
        case .savings:
            return "banknote"
        case .transfer:
            return "arrow.left.arrow.right.circle"
        }
    }

    func netAmount(for amount: Decimal) -> Decimal {
        switch self {
        case .income:
            return amount
        case .expense, .savings:
            return -amount
        case .transfer:
            return .zero
        }
    }
}
