import SwiftUI
import FlowPlanDomain

struct TransactionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let transaction: TransactionSnapshot
    let account: String

    init(transaction: TransactionSnapshot, account: String = "") {
        self.transaction = transaction
        self.account = account
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type.systemImage)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.body.weight(.medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            AmountText(
                amount: displayedAmount,
                style: .secondary,
                signed: transaction.type != .transfer,
                emphasiseNegative: true
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this transaction for editing")
    }

    private var primaryText: String {
        let detail = transaction.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? transaction.category : detail
    }

    private var displayedAmount: Decimal {
        if transaction.type == .transfer {
            return transaction.amount
        }

        return transaction.type.netAmount(for: transaction.amount)
    }

    private var subtitle: String {
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAccount.isEmpty else {
            return transaction.category
        }

        return "\(transaction.category) · \(trimmedAccount)"
    }

    private var iconColor: Color {
        switch transaction.type {
        case .income:
            return .green
        case .expense:
            return .orange
        case .savings:
            return .blue
        case .transfer:
            return .purple
        }
    }
}
