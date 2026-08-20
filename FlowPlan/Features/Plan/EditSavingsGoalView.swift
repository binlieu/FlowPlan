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
    @State private var presentedError: PresentedError?

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
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Monthly target", text: $monthlyTargetText)
                        .font(.largeTitle.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .keyboardType(.decimalPad)

                    TextField("Overall target", text: $overallTargetText)
                        .keyboardType(.decimalPad)
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
                        .disabled(!isValid || isSaving)
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
                    title: Text("Unable to save savings goal"),
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
        !trimmedName.isEmpty
            && parsedMonthlyTarget.map { $0 > .zero } == true
            && parsedOverallTarget.map { $0 > .zero } == true
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
            showSaveError()
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
            message: "The savings goal could not be saved. Please try again."
        )
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}
