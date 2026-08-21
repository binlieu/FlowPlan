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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            ScreenHeader(
                title: "Activity",
                trailing: AnyView(activityHeaderActions)
            )

            activitySearchField

            MonthNavigationBar()
                .designSystemRows()

            if viewModel.filter.isActive {
                activeFilterChips
                    .listRowInsets(EdgeInsets())
                    .designSystemRows()
            }

            if viewModel.sections.isEmpty {
                emptyState
                    .designSystemRows()
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.transactions) { transaction in
                            transactionButton(transaction)
                        }
                    } header: {
                        sectionHeader(section)
                    }
                    .designSystemRows()
                }
            }
        }
        .listStyle(.insetGrouped)
        .designSystemList()
        .contentMargins(.top, Spacing.none, for: .scrollContent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
        .onChange(of: projectionStore.dataVersion) {
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
                    .foregroundStyle(Palette.onAccentFill)
            }
            .tint(Palette.destructiveFill)

            Button {
                editor = TransactionEditorPresentation(transaction: transaction)
            } label: {
                Label("Edit", systemImage: "pencil")
                    .foregroundStyle(Palette.onAccentFill)
            }
            .tint(Palette.neutralFill)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                editor = TransactionEditorPresentation(duplicatedTransaction: transaction)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
                    .foregroundStyle(Palette.onAccentFill)
            }
            .tint(Palette.neutralFill)
        }
    }

    private func sectionHeader(_ section: TransactionDaySection) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    sectionTitle(section)
                    sectionAmount(section)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    sectionTitle(section)

                    Spacer()

                    sectionAmount(section)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ section: TransactionDaySection) -> some View {
        Text(section.title)
            .designSystemSectionHeader()
    }

    private func sectionAmount(_ section: TransactionDaySection) -> some View {
        AmountText(
            amount: section.netTotal,
            style: .secondary,
            signed: true,
            color: Palette.ink
        )
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
                Button("Clear Filters") {
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

    private var activityHeaderActions: some View {
        HStack(spacing: Spacing.xs) {
            filterMenu
                .frame(minWidth: 44, minHeight: 44)

            Button {
                editor = TransactionEditorPresentation()
            } label: {
                Image(systemName: "plus")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Add transaction")
        }
        .prominentLabelTypography()
        .foregroundStyle(Palette.accent)
    }

    private var activitySearchField: some View {
        CardSurface(
            radius: Radius.control,
            contentInsets: EdgeInsets(
                top: Spacing.none,
                leading: Spacing.sm,
                bottom: Spacing.none,
                trailing: Spacing.sm
            )
        ) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)

                TextField("Description or category", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel("Search by description or category")

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .frame(minHeight: 44)
        }
        .listRowInsets(EdgeInsets(top: Spacing.none, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
        .listRowBackground(Palette.background)
        .listRowSeparator(.hidden)
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
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
                .rowDetailEmphasisTypography()
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, Spacing.xxs)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xxs)
        }
    }

    private func filterChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(text: title, style: .filledAccent, systemImage: "xmark")
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
#Preview("Activity — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            TransactionsView()
        }
    }
}

#Preview("Activity — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            TransactionsView()
        }
    }
}

#Preview("Activity — Largest Dynamic Type") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            TransactionsView()
        }
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
