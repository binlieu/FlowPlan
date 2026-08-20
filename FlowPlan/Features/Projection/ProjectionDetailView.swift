import SwiftUI
import FlowPlanDomain

struct ProjectionDetailView: View {
    @Environment(AppState.self) private var appState

    let projection: MonthlyProjection

    @State private var isPresentingWhatIf = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                hero
                breakdownSection
                supportingFiguresSection
                ProjectionCompletenessView(completeness: projection.completeness)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Projected End of \(monthName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("What If?") {
                    isPresentingWhatIf = true
                }
            }
        }
        .sheet(isPresented: $isPresentingWhatIf) {
            WhatIfView(projection: projection)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROJECTED MONTH END")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            AmountText(
                amount: projection.projectedEndOfMonthBalance,
                style: .hero,
                emphasiseNegative: true
            )

            Text(interpretation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(heroBackground, in: RoundedRectangle(cornerRadius: 24))
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Breakdown")
                .font(.title2.weight(.bold))

            VStack(alignment: .leading, spacing: 4) {
                ForEach(projection.breakdown) { lineItem in
                    ProjectionBreakdownRow(lineItem: lineItem)
                }
            }
            .padding(16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
    }

    private var supportingFiguresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supporting figures")
                .font(.title2.weight(.bold))

            VStack(spacing: 0) {
                supportingRow(
                    title: "Income received",
                    value: "\(money(projection.incomeReceived)) of \(money(projection.totalExpectedIncome)) expected"
                )
                Divider()
                supportingRow(
                    title: "Bills paid",
                    value: "\(money(projection.billsPaid)) of \(money(totalBills))"
                )
                Divider()
                supportingRow(
                    title: "Variable spending",
                    value: "\(money(projection.actualVariableSpending)) of \(money(projection.projectedVariableSpending)) projected"
                )
                Divider()
                supportingRow(
                    title: "Savings completed",
                    value: "\(money(projection.savingsCompleted)) of \(money(projection.savingsTarget)) target"
                )
                Divider()
                supportingRow(
                    title: "Days remaining",
                    value: "\(projection.daysRemaining) of \(projection.daysInMonth)"
                )
                Divider()
                supportingRow(
                    title: "Savings rate",
                    value: savingsRate
                )
                Divider()
                supportingRow(
                    title: "Variance vs plan",
                    value: "\(signedMoney(projection.varianceVsPlan)) vs \(money(projection.plannedEndOfMonthBalance)) planned"
                )
            }
            .padding(.horizontal, 16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
    }

    private func supportingRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var heroBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.16),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var monthName: String {
        projection.month
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }

    private var interpretation: String {
        switch projection.status {
        case .healthy:
            return "You're projected to finish \(monthName) with \(projectedBalanceString) remaining."
        case .tight:
            return "You're projected to finish \(monthName) with only \(projectedBalanceString) remaining."
        case .negative:
            return "You're projected to be \(shortfallString) short this month."
        case .aheadOfPlan:
            return "You're currently \(varianceMagnitudeString) ahead of your monthly plan."
        }
    }

    private var projectedBalanceString: String {
        money(projection.projectedEndOfMonthBalance)
    }

    private var shortfallString: String {
        money(magnitude(of: projection.projectedEndOfMonthBalance))
    }

    private var varianceMagnitudeString: String {
        money(magnitude(of: projection.varianceVsPlan))
    }

    private var totalBills: Decimal {
        projection.billsPaid + projection.remainingBills
    }

    private var savingsRate: String {
        projection.savingsRate.formatted(
            .percent.precision(.fractionLength(0...1))
        )
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func signedMoney(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: true
        )
    }

    private func magnitude(of amount: Decimal) -> Decimal {
        amount < .zero ? -amount : amount
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            ProjectionDetailView(projection: FlowPlanPreviewData.projection())
        }
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            ProjectionDetailView(projection: FlowPlanPreviewData.projection(status: .negative))
        }
    }
}
#endif
