import SwiftUI
import FlowPlanDomain

struct SmartInsightsSection: View {
    @Environment(AppState.self) private var appState

    let insights: [Insight]

    var body: some View {
        TickCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeading(title: "Smart insights")

                if insights.isEmpty {
                    EmptyStateView(
                        symbol: "lightbulb",
                        title: "There is not enough month-over-month data for an insight yet.",
                        layout: .compact
                    )
                } else {
                    VStack(spacing: Spacing.none) {
                        ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: symbolName(for: insight))
                                    .prominentLabelTypography()
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)

                                Text(message(for: insight))
                                    .rowDetailTypography()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, Spacing.sm)

                            if index < insights.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func message(for insight: Insight) -> String {
        switch insight.kind {
        case .spending(let category, let percentageChange):
            let direction = percentageChange > .zero ? "higher" : "lower"
            return "Your \(displayCategory(category)) spending is "
                + "\(wholePercentage(magnitude(of: percentageChange)))% \(direction) than last month."
        case .savings(let monthlyTarget):
            return "You're on track to save \(money(monthlyTarget)) this month."
        case .subscriptions(let monthlyTotal):
            return "Your subscriptions total \(money(monthlyTotal))/month."
        case .projection(let month, let varianceFromPlan):
            let direction = varianceFromPlan > .zero ? "ahead of" : "behind"
            return "You're projected to finish \(monthName(month)) "
                + "\(money(magnitude(of: varianceFromPlan))) \(direction) plan."
        case .income(let received, let expected, let remaining):
            return "You've received \(money(received)) of \(money(expected)) expected income; "
                + "\(money(remaining)) remains."
        }
    }

    private func symbolName(for insight: Insight) -> String {
        switch insight.kind {
        case .spending(_, let percentageChange):
            return percentageChange > .zero ? "arrow.up.right" : "arrow.down.right"
        case .savings:
            return "target"
        case .subscriptions:
            return "repeat.circle"
        case .projection:
            return "chart.line.uptrend.xyaxis"
        case .income:
            return "banknote"
        }
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func wholePercentage(_ percentage: Decimal) -> String {
        percentage.formatted(.number.precision(.fractionLength(0)))
    }

    private func monthName(_ month: Int) -> String {
        guard (1...12).contains(month) else {
            return "the month"
        }

        return MonthKey(year: 2000, month: month)
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }

    private func displayCategory(_ category: String) -> String {
        let lowercased = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased == "groceries" ? "grocery" : lowercased
    }

    private func magnitude(of value: Decimal) -> Decimal {
        value < .zero ? -value : value
    }
}
