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
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 0) {
                if debts.isEmpty {
                    Text("No debts yet.")
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(debts.enumerated()), id: \.element.id) { index, debt in
                        debtRow(debt)

                        if index < debts.count - 1 {
                            Divider()
                        }
                    }
                }

                Divider()
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
            Text("Debt")
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

    private func debtRow(_ debt: Debt) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onEdit(debt)
            } label: {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(debt.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Palette.ink)

                            Text(aprText(for: debt))
                                .font(Typography.supporting)
                                .foregroundStyle(Palette.inkSecondary)
                        }

                        Spacer(minLength: 10)

                        Text(money(debt.currentBalance))
                            .font(.headline.weight(.bold))
                            .fontWidth(.condensed)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }

                    ProgressView(value: progress(for: debt))
                        .tint(Palette.accent)
                        .accessibilityLabel("Debt payoff progress")
                        .accessibilityValue("\(paidPercentage(for: debt)) percent paid off")

                    HStack(alignment: .center, spacing: 10) {
                        Text("\(paidPercentage(for: debt))% paid off")
                            .font(Typography.supporting)
                            .foregroundStyle(Palette.inkSecondary)

                        Spacer(minLength: 8)

                        if debt.isAutoPay {
                            Chip(text: "AUTO PAY", style: .filledNeutral)
                        }

                        debtStatus(debt)
                    }

                    payoffText(for: debt)
                        .font(Typography.supporting)
                        .foregroundStyle(payoffColor(for: debt))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .contentShape(Rectangle())
                .opacity(debt.isActive ? 1 : 0.55)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens debt editor")

            if OrphanedDebtDetector.isOrphaned(debt, bills: bills) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Palette.warning)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(OrphanedDebtDetector.warningMessage)
                            .font(Typography.supporting)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Count it separately") {
                            onCountSeparately(debt)
                        }
                        .font(Typography.supporting.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityHint("Includes this debt payment in the projection")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Debt payment warning")
            }
        }
    }

    private func debtStatus(_ debt: Debt) -> some View {
        Text(debt.isPaidThroughBills ? "In monthly bills" : "Counted separately")
            .font(.caption.weight(.bold))
            .fontWidth(.condensed)
            .foregroundStyle(debt.isPaidThroughBills ? Palette.inkSecondary : Palette.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                debt.isPaidThroughBills ? Palette.background : PlanTotalRow.accentFill,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    debt.isPaidThroughBills ? Palette.hairline : Palette.accentMuted,
                    lineWidth: 1
                )
            }
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
