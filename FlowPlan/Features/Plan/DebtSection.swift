import SwiftUI
import FlowPlanDomain

struct DebtSection: View {
    @Environment(AppState.self) private var appState

    let debts: [Debt]
    let bills: [PlannedBill]
    let originalBalances: [UUID: Decimal]
    let outsideBillsTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (Debt) -> Void
    let onCountSeparately: (Debt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader

            GroupedList(
                debts,
                emptyState: EmptyStateView(
                    symbol: "creditcard",
                    title: "No debts yet.",
                    layout: .compact
                ),
                footer: AnyView(totalRow),
                rowContent: debtRow
            )
        }
    }

    private var sectionHeader: some View {
        SectionHeading(title: "Debt", actionTitle: "Add", action: onAdd)
    }

    private func debtRow(_ debt: Debt) -> some View {
        VStack(alignment: .leading, spacing: Spacing.none) {
            Button {
                onEdit(debt)
            } label: {
                ListRow(
                    title: debt.name,
                    subtitle: aprText(for: debt),
                    trailingAmount: money(debt.currentBalance),
                    statuses: statuses(for: debt),
                    statusPlacement: .detail,
                    isDimmed: !debt.isActive
                ) {
                    ProgressView(value: progress(for: debt))
                        .tint(Palette.accent)
                        .accessibilityLabel("Debt payoff progress")
                        .accessibilityValue("\(paidPercentage(for: debt)) percent paid off")

                    HStack(alignment: .center, spacing: Spacing.sm) {
                        Text("\(paidPercentage(for: debt))% paid off")
                            .rowDetailTypography()
                            .foregroundStyle(Palette.inkSecondary)
                    }

                    payoffText(for: debt)
                        .rowDetailTypography()
                        .foregroundStyle(payoffColor(for: debt))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens debt editor")

            if OrphanedDebtDetector.isOrphaned(debt, bills: bills) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Palette.warning)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(OrphanedDebtDetector.warningMessage)
                            .rowDetailTypography()
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Count it separately") {
                            onCountSeparately(debt)
                        }
                        .rowDetailEmphasisTypography()
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityHint("Includes this debt payment in the projection")
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Debt payment warning")
            }
        }
    }

    private func statuses(for debt: Debt) -> [ListRowStatus] {
        var statuses: [ListRowStatus] = []

        if debt.isAutoPay {
            statuses.append(ListRowStatus(text: "AUTO PAY", style: .filledNeutral))
        }

        statuses.append(
            ListRowStatus(
                text: debt.isPaidThroughBills ? "In monthly bills" : "Counted separately",
                style: debt.isPaidThroughBills ? .filledNeutral : .outlinedAccent
            )
        )

        return statuses
    }

    private var totalRow: some View {
        PlanTotalRow(
            label: "OUTSIDE MONTHLY BILLS",
            amount: outsideBillsTotal,
            signed: false
        )
    }

    private func payoffText(for debt: Debt) -> Text {
        let selectedOrCurrentMonth = min(
            appState.selectedMonth,
            MonthKey(date: Date(), calendar: .current)
        )
        let startText = debt.firstPaymentMonth.flatMap { firstPaymentMonth in
            firstPaymentMonth > selectedOrCurrentMonth
                ? "Starts \(monthTitle(firstPaymentMonth)) · "
                : nil
        } ?? ""

        switch DebtSchedule().remainingPayments(for: debt) {
        case .value(let count):
            guard count > 0 else {
                return Text("Paid off")
            }

            let dueText = "Due \(DebtDueDayText.ordinal(debt.dueDay))"
            switch DebtSchedule().payoffMonth(for: debt, startingIn: selectedOrCurrentMonth) {
            case .value(let month):
                return Text(
                    "\(startText)\(dueText) · \(count) payments left · paid off \(monthTitle(month))"
                )
            case .neverAmortises:
                return Text("\(startText)\(dueText) · Payment does not cover interest")
            case .exceedsMaximumTerm:
                return Text("\(startText)\(dueText) · Payoff is more than 50 years away")
            }
        case .neverAmortises:
            return Text(
                "\(startText)Due \(DebtDueDayText.ordinal(debt.dueDay)) · Payment does not cover interest"
            )
        case .exceedsMaximumTerm:
            return Text(
                "\(startText)Due \(DebtDueDayText.ordinal(debt.dueDay)) · Payoff is more than 50 years away"
            )
        }
    }

    private func payoffColor(for debt: Debt) -> Color {
        switch DebtSchedule().remainingPayments(for: debt) {
        case .neverAmortises, .exceedsMaximumTerm:
            return Palette.negative
        case .value:
            return Palette.inkSecondary
        }
    }

    private func originalBalance(for debt: Debt) -> Decimal {
        max(debt.currentBalance, originalBalances[debt.id] ?? debt.currentBalance)
    }

    private func progress(for debt: Debt) -> Double {
        let originalBalance = originalBalance(for: debt)
        guard originalBalance > .zero else {
            return 1
        }

        let paid = max(.zero, originalBalance - debt.currentBalance)
        return min(1, max(0, NSDecimalNumber(decimal: paid / originalBalance).doubleValue))
    }

    private func paidPercentage(for debt: Debt) -> Int {
        Int((progress(for: debt) * 100).rounded())
    }

    private func aprText(for debt: Debt) -> String {
        let percentage = debt.annualInterestRate * 100
        return "\(percentage.formatted(.number.precision(.fractionLength(0...2))))% APR"
    }

    private func monthTitle(_ month: MonthKey) -> String {
        month.startDate(calendar: .current).formatted(.dateTime.month(.wide).year())
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
    }
}
