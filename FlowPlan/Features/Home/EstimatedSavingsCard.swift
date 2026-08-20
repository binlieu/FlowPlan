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
                VStack(alignment: .leading, spacing: 18) {
                    summary

                    Divider()
                        .overlay(Palette.hairline)

                    goalFooter
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Shows how estimated savings was calculated")
        .navigationDestination(isPresented: $isShowingProjection) {
            ProjectionDetailView(projection: projection)
        }
    }

    @ViewBuilder
    private var summary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 18) {
                summaryText
                savingsRing
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            HStack(alignment: .center, spacing: 18) {
                summaryText
                Spacer(minLength: 8)
                savingsRing
            }
        }
    }

    private var summaryText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ESTIMATED SAVINGS")
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)

            Text(projectedAmount)
                .largeAmountTypography()
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(accessibleProjectedAmount)

            Text("Based on your current income, recurring bills, and planned spending.")
                .font(Typography.supporting)
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
            VStack(alignment: .leading, spacing: 8) {
                goalLabel
                goalValue
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                goalLabel
                Spacer(minLength: 8)
                goalValue
            }
        }
    }

    private var goalLabel: some View {
        Text("GOAL")
            .smallCapsTypography()
            .foregroundStyle(Palette.inkSecondary)
    }

    private var goalValue: some View {
        Text("\(projectedAmount) / \(targetAmount)")
            .font(.headline.weight(.bold))
            .fontWidth(.condensed)
            .monospacedDigit()
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(goalAccessibilityValue)
    }

    private var projectedAmount: String {
        money(projection.projectedEndOfMonthBalance)
    }

    private var targetAmount: String {
        money(projection.savingsTarget)
    }

    private var accessibleProjectedAmount: String {
        "Estimated savings, \(accessibleMoney(projection.projectedEndOfMonthBalance))"
    }

    private var goalAccessibilityValue: String {
        guard projection.savingsTarget > .zero else {
            return "No savings goal set"
        }

        return "\(accessibleMoney(projection.projectedEndOfMonthBalance)) of \(accessibleMoney(projection.savingsTarget)) goal"
    }

    private var cardAccessibilityLabel: String {
        "Estimated savings, \(accessibleMoney(projection.projectedEndOfMonthBalance)). \(goalAccessibilityValue)."
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
                .padding(30)
                .background(Palette.background)
        }
    }
}

#Preview("Estimated Savings — Accessibility") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            EstimatedSavingsCard(projection: FlowPlanPreviewData.projection())
                .padding(30)
                .background(Palette.background)
        }
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
