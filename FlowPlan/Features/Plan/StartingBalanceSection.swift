import SwiftUI
import FlowPlanDomain

struct StartingBalanceSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var amountText = ""
    @State private var presentedError: String?
    @State private var isSaving = false

    @FocusState private var isAmountFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starting Balance")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("0.00", text: $amountText)
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

                Text("What you had available at the start of the month.")
                    .font(Typography.supporting)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

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
        .onChange(of: isAmountFocused) {
            if !isAmountFocused {
                commit()
            }
        }
        .disabled(isSaving)
    }

    private func loadBalance() {
        amountText = PlanAmountParser.text(
            repository.startingBalance(for: appState.selectedMonth)
        )
        presentedError = nil
    }

    private func commit() {
        guard !isSaving else {
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
            presentedError = nil
            projectionStore.refresh()
        } catch {
            presentedError = "The starting balance could not be saved. Please try again."
        }
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
