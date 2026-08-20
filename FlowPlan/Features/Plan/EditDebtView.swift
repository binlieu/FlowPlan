import SwiftUI
import FlowPlanDomain

struct EditDebtView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let debt: Debt?

    @State private var name: String
    @State private var balanceText: String
    @State private var aprText: String
    @State private var paymentText: String
    @State private var category: String
    @State private var dueDay: Int
    @State private var isPaidThroughBills: Bool
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var isShowingDeleteOptions = false
    @State private var presentedError: PresentedError?
    @State private var hasAttemptedSave = false

    init(debt: Debt? = nil) {
        self.debt = debt
        _name = State(initialValue: debt?.name ?? "")
        _balanceText = State(
            initialValue: debt.map { PlanAmountParser.text($0.currentBalance) } ?? ""
        )
        _aprText = State(
            initialValue: debt.map { PlanAmountParser.text($0.annualInterestRate * 100) } ?? ""
        )
        _paymentText = State(
            initialValue: debt.map { PlanAmountParser.text($0.monthlyPayment) } ?? ""
        )
        _category = State(initialValue: debt?.category ?? "")
        _dueDay = State(initialValue: debt?.dueDay ?? 1)
        _isPaidThroughBills = State(initialValue: debt?.isPaidThroughBills ?? false)
        _isActive = State(initialValue: debt?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debt") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                        PlanValidationMessage(message: visible(nameValidationMessage, for: name))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Balance remaining", text: $balanceText)
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(balanceValidationMessage, for: balanceText)
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("APR percent (optional)", text: $aprText)
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(aprValidationMessage, for: aprText)
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Monthly payment", text: $paymentText)
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(paymentValidationMessage, for: paymentText)
                        )
                    }

                    TextField("Category (optional)", text: $category)
                        .textInputAutocapitalization(.words)
                }

                Section("Payment date") {
                    Picker("Due day", selection: $dueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text(DebtDueDayText.ordinal(day)).tag(day)
                        }
                    }

                    Text("Due on the \(DebtDueDayText.ordinal(dueDay)) of each month")
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Section {
                    Toggle("Payment is in Monthly Bills", isOn: $isPaidThroughBills)
                } footer: {
                    Text(
                        "Turn this on when Monthly Bills already includes the payment. "
                            + "FlowPlan will track the debt without subtracting it twice."
                    )
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                }

                if debt != nil {
                    Section {
                        Button("Deactivate or Delete", role: .destructive) {
                            isShowingDeleteOptions = true
                        }
                    }
                }
            }
            .navigationTitle(debt == nil ? "Add Debt" : "Edit Debt")
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
            .confirmationDialog(
                "What would you like to do with \(resolvedName)?",
                isPresented: $isShowingDeleteOptions,
                titleVisibility: .visible
            ) {
                Button("Deactivate \(resolvedName)") {
                    deactivate()
                }

                Button("Delete \(resolvedName)", role: .destructive) {
                    deleteDebt()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deactivation preserves linked history. Deleting unlinks past payments.")
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Unable to save debt"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var parsedBalance: Decimal? {
        PlanAmountParser.decimal(from: balanceText)
    }

    private var parsedAPRPercentage: Decimal? {
        PlanEditorValidation.optionalDebtAPRPercentage(aprText)
    }

    private var parsedPayment: Decimal? {
        PlanAmountParser.decimal(from: paymentText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedCategory: String {
        PlanEditorValidation.debtCategory(category)
    }

    private var resolvedName: String {
        trimmedName.isEmpty ? (debt?.name ?? "debt") : trimmedName
    }

    private var isValid: Bool {
        nameValidationMessage == nil
            && balanceValidationMessage == nil
            && aprValidationMessage == nil
            && paymentValidationMessage == nil
    }

    private var nameValidationMessage: String? {
        PlanEditorValidation.requiredText(name, message: "Enter a debt name.")
    }

    private var balanceValidationMessage: String? {
        PlanEditorValidation.nonnegativeAmount(
            balanceText,
            message: "Enter a balance of zero or more."
        )
    }

    private var aprValidationMessage: String? {
        PlanEditorValidation.optionalNonnegativeAmount(
            aprText,
            message: "Enter an APR of zero or more, or leave it blank."
        )
    }

    private var paymentValidationMessage: String? {
        PlanEditorValidation.positiveAmount(
            paymentText,
            message: "Enter a monthly payment."
        )
    }

    private func visible(_ message: String?, for input: String) -> String? {
        let hasInput = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAttemptedSave || hasInput ? message : nil
    }

    private func save() {
        hasAttemptedSave = true
        guard
            let balance = parsedBalance,
            let aprPercentage = parsedAPRPercentage,
            let payment = parsedPayment,
            isValid
        else {
            return
        }

        isSaving = true

        do {
            let entity = DebtEntity(
                id: debt?.id ?? UUID(),
                name: trimmedName,
                currentBalance: balance,
                annualInterestRate: aprPercentage / 100,
                monthlyPayment: payment,
                category: resolvedCategory,
                dueDay: dueDay,
                isPaidThroughBills: isPaidThroughBills,
                isActive: isActive
            )

            if debt == nil {
                try repository.addDebt(entity)
            } else {
                try repository.updateDebt(entity)
            }

            finish()
        } catch {
            showSaveError()
        }
    }

    private func deactivate() {
        guard let debt else {
            return
        }

        do {
            try repository.updateDebt(
                DebtEntity(
                    id: debt.id,
                    name: debt.name,
                    currentBalance: debt.currentBalance,
                    annualInterestRate: debt.annualInterestRate,
                    monthlyPayment: debt.monthlyPayment,
                    category: debt.category,
                    dueDay: debt.dueDay,
                    isPaidThroughBills: debt.isPaidThroughBills,
                    isActive: false
                )
            )
            finish()
        } catch {
            showSaveError()
        }
    }

    private func deleteDebt() {
        guard let debt else {
            return
        }

        do {
            try repository.deleteDebt(id: debt.id)
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
            message: "The debt could not be saved. Please try again."
        )
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}
