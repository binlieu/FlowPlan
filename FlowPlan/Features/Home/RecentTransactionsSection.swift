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
        HStack(alignment: .firstTextBaseline) {
            Text("Recent Transactions")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button("See all", action: onSeeAll)
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
        }
    }

    private func transactionRow(_ transaction: TransactionSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol(for: transaction.type))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.detail)
                    .font(.body.weight(.medium))

                Text(transaction.date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            AmountText(
                amount: displayAmount(for: transaction),
                style: .secondary,
                signed: true,
                emphasiseNegative: true
            )
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
