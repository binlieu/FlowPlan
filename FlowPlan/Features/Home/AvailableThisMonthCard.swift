import SwiftUI
import FlowPlanDomain

struct AvailableThisMonthCard: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let projection: MonthlyProjection
    let completeness: ProjectionCompleteness
    let hasOrphanedDebt: Bool
    let onOpenPlan: () -> Void

    @State private var startingBalanceText = ""
    @State private var startingBalanceError: String?
    @State private var isSavingStartingBalance = false

    @FocusState private var isStartingBalanceFocused: Bool

    init(
        projection: MonthlyProjection,
        completeness: ProjectionCompleteness? = nil,
        hasOrphanedDebt: Bool = false,
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.projection = projection
        self.completeness = completeness ?? projection.completeness
        self.hasOrphanedDebt = hasOrphanedDebt
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        if completeness.hasNoPlanningInputs {
            TickCard {
                firstRunContent
            }
            .onChange(of: projection.month) {
                resetStartingBalanceForm()
            }
        } else {
            TickCard {
                availableContent
            }
        }
    }

    private var availableContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("AVAILABLE THIS MONTH")
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)

            Text(availableAmount)
                .heroAmountTypography()
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(accessibleAvailableAmount)

            zeroBalanceExplanation

            if hasOrphanedDebt {
                orphanedDebtWarning
            }

            Divider()
                .overlay(Palette.hairline)

            metricStrip
        }
    }

    @ViewBuilder
    private var metricStrip: some View {
        if usesVerticalMetrics {
            VStack(alignment: .leading, spacing: 14) {
                metric(incomeMetric)
                Divider().overlay(Palette.hairline)
                metric(expensesMetric)
                Divider().overlay(Palette.hairline)
                metric(savingsMetric)
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                metric(incomeMetric)
                Divider().overlay(Palette.hairline)
                metric(expensesMetric)
                Divider().overlay(Palette.hairline)
                metric(savingsMetric)
            }
        }
    }

    private var firstRunContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No plan for \(monthName) yet")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            Text("Enter your starting balance, then add your expected income to see where the month will land.")
                .font(Typography.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if hasOrphanedDebt {
                orphanedDebtWarning
            }

            HStack(spacing: 12) {
                TextField("Starting balance", text: $startingBalanceText)
                    .font(.title2.weight(.bold))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .focused($isStartingBalanceFocused)
                    .onSubmit(saveStartingBalance)
                    .accessibilityLabel("Starting balance amount")

                Text(appState.currencyCode)
                    .smallCapsTypography()
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(14)
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }

            if let startingBalanceError {
                Text(startingBalanceError)
                    .font(Typography.supporting)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Save starting balance", action: saveStartingBalance)
                .font(.headline)
                .foregroundStyle(Palette.surface)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .disabled(isSavingStartingBalance)

            Button("Go to Plan", action: onOpenPlan)
                .font(.headline)
                .foregroundStyle(Palette.accent)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        }
    }

    private var orphanedDebtWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(OrphanedDebtDetector.warningMessage)
                    .font(Typography.supporting)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Review in Plan", action: onOpenPlan)
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityHint("Opens Plan to review the debt")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Debt payment warning")
    }

    @ViewBuilder
    private var zeroBalanceExplanation: some View {
        let explanation = Self.zeroBalanceExplanation(
            projection: projection,
            completeness: completeness,
            hasRecordedActivity: !projectionStore.currentTransactions.isEmpty
        )

        if explanation.isVisible {
            VStack(alignment: .leading, spacing: 8) {
                if explanation.showsExpectedIncome {
                    Text(
                        "No income recorded as received yet — "
                            + "\(money(projection.remainingExpectedIncome)) "
                            + "still expected this month."
                    )
                    .font(Typography.supporting)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if explanation.showsStartingBalancePrompt {
                    Button("Set your starting balance in Plan.", action: onOpenPlan)
                        .font(Typography.supporting.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityHint("Opens Plan")
                }
            }
        }
    }

    private func metric(_ metric: AvailableMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.label)
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            Text(metric.displayValue)
                .valueTypography()
                .monospacedDigit()
                .foregroundStyle(metric.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(metric.accessibleValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, usesVerticalMetrics ? 0 : 12)
        .accessibilityElement(children: .combine)
    }

    private var incomeMetric: AvailableMetric {
        AvailableMetric(
            label: "INCOME",
            displayValue: compactMoney(projection.totalExpectedIncome, signed: true),
            accessibleValue: "Income, plus \(accessibleMoney(projection.totalExpectedIncome))",
            color: Palette.accent
        )
    }

    private var expensesMetric: AvailableMetric {
        AvailableMetric(
            label: "EXPENSES",
            displayValue: compactMoney(-projection.expensesPaid, signed: true),
            accessibleValue: "Expenses, minus \(accessibleMoney(projection.expensesPaid))",
            color: Palette.ink
        )
    }

    private var savingsMetric: AvailableMetric {
        AvailableMetric(
            label: "SAVINGS",
            displayValue: compactMoney(projection.savingsCompleted, signed: true),
            accessibleValue: "Savings, plus \(accessibleMoney(projection.savingsCompleted))",
            color: Palette.accent
        )
    }

    private var usesVerticalMetrics: Bool {
        dynamicTypeSize >= .xxLarge
    }

    private var monthName: String {
        projection.month
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }

    private var availableAmount: String {
        money(projection.currentAvailableBalance)
    }

    private var accessibleAvailableAmount: String {
        "Available this month, \(accessibleMoney(projection.currentAvailableBalance))"
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func compactMoney(_ amount: Decimal, signed: Bool = false) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: signed,
            style: .compact
        )
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func saveStartingBalance() {
        guard !isSavingStartingBalance else {
            return
        }
        guard let balance = PlanAmountParser.decimal(from: startingBalanceText) else {
            startingBalanceError = "Enter a valid amount."
            return
        }

        isSavingStartingBalance = true
        defer { isSavingStartingBalance = false }

        do {
            try repository.setStartingBalance(balance, for: appState.selectedMonth)
            startingBalanceText = PlanAmountParser.text(balance)
            startingBalanceError = nil
            isStartingBalanceFocused = false
            projectionStore.refresh()
        } catch {
            startingBalanceError = "The starting balance could not be saved. Please try again."
        }
    }

    private func resetStartingBalanceForm() {
        startingBalanceText = ""
        startingBalanceError = nil
        isStartingBalanceFocused = false
    }

    static func zeroBalanceExplanation(
        projection: MonthlyProjection,
        completeness: ProjectionCompleteness,
        hasRecordedActivity: Bool
    ) -> ZeroBalanceExplanation {
        guard projection.currentAvailableBalance == .zero, !hasRecordedActivity else {
            return ZeroBalanceExplanation(
                showsExpectedIncome: false,
                showsStartingBalancePrompt: false
            )
        }

        return ZeroBalanceExplanation(
            showsExpectedIncome: projection.remainingExpectedIncome > .zero
                && projection.incomeReceived == .zero,
            showsStartingBalancePrompt: !completeness.hasStartingBalance
        )
    }

    private struct AvailableMetric {
        let label: String
        let displayValue: String
        let accessibleValue: String
        let color: Color
    }

    struct ZeroBalanceExplanation: Equatable {
        let showsExpectedIncome: Bool
        let showsStartingBalancePrompt: Bool

        var isVisible: Bool {
            showsExpectedIncome || showsStartingBalancePrompt
        }
    }
}

extension ProjectionCompleteness {
    var hasNoPlanningInputs: Bool {
        !hasStartingBalance
            && !hasPlannedIncome
            && !hasBills
            && !hasSpendingBudget
            && !hasSavingsGoal
    }
}

#if DEBUG
#Preview("Available — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        AvailableThisMonthCard(projection: FlowPlanPreviewData.projection())
            .padding(30)
            .background(Palette.background)
    }
}

#Preview("Available — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        AvailableThisMonthCard(projection: FlowPlanPreviewData.projection())
            .padding(30)
            .background(Palette.background)
    }
}
#endif
