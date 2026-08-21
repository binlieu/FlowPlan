import SwiftUI
import FlowPlanDomain

struct SpendingBudgetSection: View {
    @Environment(AppState.self) private var appState

    let budgets: [BudgetAllocation]
    let transactions: [TransactionSnapshot]
    let plannedTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (BudgetAllocation) -> Void

    struct TotalRowContent: Equatable {
        let label: String
        let amount: Decimal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader

            GroupedList(
                budgets,
                emptyState: EmptyStateView(
                    symbol: "chart.bar",
                    title: "No spending budgets yet.",
                    layout: .compact
                ),
                footer: AnyView(totalRow),
                rowContent: budgetRow
            )
        }
    }

    private var sectionHeader: some View {
        SectionHeading(title: "Spending Budget", actionTitle: "Add", action: onAdd)
    }

    private func budgetRow(_ budget: BudgetAllocation) -> some View {
        let spent = spentAmount(for: budget.category)
        let difference = budget.monthlyLimit - spent
        let isOverBudget = difference < .zero

        return Button {
            onEdit(budget)
        } label: {
            ListRow(
                title: budget.category,
                trailingAmount: "\(money(spent)) of \(money(budget.monthlyLimit))",
                amountStyle: .secondary,
                amountColor: Palette.inkSecondary
            ) {
                BudgetProgressBar(spent: spent, limit: budget.monthlyLimit)

                Text(footerText(difference: difference, isOverBudget: isOverBudget))
                    .rowDetailTypography()
                    .foregroundStyle(isOverBudget ? Palette.accent : Palette.inkSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens budget editor")
    }

    private var totalRow: some View {
        let content = Self.totalRowContent(plannedTotal: plannedTotal)

        return PlanTotalRow(
            label: content.label,
            amount: content.amount,
            signed: false,
            showsTopRule: false
        )
    }

    static func totalRowContent(plannedTotal: Decimal) -> TotalRowContent {
        TotalRowContent(
            label: "TOTAL SPENDING BUDGET",
            amount: plannedTotal
        )
    }

    private func spentAmount(for category: String) -> Decimal {
        var total: Decimal = .zero

        for transaction in transactions where
            transaction.type == .expense
                && transaction.settlesBillID == nil
                && transaction.settlesDebtID == nil
                && transaction.category == category {
            total += transaction.amount
        }

        return total
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
