import SwiftUI
import FlowPlanDomain

struct ProjectionBreakdownRow: View {
    let lineItem: ProjectionLineItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if lineItem.kind == .total {
                Divider()
                    .padding(.bottom, Spacing.xxs)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(title)
                    .breakdownTitleTypography(isTotal: lineItem.kind == .total)

                Spacer(minLength: Spacing.sm)

                AmountText(
                    amount: lineItem.amount,
                    style: lineItem.kind == .total ? .primary : .secondary,
                    signed: showsSign,
                    emphasiseNegative: lineItem.kind == .total
                )
            }

            if let explainer {
                Text(explainer)
                    .footnoteTypography()
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var showsSign: Bool {
        lineItem.kind == .addition || lineItem.kind == .deduction
    }

    private var title: String {
        switch lineItem.id {
        case "currentAvailable":
            return "Current Available"
        case "remainingIncome":
            return "Remaining Income"
        case "remainingBills":
            return "Upcoming Bills"
        case "remainingDebt":
            return "Debt Payments"
        case "remainingSpending":
            return "Expected Spending"
        case "remainingSavings":
            return "Savings Goal Remaining"
        case "projectedBalance":
            return "Projected Balance"
        default:
            return lineItem.label
        }
    }

    private var explainer: String? {
        switch lineItem.id {
        case "currentAvailable":
            return "Starting balance plus what's come in, minus what's gone out."
        case "remainingIncome":
            return "Expected income you haven't received yet."
        case "remainingBills":
            return "Bills due this month that aren't paid yet."
        case "remainingDebt":
            return "Debt payments due this month that aren't paid yet."
        case "remainingSpending":
            return "What's left of your category budgets."
        case "remainingSavings":
            return "Still to set aside to hit your monthly goal."
        default:
            return nil
        }
    }
}
