import SwiftData
import SwiftUI
import FlowPlanDomain

struct EditSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Query private var storedGoals: [SavingsGoalEntity]

    let plan: SavingsPlan?

    @State private var name: String
    @State private var monthlyTargetText: String
    @State private var overallTargetText = ""
    @State private var currentAmount: Decimal = .zero
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var isActive = true
    @State private var didLoadStoredGoal = false
    @State private var isSaving = false
    @State private var isShowingDeleteConfirmation = false
    @State private var presentedError: WriteErrorPresentation?
    @State private var hasAttemptedSave = false

    init(plan: SavingsPlan? = nil) {
        self.plan = plan
        _name = State(initialValue: plan?.name ?? "")
        _monthlyTargetText = State(
            initialValue: plan.map { PlanAmountParser.text($0.monthlyTarget) } ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Savings goal") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                        PlanValidationMessage(message: visible(nameValidationMessage, for: name))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Monthly target", text: $monthlyTargetText)
                            .formAmountTypography()
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(
                                monthlyTargetValidationMessage,
                                for: monthlyTargetText
                            )
                        )
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Overall target", text: $overallTargetText)
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(
                                overallTargetValidationMessage,
                                for: overallTargetText
                            )
                        )
                    }
                }

                Section("Target date") {
                    Toggle("Set a target date", isOn: $hasTargetDate)

                    if hasTargetDate {
                        DatePicker(
                            "Date",
                            selection: $targetDate,
                            displayedComponents: .date
                        )
                    }
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                }

                if plan != nil {
                    Section {
                        Button("Delete \(resolvedName)", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(plan == nil ? "Add Savings Goal" : "Edit Savings Goal")
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
            .onAppear(perform: loadStoredGoal)
            .alert(
                "Delete \(resolvedName)?",
                isPresented: $isShowingDeleteConfirmation
            ) {
                Button("Delete", role: .destructive, action: deleteGoal)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes the goal. Savings transactions remain in your history.")
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var parsedMonthlyTarget: Decimal? {
        PlanAmountParser.decimal(from: monthlyTargetText)
    }

    private var parsedOverallTarget: Decimal? {
        PlanAmountParser.decimal(from: overallTargetText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedName: String {
        trimmedName.isEmpty ? (plan?.name ?? "savings goal") : trimmedName
    }

    private var isValid: Bool {
        nameValidationMessage == nil
            && monthlyTargetValidationMessage == nil
            && overallTargetValidationMessage == nil
    }

    private var nameValidationMessage: String? {
        PlanEditorValidation.requiredText(name, message: "Enter a savings goal name.")
    }

    private var monthlyTargetValidationMessage: String? {
        PlanEditorValidation.positiveAmount(
            monthlyTargetText,
            message: "Enter a monthly target greater than zero."
        )
    }

    private var overallTargetValidationMessage: String? {
        PlanEditorValidation.positiveAmount(
            overallTargetText,
            message: "Enter an overall target greater than zero."
        )
    }

    private func visible(_ message: String?, for input: String) -> String? {
        let hasInput = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAttemptedSave || hasInput ? message : nil
    }

    private func loadStoredGoal() {
        guard !didLoadStoredGoal else {
            return
        }

        didLoadStoredGoal = true
        guard
            let plan,
            let stored = storedGoals.first(where: { $0.id == plan.id })
        else {
            return
        }

        overallTargetText = PlanAmountParser.text(stored.targetAmount)
        currentAmount = stored.currentAmount
        hasTargetDate = stored.targetDate != nil
        targetDate = stored.targetDate ?? Date()
        isActive = stored.isActive
    }

    private func save() {
        hasAttemptedSave = true
        guard
            let monthlyTarget = parsedMonthlyTarget,
            let overallTarget = parsedOverallTarget,
            isValid
        else {
            return
        }

        isSaving = true

        do {
            let entity = SavingsGoalEntity(
                id: plan?.id ?? UUID(),
                name: trimmedName,
                targetAmount: overallTarget,
                monthlyTarget: monthlyTarget,
                currentAmount: currentAmount,
                targetDate: hasTargetDate ? targetDate : nil,
                isActive: isActive
            )

            if plan == nil {
                try repository.addSavingsGoal(entity)
            } else {
                try repository.updateSavingsGoal(entity)
            }

            finish()
        } catch {
            showError(.save, error: error)
        }
    }

    private func deleteGoal() {
        guard let plan else {
            return
        }

        do {
            try repository.deleteSavingsGoal(id: plan.id)
            finish()
        } catch {
            showError(.delete, error: error)
        }
    }

    private func finish() {
        projectionStore.refresh()
        dismiss()
    }

    private func showError(_ operation: WriteOperation, error: Error) {
        isSaving = false
        presentedError = WriteErrorPresentation(
            operation: operation,
            subject: "savings goal",
            error: error
        )
    }
}
