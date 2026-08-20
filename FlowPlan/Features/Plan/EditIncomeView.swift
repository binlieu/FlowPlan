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
    @State private var presentedError: PresentedError?

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
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Expected amount", text: $amountText)
                        .font(.largeTitle.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
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
                        .disabled(!isValid || isSaving)
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
                    title: Text("Unable to save income"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && parsedAmount.map { $0 > .zero } == true
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
            showSaveError()
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
            showSaveError()
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
            message: "The income source could not be saved. Please try again."
        )
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}

enum PlanAmountParser {
    static func decimal(from text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func text(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}
