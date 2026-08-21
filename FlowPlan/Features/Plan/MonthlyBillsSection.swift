import SwiftUI
import FlowPlanDomain

struct MonthlyBillsSection: View {
    @Environment(AppState.self) private var appState

    let bills: [PlannedBill]
    let plannedTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (PlannedBill) -> Void

    struct TotalRowContent: Equatable {
        let label: String
        let amount: Decimal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader

            GroupedList(
                bills,
                emptyState: EmptyStateView(
                    symbol: "calendar",
                    title: "No recurring bills yet.",
                    layout: .compact
                ),
                footer: AnyView(totalRow),
                rowContent: billRow
            )
        }
    }

    private var sectionHeader: some View {
        SectionHeading(title: "Monthly Bills", actionTitle: "Add", action: onAdd)
    }

    private func billRow(_ bill: PlannedBill) -> some View {
        Button {
            onEdit(bill)
        } label: {
            ListRow(
                title: bill.name,
                trailingAmount: money(bill.amount),
                trailingSubtitle: RecurrenceText.dueDescription(bill.recurrence),
                statuses: statuses(for: bill),
                statusPlacement: .detail,
                isDimmed: !bill.isActive
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens bill editor")
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

    private func statuses(for bill: PlannedBill) -> [ListRowStatus] {
        var statuses = [
            ListRowStatus(
                text: bill.amountType.rawValue.uppercased(),
                style: .outlinedAccent
            ),
            ListRowStatus(
                text: bill.isAutoPay ? "AUTO PAY" : "MANUAL",
                style: .filledNeutral
            )
        ]

        if !bill.isActive {
            statuses.append(ListRowStatus(text: "INACTIVE", style: .filledNeutral))
        }

        return statuses
    }

    static func totalRowContent(plannedTotal: Decimal) -> TotalRowContent {
        TotalRowContent(
            label: "TOTAL MONTHLY BILLS",
            amount: plannedTotal
        )
    }

    static func formattedTotal(_ amount: Decimal, currencyCode: String) -> String {
        "-\(MoneyFormatter.string(amount, currencyCode: currencyCode, style: .compact))"
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
    }
}
