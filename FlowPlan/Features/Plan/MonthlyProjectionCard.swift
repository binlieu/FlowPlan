import SwiftUI
import FlowPlanDomain

struct MonthlyProjectionCard: View {
    @Environment(AppState.self) private var appState

    let projection: MonthlyProjection

    var body: some View {
        TickCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("MONTHLY PROJECTION")
                    .smallCapsTypography()
                    .foregroundStyle(Palette.inkSecondary)

                VStack(spacing: 12) {
                    ForEach(Self.rows(for: projection)) { row in
                        projectionRow(row)
                    }
                }

                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("PROJECTED REMAINING")
                        .smallCapsTypography()
                        .foregroundStyle(Palette.accent)

                    Spacer(minLength: 12)

                    Text(signedMoney(Self.total(for: projection)))
                        .valueTypography()
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Monthly projection")
    }

    static func rows(for projection: MonthlyProjection) -> [ProjectionCardRow] {
        [
            ProjectionCardRow(
                id: "startingBalance",
                label: "Starting balance",
                amount: projection.startingBalance,
                direction: .addition
            ),
            ProjectionCardRow(
                id: "plannedIncome",
                label: "Expected income",
                amount: projection.plannedIncomeTotal,
                direction: .addition
            ),
            ProjectionCardRow(
                id: "plannedBills",
                label: "Recurring bills",
                amount: projection.plannedBillsTotal,
                direction: .deduction
            ),
            ProjectionCardRow(
                id: "plannedSpending",
                label: "Planned spending",
                amount: projection.plannedSpendingTotal,
                direction: .deduction
            ),
            ProjectionCardRow(
                id: "savingsTarget",
                label: "Savings goal",
                amount: projection.savingsTarget,
                direction: .deduction
            )
        ]
    }

    static func total(for projection: MonthlyProjection) -> Decimal {
        projection.plannedEndOfMonthBalance
    }

    private func projectionRow(_ row: ProjectionCardRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(row.label)
                .font(Typography.body)
                .foregroundStyle(Palette.inkSecondary)

            Spacer(minLength: 12)

            Text(formattedAmount(for: row))
                .font(.body.weight(.bold))
                .fontWidth(.condensed)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private func formattedAmount(for row: ProjectionCardRow) -> String {
        switch row.direction {
        case .addition:
            return "+\(money(row.amount))"
        case .deduction:
            return "-\(money(row.amount))"
        }
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
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

struct ProjectionCardRow: Identifiable, Equatable {
    enum Direction: Equatable {
        case addition
        case deduction
    }

    let id: String
    let label: String
    let amount: Decimal
    let direction: Direction

    var displayedAmount: Decimal {
        switch direction {
        case .addition:
            amount
        case .deduction:
            -amount
        }
    }
}

#if DEBUG
#Preview("Monthly Projection") {
    FlowPlanPreviewHost {
        MonthlyProjectionCard(projection: FlowPlanPreviewData.projection())
            .padding(30)
            .background(Palette.background)
    }
}
#endif
