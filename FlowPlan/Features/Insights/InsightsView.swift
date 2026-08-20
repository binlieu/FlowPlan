import SwiftUI
import FlowPlanDomain

struct InsightsView: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    private let projectionEngine = MonthlyProjectionEngine()
    private let insightsEngine = InsightsEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MonthNavigationBar()

                if currentTransactions.isEmpty {
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
                            currentTransactions: currentTransactions,
                            previousTransactions: previousTransactions,
                            currencyCode: appState.currencyCode
                        )
                    }

                    SectionCard(title: "Spending by category") {
                        SpendingByCategoryChart(
                            transactions: currentTransactions,
                            currencyCode: appState.currencyCode
                        )
                    }

                    savingsRateRow

                    SmartInsightsSection(insights: insights)
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

    private var currentTransactions: [TransactionSnapshot] {
        repository.transactions(in: appState.selectedMonth)
    }

    private var previousTransactions: [TransactionSnapshot] {
        repository.transactions(in: appState.selectedMonth.previous)
    }

    private var previousProjection: MonthlyProjection {
        let month = appState.selectedMonth.previous
        let input = repository.projectionInput(
            for: month,
            referenceDate: month.endDate(calendar: .current),
            configuration: .default
        )
        return projectionEngine.project(input)
    }

    private var insights: [Insight] {
        insightsEngine.insights(
            for: projectionStore.projection,
            previous: previousProjection,
            transactions: currentTransactions,
            previousTransactions: previousTransactions,
            bills: repository.bills()
        )
    }
}
