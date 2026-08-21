import SwiftUI
import FlowPlanDomain

struct InsightsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    var body: some View {
        let _ = projectionStore.dataVersion

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ScreenHeader(title: "Insights")

                Group {
                    MonthNavigationBar()

                    if projectionStore.currentTransactions.isEmpty {
                        EmptyStateView(
                            symbol: "chart.bar.xaxis",
                            title: "No activity this month",
                            message: "Add an income or expense transaction to see monthly insights."
                        )
                        .frame(minHeight: 360)
                    } else {
                        TickCard {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                SectionHeading(title: "Income vs expenses")

                                IncomeVsExpensesChart(
                                    currentMonth: appState.selectedMonth,
                                    currentTransactions: projectionStore.currentTransactions,
                                    previousTransactions: projectionStore.previousTransactions,
                                    currencyCode: appState.currencyCode
                                )
                            }
                        }

                        TickCard {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                SectionHeading(title: "Spending by category")

                                SpendingByCategoryChart(
                                    transactions: projectionStore.currentTransactions,
                                    currencyCode: appState.currencyCode
                                )
                            }
                        }

                        savingsRateRow

                        SmartInsightsSection(insights: projectionStore.insights)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            projectionStore.refresh()
        }
        .onChange(of: appState.selectedMonth) {
            projectionStore.refresh()
        }
    }

    private var savingsRateRow: some View {
        CardSurface(contentPadding: Spacing.md) {
            HStack {
                Label("Savings rate", systemImage: "percent")
                    .prominentLabelTypography()

                Spacer()

                Text(
                    projectionStore.projection.savingsRate.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                .iconTypography()
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

}
