import SwiftUI
import FlowPlanDomain

struct TransactionRow: View {
    @Environment(AppState.self) private var appState

    let transaction: TransactionSnapshot
    let account: String

    init(transaction: TransactionSnapshot, account: String = "") {
        self.transaction = transaction
        self.account = account
    }

    var body: some View {
        ListRow(
            leading: .icon(systemName: transaction.type.systemImage, color: iconColor),
            title: primaryText,
            subtitle: subtitle,
            trailingAmount: formattedAmount,
            amountStyle: .secondary,
            amountColor: amountColor,
            amountAccessibilityLabel: accessibleAmount,
            statuses: transaction.isAutoRecorded
                ? [ListRowStatus(text: "AUTO", style: .filledNeutral)]
                : [],
            statusPlacement: .detail,
            contentInsets: EdgeInsets(
                top: Spacing.xxs,
                leading: Spacing.none,
                bottom: Spacing.xxs,
                trailing: Spacing.none
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(transaction.isAutoRecorded ? "Automatically recorded" : "")
        .accessibilityHint("Opens this transaction for editing")
    }

    private var formattedAmount: String {
        MoneyFormatter.string(
            displayedAmount,
            currencyCode: appState.currencyCode,
            signed: transaction.type != .transfer
        )
    }

    private var accessibleAmount: String {
        let value = MoneyFormatter.accessibleString(
            displayedAmount,
            currencyCode: appState.currencyCode
        )

        if transaction.type != .transfer, displayedAmount > .zero {
            return "Plus \(value)"
        }

        return value
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
            return Palette.positive
        case .expense:
            return Palette.inkSecondary
        case .savings:
            return Palette.info
        case .transfer:
            return Palette.info
        }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income:
            return Palette.positive
        case .expense, .savings, .transfer:
            return Palette.ink
        }
    }
}

#if DEBUG
private struct TransactionTypesPreview: View {
    var body: some View {
        List {
            ForEach(TransactionType.allCases, id: \.rawValue) { type in
                TransactionRow(
                    transaction: TransactionSnapshot(
                        id: UUID(),
                        date: FlowPlanPreviewData.referenceDate,
                        amount: 125,
                        type: type,
                        category: type.displayName,
                        detail: "\(type.displayName) example"
                    ),
                    account: "Everyday"
                )
                .designSystemRows()
            }
        }
        .listStyle(.insetGrouped)
        .designSystemList()
    }
}

#Preview("Transaction Types — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        TransactionTypesPreview()
    }
}

#Preview("Transaction Types — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        TransactionTypesPreview()
    }
}
#endif
