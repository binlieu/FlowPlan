import SwiftUI
import FlowPlanDomain

struct ProjectionDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    let projection: MonthlyProjection

    @State private var isPresentingWhatIf = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                hero
                breakdownSection
                supportingFiguresSection
                ProjectionCompletenessView(
                    completeness: ProjectionCompleteness(
                        hasStartingBalance: projectionStore.hasStartingBalance,
                        hasPlannedIncome: projection.completeness.hasPlannedIncome,
                        hasBills: projection.completeness.hasBills,
                        hasSpendingBudget: projection.completeness.hasSpendingBudget,
                        hasSavingsGoal: projection.completeness.hasSavingsGoal
                    )
                )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.background)
        .navigationTitle("Projected End of \(monthName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("What If?") {
                    isPresentingWhatIf = true
                }
            }
        }
        .sheet(isPresented: $isPresentingWhatIf) {
            WhatIfView(projection: projection)
        }
    }

    private var hero: some View {
        CardSurface(fill: AnyShapeStyle(heroBackground)) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("PROJECTED MONTH END")
                    .smallCapsTypography()
                    .foregroundStyle(Palette.inkSecondary)

                AmountText(
                    amount: projection.projectedEndOfMonthBalance,
                    style: .hero,
                    emphasiseNegative: true
                )

                Text(interpretation)
                    .bodyTypography()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeading(title: "Breakdown")

            GroupedList(projection.breakdown) { lineItem in
                ProjectionBreakdownRow(lineItem: lineItem)
                    .padding(.horizontal, Spacing.md)
            }
        }
    }

    private var supportingFiguresSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeading(title: "Supporting figures")

            GroupedList(supportingFigures) { figure in
                supportingRow(title: figure.title, value: figure.value)
                    .padding(.horizontal, Spacing.md)
            }
        }
    }

    private func supportingRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(title)
                .foregroundStyle(Palette.inkSecondary)

            Spacer(minLength: Spacing.sm)

            Text(value)
                .rowDetailEmphasisTypography()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var supportingFigures: [SupportingFigure] {
        [
            SupportingFigure(
                id: "incomeReceived",
                title: "Income received",
                value: "\(money(projection.incomeReceived)) of \(money(projection.totalExpectedIncome)) expected"
            ),
            SupportingFigure(
                id: "billsPaid",
                title: "Bills paid",
                value: "\(money(projection.billsPaid)) of \(money(totalBills))"
            ),
            SupportingFigure(
                id: "variableSpending",
                title: "Variable spending",
                value: "\(money(projection.actualVariableSpending)) of \(money(projection.projectedVariableSpending)) projected"
            ),
            SupportingFigure(
                id: "savingsCompleted",
                title: "Savings completed",
                value: "\(money(projection.savingsCompleted)) of \(money(projection.savingsTarget)) target"
            ),
            SupportingFigure(
                id: "daysRemaining",
                title: "Days remaining",
                value: "\(projection.daysRemaining) of \(projection.daysInMonth)"
            ),
            SupportingFigure(id: "savingsRate", title: "Savings rate", value: savingsRate),
            SupportingFigure(
                id: "variance",
                title: "Variance vs plan",
                value: "\(signedMoney(projection.varianceVsPlan)) vs \(money(projection.plannedEndOfMonthBalance)) planned"
            )
        ]
    }

    private struct SupportingFigure: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    private var heroBackground: LinearGradient {
        LinearGradient(
            colors: [
                Palette.accent.opacity(0.16),
                Palette.accent.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var monthName: String {
        projection.month
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }

    private var interpretation: String {
        switch projection.status {
        case .healthy:
            return "You're projected to finish \(monthName) with \(projectedBalanceString) remaining."
        case .tight:
            return "You're projected to finish \(monthName) with only \(projectedBalanceString) remaining."
        case .negative:
            return "You're projected to be \(shortfallString) short this month."
        case .aheadOfPlan:
            return "You're currently \(varianceMagnitudeString) ahead of your monthly plan."
        }
    }

    private var projectedBalanceString: String {
        money(projection.projectedEndOfMonthBalance)
    }

    private var shortfallString: String {
        money(magnitude(of: projection.projectedEndOfMonthBalance))
    }

    private var varianceMagnitudeString: String {
        money(magnitude(of: projection.varianceVsPlan))
    }

    private var totalBills: Decimal {
        projection.billsPaid + projection.remainingBills
    }

    private var savingsRate: String {
        projection.savingsRate.formatted(
            .percent.precision(.fractionLength(0...1))
        )
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func signedMoney(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: true
        )
    }

    private func magnitude(of amount: Decimal) -> Decimal {
        amount < .zero ? -amount : amount
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            ProjectionDetailView(projection: FlowPlanPreviewData.projection())
        }
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            ProjectionDetailView(projection: FlowPlanPreviewData.projection(status: .negative))
        }
    }
}
#endif
