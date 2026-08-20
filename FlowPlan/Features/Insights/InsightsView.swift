import SwiftUI
import FlowPlanDomain

struct InsightsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MonthNavigationBar()

                if projectionStore.currentTransactions.isEmpty {
                    EmptyStateView(
                        symbol: "chart.bar.xaxis",
                        title: "No activity this month",
                        message: "Add an income or expense transaction to see monthly insights."
                    )
                    .frame(minHeight: 360)
                } else {
                    SectionCard(title: "Income vs expenses") {
                        IncomeVsExpensesChart(
                            currentMonth: appState.selectedMonth,
                            currentTransactions: projectionStore.currentTransactions,
                            previousTransactions: projectionStore.previousTransactions,
                            currencyCode: appState.currencyCode
                        )
                    }

                    SectionCard(title: "Spending by category") {
                        SpendingByCategoryChart(
                            transactions: projectionStore.currentTransactions,
                            currencyCode: appState.currencyCode
                        )
                    }

                    savingsRateRow

                    SmartInsightsSection(insights: projectionStore.insights)
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            projectionStore.refresh()
        }
        .onChange(of: appState.selectedMonth) {
            projectionStore.refresh()
        }
    }

    private var savingsRateRow: some View {
        HStack {
            Label("Savings rate", systemImage: "percent")
                .font(.headline)

            Spacer()

            Text(
                projectionStore.projection.savingsRate.formatted(
                    .percent.precision(.fractionLength(0))
                )
            )
            .font(.title3.bold())
            .monospacedDigit()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

}
