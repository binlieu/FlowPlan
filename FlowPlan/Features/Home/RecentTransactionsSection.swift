import SwiftUI
import FlowPlanDomain

struct RecentTransactionsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let onSeeAll: () -> Void

    init(onSeeAll: @escaping () -> Void = {}) {
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        let _ = projectionStore.dataVersion

        Section {
            if recentTransactions.isEmpty {
                EmptyStateView(
                    symbol: "list.bullet.rectangle",
                    title: "No transactions yet.",
                    message: "Add your first income or expense to start tracking your month."
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(recentTransactions) { transaction in
                    transactionRow(transaction)
                }
            }
        } header: {
            sectionHeader
        }
    }

    private var sectionHeader: some View {
        SectionHeading(title: "Recent Transactions", actionTitle: "See all", action: onSeeAll)
    }

    private func transactionRow(_ transaction: TransactionSnapshot) -> some View {
        ListRow(
            leading: .icon(
                systemName: symbol(for: transaction.type),
                color: Palette.inkSecondary
            ),
            title: transaction.detail,
            subtitle: transaction.date.formatted(.dateTime.month(.abbreviated).day()),
            trailingAmount: MoneyFormatter.string(
                displayAmount(for: transaction),
                currencyCode: appState.currencyCode,
                signed: true
            ),
            amountStyle: .secondary,
            amountColor: amountColor(for: transaction.type),
            amountAccessibilityLabel: accessibleAmount(for: transaction),
            contentInsets: EdgeInsets(
                top: Spacing.xxs,
                leading: Spacing.none,
                bottom: Spacing.xxs,
                trailing: Spacing.none
            )
        )
    }

    private var recentTransactions: [TransactionSnapshot] {
        return Array(repository.transactions(in: appState.selectedMonth).prefix(5))
    }

    private func displayAmount(for transaction: TransactionSnapshot) -> Decimal {
        switch transaction.type {
        case .expense, .savings:
            return -transaction.amount
        case .income, .transfer:
            return transaction.amount
        }
    }

    private func accessibleAmount(for transaction: TransactionSnapshot) -> String {
        let amount = displayAmount(for: transaction)
        let value = MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
        return amount > .zero ? "Plus \(value)" : value
    }

    private func symbol(for type: TransactionType) -> String {
        switch type {
        case .income:
            return "arrow.down.circle"
        case .expense:
            return "arrow.up.circle"
        case .transfer:
            return "arrow.left.arrow.right.circle"
        case .savings:
            return "banknote"
        }
    }

    private func amountColor(for type: TransactionType) -> Color {
        type == .income ? Palette.positive : Palette.ink
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        List {
            RecentTransactionsSection()
        }
        .listStyle(.insetGrouped)
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        List {
            RecentTransactionsSection()
        }
        .listStyle(.insetGrouped)
    }
}
#endif
