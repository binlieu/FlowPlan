import SwiftUI
import FlowPlanDomain

struct SpendingBudgetSection: View {
    @Environment(AppState.self) private var appState

    let budgets: [BudgetAllocation]
    let transactions: [TransactionSnapshot]
    let onAdd: () -> Void
    let onEdit: (BudgetAllocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 0) {
                if budgets.isEmpty {
                    Text("No spending budgets yet.")
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(budgets.enumerated()), id: \.element.id) { index, budget in
                        budgetRow(budget)

                        if index < budgets.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Spending Budget")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 8)

            Button("Add", action: onAdd)
                .font(.subheadline.weight(.bold))
                .fontWidth(.condensed)
                .foregroundStyle(Palette.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private func budgetRow(_ budget: BudgetAllocation) -> some View {
        let spent = spentAmount(for: budget.category)
        let difference = budget.monthlyLimit - spent
        let isOverBudget = difference < .zero

        return Button {
            onEdit(budget)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(budget.category)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)

                    Spacer(minLength: 8)

                    Text("\(money(spent)) of \(money(budget.monthlyLimit))")
                        .font(.subheadline.weight(.semibold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.trailing)
                }

                BudgetProgressBar(spent: spent, limit: budget.monthlyLimit)

                Text(footerText(difference: difference, isOverBudget: isOverBudget))
                    .font(Typography.supporting)
                    .foregroundStyle(isOverBudget ? Palette.accent : Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens budget editor")
    }

    private func spentAmount(for category: String) -> Decimal {
        transactions
            .filter {
                $0.type == .expense
                    && $0.settlesBillID == nil
                    && $0.category == category
            }
            .map(\.amount)
            .reduce(.zero, +)
    }

    private func footerText(difference: Decimal, isOverBudget: Bool) -> String {
        if isOverBudget {
            return "\(money(-difference)) over budget"
        }

        return "\(money(difference)) remaining"
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
    }
}
