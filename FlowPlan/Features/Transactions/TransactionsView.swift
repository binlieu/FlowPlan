import SwiftUI
import FlowPlanDomain

struct TransactionsView: View {
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    var body: some View {
        TransactionsContent(
            repository: repository,
            projectionStore: projectionStore
        )
    }
}

@MainActor
private struct TransactionsContent: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var viewModel: TransactionsViewModel
    @State private var editor: TransactionEditorPresentation?
    @State private var pendingDelete: TransactionSnapshot?
    @State private var isConfirmingDelete = false
    @State private var presentedError: WriteErrorPresentation?

    init(repository: FinanceRepository, projectionStore: ProjectionStore) {
        _viewModel = State(
            initialValue: TransactionsViewModel(
                repository: repository,
                projectionStore: projectionStore
            )
        )
    }

    var body: some View {
        List {
            MonthNavigationBar()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if viewModel.filter.isActive {
                activeFilterChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if viewModel.sections.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.transactions) { transaction in
                            transactionButton(transaction)
                        }
                    } header: {
                        sectionHeader(section)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Description or category"
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                filterMenu

                Button {
                    editor = TransactionEditorPresentation()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add transaction")
            }
        }
        .sheet(item: $editor) { editor in
            AddTransactionView(
                transaction: editor.transaction,
                duplicateOf: editor.duplicatedTransaction,
                onSaved: {
                    viewModel.load(month: appState.selectedMonth)
                }
            )
        }
        .confirmationDialog(
            "Delete transaction?",
            isPresented: $isConfirmingDelete,
            presenting: pendingDelete
        ) { transaction in
            Button("Delete", role: .destructive) {
                delete(transaction)
            }
            Button("Cancel", role: .cancel) {}
        } message: { transaction in
            Text("This permanently deletes \(transaction.detail.isEmpty ? "this transaction" : transaction.detail).")
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .refreshable {
            viewModel.load(month: appState.selectedMonth)
        }
        .onAppear {
            viewModel.load(month: appState.selectedMonth)
        }
        .onChange(of: appState.selectedMonth) {
            projectionStore.refresh()
            viewModel.load(month: appState.selectedMonth)
        }
        .onChange(of: projectionStore.projection) {
            viewModel.load(month: appState.selectedMonth)
        }
    }

    private func transactionButton(_ transaction: TransactionSnapshot) -> some View {
        Button {
            editor = TransactionEditorPresentation(transaction: transaction)
        } label: {
            TransactionRow(
                transaction: transaction,
                account: viewModel.account(for: transaction)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = transaction
                isConfirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                editor = TransactionEditorPresentation(transaction: transaction)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                editor = TransactionEditorPresentation(duplicatedTransaction: transaction)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.indigo)
        }
    }

    private func sectionHeader(_ section: TransactionDaySection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(section.title)
                .foregroundStyle(.primary)

            Spacer()

            AmountText(
                amount: section.netTotal,
                style: .secondary,
                signed: true,
                emphasiseNegative: true
            )
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        Group {
            if viewModel.isNarrowingResults {
                EmptyStateView(
                    symbol: "line.3.horizontal.decrease.circle",
                    title: "No transactions match this filter.",
                    message: "Try changing the search or clearing a filter."
                )
            } else {
                EmptyStateView(
                    symbol: "list.bullet.rectangle",
                    title: "No transactions yet.",
                    message: "Add your first income or expense to start tracking your month.",
                    actionTitle: "Add transaction"
                ) {
                    editor = TransactionEditorPresentation()
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Transaction Type") {
                Picker("Transaction Type", selection: filterTypeBinding) {
                    ForEach(TransactionTypeFilter.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
            }

            Menu("Categories") {
                if viewModel.availableCategories.isEmpty {
                    Text("No categories available")
                } else {
                    ForEach(viewModel.availableCategories, id: \.self) { category in
                        Button {
                            viewModel.toggleCategory(category)
                        } label: {
                            if viewModel.filter.categories.contains(category) {
                                Label(category, systemImage: "checkmark")
                            } else {
                                Text(category)
                            }
                        }
                    }
                }
            }

            Menu("Accounts") {
                if viewModel.availableAccounts.isEmpty {
                    Text("No accounts available")
                } else {
                    ForEach(viewModel.availableAccounts, id: \.self) { account in
                        Button {
                            viewModel.selectAccount(
                                viewModel.filter.account == account ? nil : account
                            )
                        } label: {
                            if viewModel.filter.account == account {
                                Label(account, systemImage: "checkmark")
                            } else {
                                Text(account)
                            }
                        }
                    }
                }
            }

            if viewModel.filter.isActive {
                Divider()
                Button("Clear Filters", role: .destructive) {
                    viewModel.clearFilters()
                }
            }
        } label: {
            Image(
                systemName: viewModel.filter.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityLabel("Filter transactions")
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.filter.type != .all {
                    filterChip(viewModel.filter.type.title) {
                        var filter = viewModel.filter
                        filter.type = .all
                        viewModel.filter = filter
                    }
                }

                ForEach(viewModel.filter.categories.sorted(), id: \.self) { category in
                    filterChip(category) {
                        viewModel.removeCategoryFilter(category)
                    }
                }

                if let account = viewModel.filter.account {
                    filterChip(account) {
                        viewModel.selectAccount(nil)
                    }
                }

                Button("Clear") {
                    viewModel.clearFilters()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private func filterChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
    }

    private var filterTypeBinding: Binding<TransactionTypeFilter> {
        Binding(
            get: { viewModel.filter.type },
            set: { type in
                var filter = viewModel.filter
                filter.type = type
                viewModel.filter = filter
            }
        )
    }

    private func delete(_ transaction: TransactionSnapshot) {
        do {
            try viewModel.delete(transaction, in: appState.selectedMonth)
            pendingDelete = nil
        } catch {
            pendingDelete = nil
            presentedError = WriteErrorPresentation(
                operation: .delete,
                subject: "transaction",
                error: error
            )
        }
    }

    private struct TransactionEditorPresentation: Identifiable {
        let id = UUID()
        let transaction: TransactionSnapshot?
        let duplicatedTransaction: TransactionSnapshot?

        init(
            transaction: TransactionSnapshot? = nil,
            duplicatedTransaction: TransactionSnapshot? = nil
        ) {
            self.transaction = transaction
            self.duplicatedTransaction = duplicatedTransaction
        }
    }

}

#if DEBUG
#Preview("Transactions") {
    FlowPlanPreviewHost {
        NavigationStack {
            TransactionsView()
        }
    }
}
#endif
