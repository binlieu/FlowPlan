import SwiftUI
import FlowPlanDomain

struct EditIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let source: PlannedIncome?

    @State private var name: String
    @State private var amountText: String
    @State private var frequency: RecurrenceFrequency
    @State private var anchorDate: Date
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var isShowingDeleteOptions = false
    @State private var presentedError: WriteErrorPresentation?
    @State private var hasAttemptedSave = false

    init(source: PlannedIncome? = nil) {
        self.source = source
        _name = State(initialValue: source?.name ?? "")
        _amountText = State(
            initialValue: source.map { PlanAmountParser.text($0.expectedAmount) } ?? ""
        )
        _frequency = State(initialValue: source?.recurrence.frequency ?? .monthly)
        _anchorDate = State(initialValue: source?.recurrence.anchorDate ?? Date())
        _isActive = State(initialValue: source?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Income") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                        PlanValidationMessage(message: visible(nameValidationMessage, for: name))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Expected amount", text: $amountText)
                            .formAmountTypography()
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                        PlanValidationMessage(
                            message: visible(amountValidationMessage, for: amountText)
                        )
                    }
                }

                Section("Recurrence") {
                    RecurrencePicker(
                        frequency: $frequency,
                        anchorDate: $anchorDate
                    )
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                }

                if source != nil {
                    Section {
                        Button("Deactivate or Delete", role: .destructive) {
                            isShowingDeleteOptions = true
                        }
                    }
                }
            }
            .navigationTitle(source == nil ? "Add Income" : "Edit Income")
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
                deleteDialogTitle,
                isPresented: $isShowingDeleteOptions,
                titleVisibility: .visible
            ) {
                Button("Deactivate \(resolvedName)") {
                    deactivate()
                }

                Button("Delete \(resolvedName)", role: .destructive) {
                    deleteSource()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deactivation preserves linked history. Deleting unlinks past transactions.")
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

    private var isValid: Bool {
        nameValidationMessage == nil && amountValidationMessage == nil
    }

    private var nameValidationMessage: String? {
        PlanEditorValidation.requiredText(name, message: "Enter an income name.")
    }

    private var amountValidationMessage: String? {
        PlanEditorValidation.positiveAmount(
            amountText,
            message: "Enter an expected amount greater than zero."
        )
    }

    private func visible(_ message: String?, for input: String) -> String? {
        let hasInput = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAttemptedSave || hasInput ? message : nil
    }

    private var parsedAmount: Decimal? {
        PlanAmountParser.decimal(from: amountText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedName: String {
        trimmedName.isEmpty ? (source?.name ?? "income") : trimmedName
    }

    private var deleteDialogTitle: String {
        "What would you like to do with \(resolvedName)?"
    }

    private func save() {
        hasAttemptedSave = true
        guard let amount = parsedAmount, isValid else {
            return
        }

        isSaving = true

        do {
            let entity = IncomeSourceEntity(
                id: source?.id ?? UUID(),
                name: trimmedName,
                expectedAmount: amount,
                frequency: frequency,
                anchorDate: anchorDate,
                endDate: source?.recurrence.endDate,
                isActive: isActive
            )

            if source == nil {
                try repository.addIncomeSource(entity)
            } else {
                try repository.updateIncomeSource(entity)
            }

            finish()
        } catch {
            showError(.save, error: error)
        }
    }

    private func deactivate() {
        guard let source else {
            return
        }

        do {
            try repository.updateIncomeSource(
                IncomeSourceEntity(
                    id: source.id,
                    name: source.name,
                    expectedAmount: source.expectedAmount,
                    frequency: source.recurrence.frequency,
                    anchorDate: source.recurrence.anchorDate,
                    endDate: source.recurrence.endDate,
                    isActive: false
                )
            )
            finish()
        } catch {
            showError(.deactivate, error: error)
        }
    }

    private func deleteSource() {
        guard let source else {
            return
        }

        do {
            try repository.deleteIncomeSource(id: source.id)
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
            subject: "income source",
            error: error
        )
    }
}

enum PlanAmountParser {
    static func decimal(from text: String, locale: Locale = .current) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ""

        if value.contains(decimalSeparator) {
            let normalized = removingGroupingSeparator(
                groupingSeparator,
                from: value,
                decimalSeparator: decimalSeparator
            )
            guard isValidDecimal(normalized, decimalSeparator: decimalSeparator) else {
                return nil
            }
            return Decimal(string: normalized, locale: locale)
        }

        if let decimal = posixDecimal(from: value) {
            return decimal
        }

        let normalized = removingGroupingSeparator(
            groupingSeparator,
            from: value,
            decimalSeparator: decimalSeparator
        )
        return posixDecimal(from: normalized)
    }

    static func text(_ amount: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 16
        formatter.generatesDecimalNumbers = true

        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? NSDecimalNumber(decimal: amount).stringValue
    }

    private static func removingGroupingSeparator(
        _ groupingSeparator: String,
        from text: String,
        decimalSeparator: String
    ) -> String {
        guard !groupingSeparator.isEmpty, groupingSeparator != decimalSeparator else {
            return text
        }
        return text.replacingOccurrences(of: groupingSeparator, with: "")
    }

    private static func posixDecimal(from text: String) -> Decimal? {
        guard isValidDecimal(text, decimalSeparator: ".") else {
            return nil
        }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func isValidDecimal(_ text: String, decimalSeparator: String) -> Bool {
        var unsigned = text
        if unsigned.first == "+" || unsigned.first == "-" {
            unsigned.removeFirst()
        }

        guard !unsigned.isEmpty else {
            return false
        }

        let components = unsigned.components(separatedBy: decimalSeparator)
        guard components.count <= 2 else {
            return false
        }

        let hasDigit = components.contains { !$0.isEmpty }
        return hasDigit && components.allSatisfy { component in
            component.allSatisfy(\.isNumber)
        }
    }
}
