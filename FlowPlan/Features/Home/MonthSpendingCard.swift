import SwiftUI
import FlowPlanDomain

struct MonthSpendingCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let projection: MonthlyProjection

    var body: some View {
        TickCard {
            VStack(alignment: .leading, spacing: 20) {
                cardHeader
                spendingMetrics
                spendingProgressBar
                safeToSpendRow
            }
        }
    }

    @ViewBuilder
    private var cardHeader: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: 8) {
                heading
                daysRemainingLabel
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                heading
                Spacer(minLength: 8)
                daysRemainingLabel
            }
        }
    }

    private var heading: some View {
        Text("\(monthName) Spending")
            .sectionHeadingTypography()
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var daysRemainingLabel: some View {
        Text("\(projection.daysRemaining) DAYS REMAINING")
            .smallCapsTypography()
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var spendingMetrics: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: 14) {
                spendingMetric(label: "SPENT", amount: projection.actualVariableSpending)
                Divider().overlay(Palette.hairline)
                spendingMetric(label: "BUDGET", amount: projection.projectedVariableSpending)
                Divider().overlay(Palette.hairline)
                spendingMetric(
                    label: "REMAINING",
                    amount: projection.remainingVariableSpending,
                    color: Palette.accent
                )
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                spendingMetric(label: "SPENT", amount: projection.actualVariableSpending)
                spendingMetric(label: "BUDGET", amount: projection.projectedVariableSpending)
                spendingMetric(
                    label: "REMAINING",
                    amount: projection.remainingVariableSpending,
                    color: Palette.accent
                )
            }
        }
    }

    private func spendingMetric(
        label: String,
        amount: Decimal,
        color: Color = Palette.ink
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            Text(compactMoney(amount))
                .valueTypography()
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(accessibleMoney(amount))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var spendingProgressBar: some View {
        ProportionalSegmentsLayout(weights: spendingWeights) {
            Rectangle()
                .fill(Palette.accentMuted)
            Rectangle()
                .fill(Palette.surface)
        }
        .frame(height: 8)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monthly spending progress")
        .accessibilityValue(spendingProgressAccessibilityValue)
    }

    @ViewBuilder
    private var safeToSpendRow: some View {
        if projection.daysRemaining == 0 {
            Label("The month is complete", systemImage: "dollarsign")
                .font(Typography.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "dollarsign")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.accent)

                Text("Safe to spend:")
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSecondary)

                Text("\(dailySafeToSpendAmount)/day")
                    .font(.body.weight(.bold))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(accessibleMoney(projection.dailySafeToSpend)) per day")
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var monthName: String {
        projection.month
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }

    private var spendingWeights: [CGFloat] {
        [
            chartWeight(projection.actualVariableSpending),
            chartWeight(projection.remainingVariableSpending)
        ]
    }

    private var spendingProgressAccessibilityValue: String {
        "\(accessibleMoney(projection.actualVariableSpending)) spent of \(accessibleMoney(projection.projectedVariableSpending)); \(accessibleMoney(projection.remainingVariableSpending)) remaining."
    }

    private var dailySafeToSpendAmount: String {
        money(projection.dailySafeToSpend)
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func compactMoney(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func chartWeight(_ amount: Decimal) -> CGFloat {
        max(0, CGFloat(NSDecimalNumber(decimal: amount).doubleValue))
    }
}

#if DEBUG
#Preview("Month Spending — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        MonthSpendingCard(projection: FlowPlanPreviewData.projection())
            .padding(30)
            .background(Palette.background)
    }
}

#Preview("Month Spending — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        MonthSpendingCard(projection: FlowPlanPreviewData.projection())
            .padding(30)
            .background(Palette.background)
    }
}
#endif
