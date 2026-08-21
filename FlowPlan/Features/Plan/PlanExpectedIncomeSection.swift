import SwiftUI
import FlowPlanDomain

struct PlanExpectedIncomeSection: View {
    @Environment(AppState.self) private var appState

    let sources: [PlannedIncome]
    let plannedTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (PlannedIncome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader

            GroupedList(
                sources,
                emptyState: EmptyStateView(
                    symbol: "banknote",
                    title: "No expected income yet.",
                    layout: .compact
                ),
                footer: AnyView(totalRow),
                rowContent: incomeRow
            )
        }
    }

    private var sectionHeader: some View {
        SectionHeading(title: "Expected Income", actionTitle: "Add", action: onAdd)
    }

    private func incomeRow(_ source: PlannedIncome) -> some View {
        Button {
            onEdit(source)
        } label: {
            ListRow(
                title: source.name,
                subtitle: subtitle(for: source),
                trailingAmount: signedMoney(source.expectedAmount),
                isDimmed: !source.isActive
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens income editor")
    }

    private var totalRow: some View {
        PlanTotalRow(
            label: "TOTAL EXPECTED INCOME",
            amount: plannedTotal
        )
    }

    private func subtitle(for source: PlannedIncome) -> String {
        let recurrence = RecurrenceText.summary(source.recurrence)
        return source.isActive ? recurrence : "Inactive · \(recurrence)"
    }

    private func signedMoney(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: true,
            style: .compact
        )
    }
}
