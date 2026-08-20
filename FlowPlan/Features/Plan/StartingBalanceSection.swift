import SwiftUI
import FlowPlanDomain

struct StartingBalanceSection: View {
    enum ExplicitBalanceAction: Equatable {
        case useRolledOverAmount
        case clear
    }

    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var amountText = ""
    @State private var resolvedAmount = Decimal.zero
    @State private var balanceSource = StartingBalanceResolution.Source.unset
    @State private var presentedError: String?
    @State private var isSaving = false
    @State private var hasEditedAmount = false
    @State private var isShowingClearConfirmation = false

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

                balanceAction

                if let presentedError {
                    Text(presentedError)
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.negative)
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
        .alert("Clear starting balance?", isPresented: $isShowingClearConfirmation) {
            Button("Clear", role: .destructive, action: removeExplicitBalance)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes this month's starting balance. This month's projection will use zero.")
        }
        .disabled(isSaving)
    }

    @ViewBuilder
    private var balanceExplanation: some View {
        if appState.carryBalanceForward {
            switch balanceSource {
            case .explicit, .unset:
                explanationText("What you had available at the start of the month.")
            case .rolledOver(let previousMonth):
                explanationText(
                    "Rolled over from \(monthName(previousMonth)) · "
                        + MoneyFormatter.string(
                            resolvedAmount,
                            currencyCode: appState.currencyCode
                        )
                )
            }
        } else {
            explanationText(Self.standaloneExplanation(source: balanceSource))
        }
    }

    @ViewBuilder
    private var balanceAction: some View {
        switch Self.availableAction(
            carryBalanceForward: appState.carryBalanceForward,
            source: balanceSource
        ) {
        case .useRolledOverAmount:
            balanceActionButton(
                "Use rolled-over amount",
                accessibilityHint: "Deletes this month's explicit starting balance",
                action: removeExplicitBalance
            )
        case .clear:
            balanceActionButton(
                "Clear",
                accessibilityHint: "Removes this month's starting balance after confirmation"
            ) {
                isShowingClearConfirmation = true
            }
        case nil:
            EmptyView()
        }
    }

    private func explanationText(_ text: String) -> some View {
        Text(text)
            .font(Typography.supporting)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func balanceActionButton(
        _ title: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(Typography.supporting.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Palette.accent)
            .accessibilityHint(accessibilityHint)
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
        amountText = Self.displayText(for: resolution)
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

    private func removeExplicitBalance() {
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

    static func availableAction(
        carryBalanceForward: Bool,
        source: StartingBalanceResolution.Source
    ) -> ExplicitBalanceAction? {
        guard source == .explicit else {
            return nil
        }

        return carryBalanceForward ? .useRolledOverAmount : .clear
    }

    static func standaloneExplanation(source: StartingBalanceResolution.Source) -> String {
        var explanation = "What you had available at the start of the month. "
            + "Each month is entered separately because Carry balance forward is off."

        if source == .unset {
            explanation += " Enter this month's starting balance so your projection is accurate."
        }

        return explanation
    }

    static func displayText(
        for resolution: StartingBalanceResolution,
        locale: Locale = .current
    ) -> String {
        guard resolution.source != .unset else {
            return ""
        }

        return PlanAmountParser.text(resolution.amount, locale: locale)
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
