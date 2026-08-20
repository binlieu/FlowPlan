import SwiftUI
import FlowPlanDomain

struct TransactionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 32

    let transaction: TransactionSnapshot
    let account: String

    init(transaction: TransactionSnapshot, account: String = "") {
        self.transaction = transaction
        self.account = account
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    identityContent

                    amount
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    identityContent

                    Spacer(minLength: 8)

                    amount
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(transaction.isAutoRecorded ? "Automatically recorded" : "")
        .accessibilityHint("Opens this transaction for editing")
    }

    private var identityContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: transaction.type.systemImage)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: iconSize, height: iconSize)
                .background(iconColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 6) {
                            subtitleText
                            autoRecordedChip
                        }
                    } else {
                        HStack(spacing: 6) {
                            subtitleText
                            autoRecordedChip
                        }
                    }
                }
            }
            .layoutPriority(1)
        }
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(Palette.inkSecondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var autoRecordedChip: some View {
        if transaction.isAutoRecorded {
            Chip(text: "AUTO", style: .filledNeutral)
        }
    }

    private var amount: some View {
        AmountText(
            amount: displayedAmount,
            style: .secondary,
            signed: transaction.type != .transfer,
            emphasiseNegative: true
        )
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
