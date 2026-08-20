import SwiftUI
import FlowPlanDomain

struct AvailableThisMonthCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let projection: MonthlyProjection
    let onOpenPlan: () -> Void

    init(
        projection: MonthlyProjection,
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.projection = projection
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        TickCard {
            if projection.completeness.hasNoPlanningInputs {
                firstRunContent
            } else {
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

            Text("Add your expected income to see where the month will land.")
                .font(Typography.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Go to Plan", action: onOpenPlan)
                .font(.headline)
                .foregroundStyle(Palette.surface)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .padding(.top, 4)
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

    private struct AvailableMetric {
        let label: String
        let displayValue: String
        let accessibleValue: String
        let color: Color
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
