import SwiftUI
import FlowPlanDomain

struct DebtSection: View {
    @Environment(AppState.self) private var appState

    let debts: [Debt]
    let originalBalances: [UUID: Decimal]
    let outsideBillsTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (Debt) -> Void

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
    }

    private func debtStatus(_ debt: Debt) -> some View {
        Text(debt.isPaidThroughBills ? "In monthly bills" : "Counted separately")
            .font(.caption.weight(.bold))
            .fontWidth(.condensed)
            .foregroundStyle(debt.isPaidThroughBills ? Palette.inkSecondary : Palette.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                debt.isPaidThroughBills ? Palette.background : Palette.accentLight,
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
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("OUTSIDE MONTHLY BILLS")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            Spacer(minLength: 10)

            Text(money(outsideBillsTotal))
                .font(.headline.weight(.bold))
                .fontWidth(.condensed)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(16)
    }

    private func payoffText(for debt: Debt) -> Text {
        switch DebtSchedule().remainingPayments(for: debt) {
        case .value(let count):
            guard count > 0 else {
                return Text("Paid off")
            }

            let selectedOrCurrentMonth = min(
                appState.selectedMonth,
                MonthKey(date: Date(), calendar: .current)
            )
            switch DebtSchedule().payoffMonth(for: debt, startingIn: selectedOrCurrentMonth) {
            case .value(let month):
                return Text("\(count) payments left · paid off \(monthTitle(month))")
            case .neverAmortises:
                return Text("Payment does not cover interest")
            case .exceedsMaximumTerm:
                return Text("Payoff is more than 50 years away")
            }
        case .neverAmortises:
            return Text("Payment does not cover interest")
        case .exceedsMaximumTerm:
            return Text("Payoff is more than 50 years away")
        }
    }

    private func payoffColor(for debt: Debt) -> Color {
        switch DebtSchedule().remainingPayments(for: debt) {
        case .neverAmortises, .exceedsMaximumTerm:
            return .red
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
