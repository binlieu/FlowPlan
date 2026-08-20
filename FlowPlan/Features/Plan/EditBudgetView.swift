import SwiftData
import SwiftUI
import FlowPlanDomain

struct EditBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Query private var storedBudgets: [BudgetEntity]

    let budget: BudgetAllocation?

    @State private var category: String
    @State private var limitText: String
    @State private var appliesToEveryMonth = true
    @State private var didLoadStoredScope = false
    @State private var isSaving = false
    @State private var isShowingDeleteConfirmation = false
    @State private var presentedError: PresentedError?
    @State private var hasAttemptedSave = false

    init(budget: BudgetAllocation? = nil) {
        self.budget = budget
        _category = State(initialValue: budget?.category ?? "")
        _limitText = State(
            initialValue: budget.map { PlanAmountParser.text($0.monthlyLimit) } ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Category", text: $category)
                            .textInputAutocapitalization(.words)
                        PlanValidationMessage(
                            message: visible(categoryValidationMessage, for: category)
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Monthly limit", text: $limitText)
                            .font(.largeTitle.weight(.bold))
                            .fontWidth(.condensed)
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(limitValidationMessage, for: limitText)
                        )
                    }
                }

                Section("Applies") {
                    if budget == nil {
                        Toggle("Every month", isOn: $appliesToEveryMonth)
                    }

                    Text(scopeDescription)
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if budget != nil {
                    Section {
                        Button("Delete \(resolvedCategory)", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(budget == nil ? "Add Budget" : "Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isSaving)
                }
            }
            .onAppear(perform: loadStoredScope)
            .alert(
                "Delete \(resolvedCategory)?",
                isPresented: $isShowingDeleteConfirmation
            ) {
                Button("Delete", role: .destructive, action: deleteBudget)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the budget row. Past transactions are not deleted.")
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Unable to save budget"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var parsedLimit: Decimal? {
        PlanAmountParser.decimal(from: limitText)
    }

    private var trimmedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedCategory: String {
        trimmedCategory.isEmpty ? (budget?.category ?? "budget") : trimmedCategory
    }

    private var isValid: Bool {
        categoryValidationMessage == nil && limitValidationMessage == nil
    }

    private var categoryValidationMessage: String? {
        PlanEditorValidation.requiredText(category, message: "Enter a budget category.")
    }

    private var limitValidationMessage: String? {
        PlanEditorValidation.positiveAmount(
            limitText,
            message: "Enter a monthly limit greater than zero."
        )
    }

    private func visible(_ message: String?, for input: String) -> String? {
        let hasInput = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAttemptedSave || hasInput ? message : nil
    }

    private var scopeDescription: String {
        if appliesToEveryMonth {
            return "This budget applies to every month unless that month has its own plan."
        }

        return "This budget applies only to \(selectedMonthName)."
    }

    private var selectedMonthName: String {
        appState.selectedMonth
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide).year())
    }

    private func loadStoredScope() {
        guard !didLoadStoredScope else {
            return
        }

        didLoadStoredScope = true
        guard
            let budget,
            let stored = storedBudgets.first(where: { $0.id == budget.id })
        else {
            return
        }

        appliesToEveryMonth = stored.scopeYear == nil && stored.scopeMonth == nil
    }

    private func save() {
        hasAttemptedSave = true
        guard let limit = parsedLimit, isValid else {
            return
        }

        isSaving = true

        do {
            if let budget {
                let stored = storedBudgets.first { $0.id == budget.id }
                try repository.updateBudget(
                    BudgetEntity(
                        id: budget.id,
                        category: trimmedCategory,
                        monthlyLimit: limit,
                        scopeYear: stored?.scopeYear,
                        scopeMonth: stored?.scopeMonth
                    )
                )
            } else if appliesToEveryMonth {
                try repository.addBudget(
                    BudgetEntity(category: trimmedCategory, monthlyLimit: limit)
                )
            } else {
                try createMonthOverrideIfNeeded()
                try repository.addBudget(
                    BudgetEntity(
                        category: trimmedCategory,
                        monthlyLimit: limit,
                        scopeYear: appState.selectedMonth.year,
                        scopeMonth: appState.selectedMonth.month
                    )
                )
            }

            finish()
        } catch {
            showSaveError()
        }
    }

    private func createMonthOverrideIfNeeded() throws {
        let selectedMonth = appState.selectedMonth
        let hasOverride = storedBudgets.contains {
            $0.scopeYear == selectedMonth.year && $0.scopeMonth == selectedMonth.month
        }

        guard !hasOverride else {
            return
        }

        let defaults = storedBudgets.filter {
            $0.scopeYear == nil && $0.scopeMonth == nil
        }

        for defaultBudget in defaults {
            try repository.addBudget(
                BudgetEntity(
                    category: defaultBudget.category,
                    monthlyLimit: defaultBudget.monthlyLimit,
                    scopeYear: selectedMonth.year,
                    scopeMonth: selectedMonth.month
                )
            )
        }
    }

    private func deleteBudget() {
        guard let budget else {
            return
        }

        do {
            try repository.deleteBudget(id: budget.id)
            finish()
        } catch {
            showSaveError()
        }
    }

    private func finish() {
        projectionStore.refresh()
        dismiss()
    }

    private func showSaveError() {
        isSaving = false
        presentedError = PresentedError(
            message: "The budget could not be saved. Please try again."
        )
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}
