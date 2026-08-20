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
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 0) {
                if bills.isEmpty {
                    Text("No recurring bills yet.")
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(bills.enumerated()), id: \.element.id) { index, bill in
                        billRow(bill)

                        if index < bills.count - 1 {
                            Divider()
                        }
                    }

                    Divider()
                }

                totalRow
            }
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Monthly Bills")
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

    private func billRow(_ bill: PlannedBill) -> some View {
        Button {
            onEdit(bill)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(bill.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)

                    HStack(spacing: 6) {
                        Chip(
                            text: bill.amountType.rawValue.uppercased(),
                            style: .outlinedAccent
                        )
                        Chip(
                            text: bill.isAutoPay ? "AUTO PAY" : "MANUAL",
                            style: .filledNeutral
                        )

                        if !bill.isActive {
                            Chip(text: "INACTIVE", style: .filledNeutral)
                        }
                    }
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(money(bill.amount))
                        .font(.headline.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)

                    Text(RecurrenceText.dueDescription(bill.recurrence))
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
            .opacity(bill.isActive ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens bill editor")
    }

    private var totalRow: some View {
        let content = Self.totalRowContent(plannedTotal: plannedTotal)

        return PlanTotalRow(
            label: content.label,
            amount: content.amount,
            signed: false
        )
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
