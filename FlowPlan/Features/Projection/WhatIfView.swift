import SwiftUI
import FlowPlanDomain

struct WhatIfView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let projection: MonthlyProjection

    @State private var amountText = ""
    @State private var transactionDescription = ""
    @State private var transactionType = ScenarioTransactionType.expense
    @State private var result: WhatIfResult?
    @State private var presentedError: PresentedError?

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $amountText)
                        .formAmountTypography()
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .accessibilityLabel("Amount")
                }

                Section("Details") {
                    TextField("Description", text: $transactionDescription)

                    Picker("Transaction type", selection: $transactionType) {
                        ForEach(ScenarioTransactionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Projection") {
                    if let result {
                        simulationSummary(result)
                    } else {
                        neutralSummary
                    }
                }

                Section {
                    Button(saveButtonTitle) {
                        saveTransaction()
                    }
                    .frame(maxWidth: .infinity)
                    .prominentLabelTypography()
                    .disabled(validAmount == nil)
                } footer: {
                    Text("This is only added to your transactions when you use the button above.")
                }
            }
            .navigationTitle("What If?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: amountText, initial: true) {
                updateSimulation()
            }
            .onChange(of: transactionType) {
                updateSimulation()
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Unable to add transaction"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func simulationSummary(_ result: WhatIfResult) -> some View {
        VStack(spacing: Spacing.sm) {
            figureRow(
                title: "Current Projection",
                amount: result.base.projectedEndOfMonthBalance
            )
            figureRow(
                title: transactionType == .expense ? "After Purchase" : "After Income",
                amount: result.simulated.projectedEndOfMonthBalance
            )
            figureRow(title: "Impact", amount: result.impact, signed: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(result))
    }

    private var neutralSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            figureRow(
                title: "Current Projection",
                amount: projection.projectedEndOfMonthBalance
            )

            Text("Enter an amount to see how it changes your projection.")
                .footnoteTypography()
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func figureRow(
        title: String,
        amount: Decimal,
        signed: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(title)
                .foregroundStyle(Palette.inkSecondary)

            Spacer(minLength: Spacing.sm)

            AmountText(
                amount: amount,
                style: .primary,
                signed: signed,
                emphasiseNegative: true
            )
        }
    }

    private var validAmount: Decimal? {
        guard let amount = try? Decimal.FormatStyle.number.parseStrategy.parse(amountText),
              amount > .zero else {
            return nil
        }
        return amount
    }

    private var saveButtonTitle: String {
        transactionType == .expense ? "Add as Expense" : "Add as Income"
    }

    private func updateSimulation() {
        guard let amount = validAmount else {
            result = nil
            return
        }

        result = projectionStore.simulate(
            WhatIfScenario(
                additionalTransactions: [scenarioTransaction(amount: amount)]
            )
        )
    }

    private func saveTransaction() {
        guard let amount = validAmount else {
            return
        }

        do {
            try repository.addTransaction(
                TransactionEntity(domain: scenarioTransaction(amount: amount))
            )
            projectionStore.refresh()
            dismiss()
        } catch {
            presentedError = PresentedError(
                message: "The transaction could not be added. Please try again."
            )
        }
    }

    private func scenarioTransaction(amount: Decimal) -> TransactionSnapshot {
        TransactionSnapshot(
            id: UUID(),
            date: transactionDate,
            amount: amount,
            type: transactionType.domainValue,
            category: transactionType.category,
            detail: enteredDescription
        )
    }

    private var transactionDate: Date {
        let now = Date()
        let calendar = Calendar.current

        if projection.month.contains(now, calendar: calendar) {
            return now
        }

        return projection.month.startDate(calendar: calendar)
    }

    private var enteredDescription: String {
        let trimmed = transactionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return transactionType.defaultDescription
    }

    private func accessibilitySummary(_ result: WhatIfResult) -> String {
        let current = formatted(result.base.projectedEndOfMonthBalance)
        let simulated = formatted(result.simulated.projectedEndOfMonthBalance)
        let afterLabel = transactionType == .expense ? "After this purchase" : "After this income"
        return "Current projection \(current). \(afterLabel), \(simulated). Impact, \(formatted(result.impact, signed: true))."
    }

    private func formatted(_ amount: Decimal, signed: Bool = false) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: signed
        )
    }

    private enum ScenarioTransactionType: String, CaseIterable, Identifiable {
        case expense
        case income

        var id: String { rawValue }

        var title: String {
            switch self {
            case .expense:
                return "Expense"
            case .income:
                return "Income"
            }
        }

        var domainValue: TransactionType {
            switch self {
            case .expense:
                return .expense
            case .income:
                return .income
            }
        }

        var category: String {
            switch self {
            case .expense:
                return "What If"
            case .income:
                return "Income"
            }
        }

        var defaultDescription: String {
            switch self {
            case .expense:
                return "What-if purchase"
            case .income:
                return "What-if income"
            }
        }
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        WhatIfView(projection: FlowPlanPreviewData.projection())
    }
}
#endif
