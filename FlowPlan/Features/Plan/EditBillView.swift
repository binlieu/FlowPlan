import SwiftUI
import FlowPlanDomain

struct EditBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let bill: PlannedBill?

    @State private var name: String
    @State private var amountText: String
    @State private var amountType: BillAmountType
    @State private var category: String
    @State private var frequency: RecurrenceFrequency
    @State private var anchorDate: Date
    @State private var isAutoPay: Bool
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var isShowingDeleteOptions = false
    @State private var presentedError: PresentedError?

    init(bill: PlannedBill? = nil) {
        self.bill = bill
        _name = State(initialValue: bill?.name ?? "")
        _amountText = State(initialValue: bill.map { PlanAmountParser.text($0.amount) } ?? "")
        _amountType = State(initialValue: bill?.amountType ?? .fixed)
        _category = State(initialValue: bill?.category ?? "")
        _frequency = State(initialValue: bill?.recurrence.frequency ?? .monthly)
        _anchorDate = State(initialValue: bill?.recurrence.anchorDate ?? Date())
        _isAutoPay = State(initialValue: bill?.isAutoPay ?? false)
        _isActive = State(initialValue: bill?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Amount", text: $amountText)
                        .font(.largeTitle.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .keyboardType(.decimalPad)

                    Picker("Amount type", selection: $amountType) {
                        ForEach(BillAmountType.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }

                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.words)
                }

                Section("Recurrence") {
                    RecurrencePicker(
                        frequency: $frequency,
                        anchorDate: $anchorDate
                    )
                }

                Section {
                    Toggle("Auto-pay", isOn: $isAutoPay)
                    Toggle("Active", isOn: $isActive)
                }

                if bill != nil {
                    Section {
                        Button("Deactivate or Delete", role: .destructive) {
                            isShowingDeleteOptions = true
                        }
                    }
                }
            }
            .navigationTitle(bill == nil ? "Add Bill" : "Edit Bill")
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
                "What would you like to do with \(resolvedName)?",
                isPresented: $isShowingDeleteOptions,
                titleVisibility: .visible
            ) {
                Button("Deactivate \(resolvedName)") {
                    deactivate()
                }

                Button("Delete \(resolvedName)", role: .destructive) {
                    deleteBill()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deactivation preserves linked history. Deleting unlinks past transactions.")
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Unable to save bill"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var parsedAmount: Decimal? {
        PlanAmountParser.decimal(from: amountText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedName: String {
        trimmedName.isEmpty ? (bill?.name ?? "bill") : trimmedName
    }

    private var isValid: Bool {
        !trimmedName.isEmpty
            && !trimmedCategory.isEmpty
            && parsedAmount.map { $0 > .zero } == true
    }

    private func save() {
        guard let amount = parsedAmount, isValid else {
            return
        }

        isSaving = true

        do {
            let entity = RecurringBillEntity(
                id: bill?.id ?? UUID(),
                name: trimmedName,
                amount: amount,
                amountType: amountType,
                category: trimmedCategory,
                frequency: frequency,
                anchorDate: anchorDate,
                endDate: bill?.recurrence.endDate,
                isAutoPay: isAutoPay,
                isActive: isActive
            )

            if bill == nil {
                try repository.addBill(entity)
            } else {
                try repository.updateBill(entity)
            }

            finish()
        } catch {
            showSaveError()
        }
    }

    private func deactivate() {
        guard let bill else {
            return
        }

        do {
            try repository.updateBill(
                RecurringBillEntity(
                    id: bill.id,
                    name: bill.name,
                    amount: bill.amount,
                    amountType: bill.amountType,
                    category: bill.category,
                    frequency: bill.recurrence.frequency,
                    anchorDate: bill.recurrence.anchorDate,
                    endDate: bill.recurrence.endDate,
                    isAutoPay: bill.isAutoPay,
                    isActive: false
                )
            )
            finish()
        } catch {
            showSaveError()
        }
    }

    private func deleteBill() {
        guard let bill else {
            return
        }

        do {
            try repository.deleteBill(id: bill.id)
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
            message: "The bill could not be saved. Please try again."
        )
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}
