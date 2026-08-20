import SwiftUI
import SwiftData
import UIKit
import FlowPlanDomain

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    private let transactionToEdit: TransactionSnapshot?
    private let isDuplicate: Bool
    private let onSaved: () -> Void

    @Query private var storedTransactions: [TransactionEntity]

    @State private var transactionType: TransactionType
    @State private var amount: Decimal?
    @State private var category: String
    @State private var transactionDescription: String
    @State private var date: Date
    @State private var account: String
    @State private var isRecurring = false
    @State private var note: String
    @State private var existingCategories: [String] = []
    @State private var settlementOccurrences: [TransactionSettlementOccurrence] = []
    @State private var selectedSettlementID: String?
    @State private var isPresentingNewCategory = false
    @State private var newCategory = ""
    @State private var presentedError: PresentedError?
    @State private var isSaving = false
    @State private var didConfigureInitialDate = false
    @State private var didLoadStoredDetails = false

    @FocusState private var isAmountFocused: Bool

    init(
        transaction: TransactionSnapshot? = nil,
        duplicateOf duplicatedTransaction: TransactionSnapshot? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        let source = transaction ?? duplicatedTransaction
        let sourceID = source?.id ?? UUID()

        transactionToEdit = transaction
        isDuplicate = duplicatedTransaction != nil
        self.onSaved = onSaved
        _storedTransactions = Query(
            filter: #Predicate<TransactionEntity> { storedTransaction in
                storedTransaction.id == sourceID
            }
        )
        _transactionType = State(initialValue: source?.type ?? .expense)
        _amount = State(initialValue: source?.amount)
        _category = State(initialValue: source?.category ?? "")
        _transactionDescription = State(initialValue: source?.detail ?? "")
        _date = State(initialValue: duplicatedTransaction == nil ? source?.date ?? Date() : Date())
        _account = State(initialValue: "")
        _note = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                transactionTypeSection
                amountSection
                detailsSection
                settlementSection
                recurringSection
                noteSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
            }
            .onAppear {
                configureInitialState()
            }
            .onChange(of: transactionType) {
                if !supportsRecurring {
                    isRecurring = false
                }
                loadCategories()
                loadSettlementOccurrences()
            }
            .onChange(of: date) {
                loadSettlementOccurrences()
            }
            .onChange(of: isRecurring) {
                loadSettlementOccurrences()
            }
            .onChange(of: selectedSettlementID) {
                applySettlementDefaults()
            }
            .alert("New category", isPresented: $isPresentingNewCategory) {
                TextField("Category name", text: $newCategory)
                Button("Cancel", role: .cancel) {
                    newCategory = ""
                }
                Button("Add") {
                    addNewCategory()
                }
                .disabled(trimmedNewCategory.isEmpty)
            } message: {
                Text("Enter a category name for this transaction.")
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Unable to save"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
    }

    private var transactionTypeSection: some View {
        Section {
            HStack(spacing: 12) {
                Picker("Transaction type", selection: commonTypeBinding) {
                    Text("Income").tag(TransactionType.income as TransactionType?)
                    Text("Expense").tag(TransactionType.expense as TransactionType?)
                }
                .pickerStyle(.segmented)

                Menu {
                    Button {
                        transactionType = .savings
                    } label: {
                        Label("Savings", systemImage: TransactionType.savings.systemImage)
                    }

                    Button {
                        transactionType = .transfer
                    } label: {
                        Label("Transfer", systemImage: TransactionType.transfer.systemImage)
                    }
                } label: {
                    Label(moreMenuTitle, systemImage: "ellipsis.circle")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("More transaction types")
            }
        }
    }

    private var amountSection: some View {
        Section {
            TextField("0.00", value: $amount, format: amountFormat)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .focused($isAmountFocused)
                .accessibilityLabel("Amount")
        } header: {
            Text("Amount")
        } footer: {
            if !hasValidAmount {
                Text("Amount must be greater than zero.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var detailsSection: some View {
        Section {
            Menu {
                ForEach(existingCategories, id: \.self) { existingCategory in
                    Button {
                        category = existingCategory
                    } label: {
                        if category == existingCategory {
                            Label(existingCategory, systemImage: "checkmark")
                        } else {
                            Text(existingCategory)
                        }
                    }
                }

                if !existingCategories.isEmpty {
                    Divider()
                }

                Button {
                    newCategory = ""
                    isPresentingNewCategory = true
                } label: {
                    Label("New category…", systemImage: "plus")
                }
            } label: {
                HStack {
                    Label("Category", systemImage: "tag")
                    Spacer()
                    Text(trimmedCategory.isEmpty ? "Select" : trimmedCategory)
                        .foregroundStyle(trimmedCategory.isEmpty ? .secondary : .primary)
                }
                .contentShape(Rectangle())
            }

            TextField("Description", text: $transactionDescription)

            DatePicker(
                "Date",
                selection: $date,
                displayedComponents: [.date]
            )

            TextField("Account", text: $account)
                .textContentType(.organizationName)
        } header: {
            Text("Details")
        } footer: {
            if trimmedCategory.isEmpty {
                Text("Select a category.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var recurringSection: some View {
        Section {
            Toggle("Recurring monthly", isOn: $isRecurring)
                .disabled(transactionToEdit != nil || !supportsRecurring)
        } footer: {
            if transactionToEdit != nil {
                Text("Recurring plans can be created from a new transaction.")
            } else if !supportsRecurring {
                Text("Recurring plans are available for income and expenses.")
            } else if isRecurring {
                Text(recurringExplanation)
            }
        }
    }

    @ViewBuilder
    private var settlementSection: some View {
        if transactionToEdit == nil, !isRecurring, !settlementOccurrences.isEmpty {
            Section {
                Picker("Planned occurrence", selection: $selectedSettlementID) {
                    ForEach(settlementOccurrences) { occurrence in
                        Text(settlementLabel(occurrence))
                            .tag(Optional(occurrence.id))
                    }

                    Text(extraIncomeOrExpenseLabel)
                        .tag(Optional(extraSettlementID))
                }
                .pickerStyle(.menu)
            } header: {
                Text(transactionType == .income ? "Match planned income" : "Match a bill")
            } footer: {
                Text("Linking this transaction marks the selected planned occurrence as settled.")
            }
        }
    }

    private var noteSection: some View {
        Section("Optional note") {
            TextField("Note", text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button(action: save) {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(saveButtonTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .disabled(!canSave || isSaving)
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var commonTypeBinding: Binding<TransactionType?> {
        Binding(
            get: {
                switch transactionType {
                case .income, .expense:
                    return transactionType
                case .savings, .transfer:
                    return nil
                }
            },
            set: { selectedType in
                if let selectedType {
                    transactionType = selectedType
                }
            }
        )
    }

    private var amountFormat: Decimal.FormatStyle.Currency {
        Decimal.FormatStyle.Currency(code: appState.currencyCode)
            .precision(.fractionLength(0...2))
    }

    private var hasValidAmount: Bool {
        guard let amount else {
            return false
        }
        return amount > .zero
    }

    private var canSave: Bool {
        hasValidAmount && !trimmedCategory.isEmpty
    }

    private var supportsRecurring: Bool {
        transactionType == .income || transactionType == .expense
    }

    private var navigationTitle: String {
        transactionToEdit == nil ? "Add Transaction" : "Edit Transaction"
    }

    private var saveButtonTitle: String {
        transactionToEdit == nil ? "Save Transaction" : "Save Changes"
    }

    private var moreMenuTitle: String {
        switch transactionType {
        case .savings, .transfer:
            return transactionType.displayName
        case .income, .expense:
            return "More"
        }
    }

    private var recurringExplanation: String {
        transactionType == .income
            ? "This creates a monthly income source instead of a one-off transaction."
            : "This creates a monthly bill instead of a one-off transaction."
    }

    private var trimmedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        transactionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewCategory: String {
        newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureInitialState() {
        loadCategories()

        if !didLoadStoredDetails {
            didLoadStoredDetails = true
            if let storedTransaction = storedTransactions.first {
                account = storedTransaction.account
                note = storedTransaction.note
            }
        }

        if !didConfigureInitialDate {
            didConfigureInitialDate = true
            if transactionToEdit == nil, !isDuplicate {
                date = defaultDate(for: appState.selectedMonth)
            }
        }

        loadSettlementOccurrences()

        Task { @MainActor in
            isAmountFocused = true
        }
    }

    private func loadCategories() {
        var categories = Set(
            repository.transactions(in: appState.selectedMonth)
                .map(\.category)
                .filter { !$0.isEmpty }
        )
        categories.formUnion(
            repository.budgets(for: appState.selectedMonth)
                .map(\.category)
                .filter { !$0.isEmpty }
        )
        categories.formUnion(
            repository.bills().map(\.category).filter { !$0.isEmpty }
        )

        if !repository.incomeSources().isEmpty || transactionType == .income {
            categories.insert("Income")
        }
        if !trimmedCategory.isEmpty {
            categories.insert(trimmedCategory)
        }

        existingCategories = categories.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func defaultDate(for month: MonthKey) -> Date {
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = MonthKey(date: now, calendar: calendar)

        if month.contains(now, calendar: calendar) {
            return now
        }

        if month < currentMonth {
            return month.endDate(calendar: calendar)
        }

        return month.startDate(calendar: calendar)
    }

    private func addNewCategory() {
        guard !trimmedNewCategory.isEmpty else {
            return
        }

        category = trimmedNewCategory
        if !existingCategories.contains(trimmedNewCategory) {
            existingCategories.append(trimmedNewCategory)
            existingCategories.sort {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
        newCategory = ""
    }

    private func loadSettlementOccurrences() {
        guard transactionToEdit == nil, !isRecurring else {
            settlementOccurrences = []
            selectedSettlementID = nil
            return
        }

        let calendar = Calendar.current
        let month = MonthKey(date: date, calendar: calendar)
        let viewModel = TransactionsViewModel(
            repository: repository,
            projectionStore: projectionStore,
            calendar: calendar
        )
        let occurrences = viewModel.unsettledOccurrences(for: transactionType, in: month)
        settlementOccurrences = occurrences

        if let selectedSettlementID,
           selectedSettlementID == extraSettlementID
            || occurrences.contains(where: { $0.id == selectedSettlementID }) {
            return
        }

        self.selectedSettlementID = occurrences.min { lhs, rhs in
            let lhsDistance = abs(lhs.occurrenceDate.timeIntervalSince(date))
            let rhsDistance = abs(rhs.occurrenceDate.timeIntervalSince(date))
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.occurrenceDate < rhs.occurrenceDate
        }?.id
    }

    private func applySettlementDefaults() {
        guard let selectedSettlement else {
            return
        }

        if trimmedCategory.isEmpty {
            category = selectedSettlement.category
        }
        if trimmedDescription.isEmpty {
            transactionDescription = selectedSettlement.name
        }
        if amount == nil || amount == .zero {
            amount = selectedSettlement.amount
        }
    }

    private var selectedSettlement: TransactionSettlementOccurrence? {
        guard let selectedSettlementID else {
            return nil
        }
        return settlementOccurrences.first { $0.id == selectedSettlementID }
    }

    private var extraSettlementID: String {
        "extra-\(transactionType.rawValue)"
    }

    private var extraIncomeOrExpenseLabel: String {
        transactionType == .income
            ? "Not one of these — extra income"
            : "Not one of these — extra expense"
    }

    private func settlementLabel(_ occurrence: TransactionSettlementOccurrence) -> String {
        let dateText = occurrence.occurrenceDate.formatted(.dateTime.month(.abbreviated).day())
        let amountText = MoneyFormatter.string(
            occurrence.amount,
            currencyCode: appState.currencyCode
        )
        return "\(occurrence.name) · \(dateText) · \(amountText)"
    }

    private func save() {
        guard let amount, amount > .zero, !trimmedCategory.isEmpty else {
            return
        }

        isSaving = true

        do {
            if isRecurring {
                try saveRecurring(amount: amount)
            } else if let transactionToEdit {
                try repository.updateTransaction(
                    TransactionEntity(
                        id: transactionToEdit.id,
                        date: date,
                        amount: amount,
                        type: transactionType,
                        category: trimmedCategory,
                        detail: resolvedDescription,
                        note: trimmedNote,
                        account: trimmedAccount,
                        settlesBillID: transactionToEdit.settlesBillID,
                        settlesIncomeID: transactionToEdit.settlesIncomeID
                    )
                )
            } else if let selectedSettlement {
                switch selectedSettlement.kind {
                case .income:
                    try repository.markIncomeReceived(
                        incomeID: selectedSettlement.sourceID,
                        occurrence: selectedSettlement.occurrenceDate,
                        amount: amount,
                        on: date
                    )
                case .bill:
                    try repository.markBillPaid(
                        billID: selectedSettlement.sourceID,
                        occurrence: selectedSettlement.occurrenceDate,
                        amount: amount,
                        on: date
                    )
                }
            } else {
                try repository.addTransaction(
                    TransactionEntity(
                        date: date,
                        amount: amount,
                        type: transactionType,
                        category: trimmedCategory,
                        detail: resolvedDescription,
                        note: trimmedNote,
                        account: trimmedAccount
                    )
                )
            }

            projectionStore.refresh()
            onSaved()
            if appState.isHapticsEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            dismiss()
        } catch {
            isSaving = false
            presentedError = PresentedError(message: message(for: error))
        }
    }

    private func saveRecurring(amount: Decimal) throws {
        if transactionType == .income {
            try repository.addIncomeSource(
                IncomeSourceEntity(
                    name: resolvedDescription,
                    expectedAmount: amount,
                    frequency: .monthly,
                    anchorDate: date
                )
            )
        } else {
            try repository.addBill(
                RecurringBillEntity(
                    name: resolvedDescription,
                    amount: amount,
                    amountType: .fixed,
                    category: trimmedCategory,
                    frequency: .monthly,
                    anchorDate: date
                )
            )
        }
    }

    private var resolvedDescription: String {
        trimmedDescription.isEmpty ? trimmedCategory : trimmedDescription
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAccount: String {
        account.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func message(for error: Error) -> String {
        if let repositoryError = error as? FinanceRepositoryError,
           repositoryError == .settlementMustUseDedicatedMethod {
            return "Transactions linked to planned income or bills cannot be edited here."
        }

        return "The transaction could not be saved. Please try again."
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}

#if DEBUG
#Preview("Add Transaction") {
    FlowPlanPreviewHost {
        AddTransactionView()
    }
}
#endif
