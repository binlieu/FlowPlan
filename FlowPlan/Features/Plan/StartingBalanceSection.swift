import SwiftUI
import FlowPlanDomain

struct StartingBalanceSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var amountText = ""
    @State private var resolvedAmount = Decimal.zero
    @State private var balanceSource = StartingBalanceResolution.Source.unset
    @State private var presentedError: String?
    @State private var isSaving = false
    @State private var hasEditedAmount = false

    @FocusState private var isAmountFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starting Balance")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("0.00", text: amountBinding)
                        .font(.title2.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .onSubmit(commit)
                        .accessibilityLabel("Starting balance amount")

                    Text(appState.currencyCode)
                        .smallCapsTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }

                balanceExplanation

                if balanceSource == .explicit {
                    Button("Use rolled-over amount", action: useRolledOverAmount)
                        .font(Typography.supporting.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.accent)
                        .accessibilityHint("Deletes this month's explicit starting balance")
                }

                if let presentedError {
                    Text(presentedError)
                        .font(Typography.supporting)
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
        }
        .onAppear(perform: loadBalance)
        .onChange(of: appState.selectedMonth) {
            loadBalance()
        }
        .onChange(of: appState.carryBalanceForward) {
            loadBalance()
        }
        .onChange(of: isAmountFocused) {
            if !isAmountFocused {
                commit()
            }
        }
        .disabled(isSaving)
    }

    @ViewBuilder
    private var balanceExplanation: some View {
        switch balanceSource {
        case .explicit, .unset:
            Text("What you had available at the start of the month.")
                .font(Typography.supporting)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .rolledOver(let previousMonth):
            Text(
                "Rolled over from \(monthName(previousMonth)) · "
                    + MoneyFormatter.string(
                        resolvedAmount,
                        currencyCode: appState.currencyCode
                    )
            )
            .font(Typography.supporting)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var amountBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                amountText = newValue
                hasEditedAmount = true
            }
        )
    }

    private func loadBalance() {
        let resolution = repository.startingBalanceResolution(for: appState.selectedMonth)
        amountText = PlanAmountParser.text(resolution.amount)
        resolvedAmount = resolution.amount
        balanceSource = resolution.source
        hasEditedAmount = false
        presentedError = nil
    }

    private func commit() {
        guard !isSaving, hasEditedAmount else {
            return
        }
        guard let balance = PlanAmountParser.decimal(from: amountText) else {
            presentedError = "Enter a valid amount."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try repository.setStartingBalance(balance, for: appState.selectedMonth)
            amountText = PlanAmountParser.text(balance)
            resolvedAmount = balance
            balanceSource = .explicit
            hasEditedAmount = false
            presentedError = nil
            projectionStore.refresh()
        } catch {
            presentedError = WriteErrorPresentation(
                operation: .save,
                subject: "starting balance",
                error: error
            ).inlineMessage
        }
    }

    private func useRolledOverAmount() {
        guard !isSaving else {
            return
        }

        isSaving = true
        hasEditedAmount = false
        isAmountFocused = false
        defer { isSaving = false }

        do {
            try repository.deleteStartingBalance(for: appState.selectedMonth)
            projectionStore.refresh()
            loadBalance()
        } catch {
            loadBalance()
            presentedError = WriteErrorPresentation(
                operation: .reset,
                subject: "starting balance",
                error: error
            ).inlineMessage
        }
    }

    private func monthName(_ month: MonthKey) -> String {
        month.startDate(calendar: .current).formatted(.dateTime.month(.wide))
    }
}

#if DEBUG
#Preview("Starting Balance") {
    FlowPlanPreviewHost {
        StartingBalanceSection()
            .padding(20)
            .background(Palette.background)
    }
}
#endif
