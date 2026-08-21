import SwiftUI
import FlowPlanDomain

struct EstimatedSavingsCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let projection: MonthlyProjection

    @State private var isShowingProjection = false

    var body: some View {
        Button {
            isShowingProjection = true
        } label: {
            TickCard {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    summary

                    if !isShortfall {
                        Divider()
                            .overlay(Palette.hairline)

                        goalFooter
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(cardAccessibilityHint)
        .navigationDestination(isPresented: $isShowingProjection) {
            ProjectionDetailView(projection: projection)
        }
    }

    @ViewBuilder
    private var summary: some View {
        if isShortfall {
            summaryText
        } else if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                summaryText
                savingsRing
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            HStack(alignment: .center, spacing: Spacing.lg) {
                summaryText
                Spacer(minLength: Spacing.xs)
                savingsRing
            }
        }
    }

    private var summaryText: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(summaryLabel)
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)

            Text(summaryAmount)
                .largeAmountTypography()
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(accessibleProjectedAmount)

            Text(summaryCopy)
                .rowDetailTypography()
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var savingsRing: some View {
        SavingsGoalRing(
            progress: goalProgress,
            accessibilityValue: goalAccessibilityValue
        )
    }

    @ViewBuilder
    private var goalFooter: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                goalLabel
                goalValue
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                goalLabel
                Spacer(minLength: Spacing.xs)
                goalValue
            }
        }
    }

    private var goalLabel: some View {
        Text(isGoalMet ? "GOAL MET" : "GOAL")
            .smallCapsTypography()
            .foregroundStyle(Palette.inkSecondary)
    }

    private var goalValue: some View {
        Text(goalFigure)
            .rowAmountTypography()
            .monospacedDigit()
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(goalAccessibilityValue)
    }

    private var summaryAmount: String {
        let amount = isShortfall
            ? magnitude(of: projection.projectedEndOfMonthBalance)
            : projection.projectedEndOfMonthBalance
        return money(amount)
    }

    private var targetAmount: String {
        money(projection.savingsTarget)
    }

    private var accessibleProjectedAmount: String {
        if isShortfall {
            return "Projected shortfall, \(accessibleMoney(magnitude(of: projection.projectedEndOfMonthBalance)))"
        }

        return "Estimated savings, \(accessibleMoney(projection.projectedEndOfMonthBalance))"
    }

    private var goalAccessibilityValue: String {
        guard projection.savingsTarget > .zero else {
            return "No savings goal set"
        }

        let cappedProjection = min(projection.projectedEndOfMonthBalance, projection.savingsTarget)
        let status = isGoalMet ? ", goal met" : ""
        return "\(accessibleMoney(cappedProjection)) of \(accessibleMoney(projection.savingsTarget)) goal\(status)"
    }

    private var cardAccessibilityLabel: String {
        if isShortfall {
            return "Projected shortfall, \(accessibleMoney(magnitude(of: projection.projectedEndOfMonthBalance))). "
                + "You're projected to be \(accessibleMoney(magnitude(of: projection.projectedEndOfMonthBalance))) short this month."
        }

        return "Estimated savings, \(accessibleMoney(projection.projectedEndOfMonthBalance)). \(goalAccessibilityValue)."
    }

    private var cardAccessibilityHint: String {
        isShortfall
            ? "Shows how the projected shortfall was calculated"
            : "Shows how estimated savings was calculated"
    }

    private var summaryLabel: String {
        isShortfall ? "PROJECTED SHORTFALL" : "ESTIMATED SAVINGS"
    }

    private var summaryCopy: String {
        if isShortfall {
            return "You're projected to be \(money(magnitude(of: projection.projectedEndOfMonthBalance))) short this month."
        }

        return "Based on your current income, recurring bills, and planned spending."
    }

    private var goalFigure: String {
        guard projection.savingsTarget > .zero else {
            return "No goal set"
        }

        let cappedProjection = min(projection.projectedEndOfMonthBalance, projection.savingsTarget)
        return "\(money(cappedProjection)) of \(targetAmount)"
    }

    private var isShortfall: Bool {
        projection.projectedEndOfMonthBalance < .zero
    }

    private var isGoalMet: Bool {
        projection.savingsTarget > .zero
            && projection.projectedEndOfMonthBalance >= projection.savingsTarget
    }

    private var goalProgress: CGFloat {
        guard projection.savingsTarget > .zero else {
            return 0
        }

        let projected = NSDecimalNumber(decimal: projection.projectedEndOfMonthBalance).doubleValue
        let target = NSDecimalNumber(decimal: projection.savingsTarget).doubleValue
        return min(max(CGFloat(projected / target), 0), 1)
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func magnitude(of amount: Decimal) -> Decimal {
        amount < .zero ? -amount : amount
    }
}

private struct SavingsGoalRing: View {
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 78
    @ScaledMetric(relativeTo: .body) private var lineWidth: CGFloat = 9

    let progress: CGFloat
    let accessibilityValue: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.hairline, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Palette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Savings goal progress ring")
        .accessibilityValue(accessibilityValue)
    }
}

#if DEBUG
#Preview("Estimated Savings — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            EstimatedSavingsCard(projection: FlowPlanPreviewData.projection())
                .padding(Spacing.xl)
                .background(Palette.background)
        }
    }
}

#Preview("Estimated Savings — Accessibility") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            EstimatedSavingsCard(projection: FlowPlanPreviewData.projection())
                .padding(Spacing.xl)
                .background(Palette.background)
        }
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
