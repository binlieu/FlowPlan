import SwiftUI
import FlowPlanDomain

struct TransactionRow: View {
    let transaction: TransactionSnapshot

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
                    .lineLimit(1)

                Text(transaction.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
