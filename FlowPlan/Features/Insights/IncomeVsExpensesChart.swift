import Accessibility
import Charts
import SwiftUI
import FlowPlanDomain

struct IncomeVsExpensesChart: View {
    let currentMonth: MonthKey
    let currentTransactions: [TransactionSnapshot]
    let previousTransactions: [TransactionSnapshot]
    let currencyCode: String

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Month", point.month),
                y: .value("Amount", point.amountValue)
            )
            .position(by: .value("Type", point.kind.rawValue))
            .foregroundStyle(by: .value("Type", point.kind.rawValue))
            .accessibilityLabel("\(point.kind.rawValue), \(point.month)")
            .accessibilityValue(
                MoneyFormatter.accessibleString(point.amount, currencyCode: currencyCode)
            )
        }
        .chartForegroundStyleScale([
            CashFlowKind.income.rawValue: Palette.accent,
            CashFlowKind.expenses.rawValue: Palette.inkSecondary
        ])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(
                            Decimal(amount).formatted(
                                .currency(code: currencyCode)
                                .notation(.compactName)
                                .precision(.fractionLength(0))
                            )
                        )
                    }
                }
            }
        }
        .accessibilityChartDescriptor(
            CashFlowChartDescriptor(points: points, currencyCode: currencyCode)
        )
        .frame(height: 220)
    }

    private var points: [CashFlowPoint] {
        let previousMonth = currentMonth.previous
        return [
            CashFlowPoint(
                month: monthLabel(previousMonth),
                kind: .income,
                amount: total(for: .income, in: previousTransactions)
            ),
            CashFlowPoint(
                month: monthLabel(previousMonth),
                kind: .expenses,
                amount: total(for: .expense, in: previousTransactions)
            ),
            CashFlowPoint(
                month: monthLabel(currentMonth),
                kind: .income,
                amount: total(for: .income, in: currentTransactions)
            ),
            CashFlowPoint(
                month: monthLabel(currentMonth),
                kind: .expenses,
                amount: total(for: .expense, in: currentTransactions)
            )
        ]
    }

    private func total(
        for type: TransactionType,
        in transactions: [TransactionSnapshot]
    ) -> Decimal {
        transactions
            .filter { $0.type == type }
            .map(\.amount)
            .reduce(.zero, +)
    }

    private func monthLabel(_ month: MonthKey) -> String {
        month.startDate(calendar: .current).formatted(.dateTime.month(.abbreviated))
    }
}

private enum CashFlowKind: String {
    case income = "Income"
    case expenses = "Expenses"
}

private struct CashFlowPoint: Identifiable {
    let month: String
    let kind: CashFlowKind
    let amount: Decimal

    var id: String { "\(month)-\(kind.rawValue)" }
    var amountValue: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

private struct CashFlowChartDescriptor: AXChartDescriptorRepresentable {
    let points: [CashFlowPoint]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        var months: [String] = []
        for point in points where !months.contains(point.month) {
            months.append(point.month)
        }
        let maximum = max(points.map(\.amountValue).max() ?? 0, 1)
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Month", categoryOrder: months)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Amount",
            range: 0...maximum,
            gridlinePositions: []
        ) { value in
            MoneyFormatter.accessibleString(Decimal(value), currencyCode: currencyCode)
        }
        let series = CashFlowKind.allCases.map { kind in
            AXDataSeriesDescriptor(
                name: kind.rawValue,
                isContinuous: false,
                dataPoints: points
                    .filter { $0.kind == kind }
                    .map { AXDataPoint(x: $0.month, y: $0.amountValue) }
            )
        }

        return AXChartDescriptor(
            title: "Income versus expenses",
            summary: "Compares income and expenses for the selected month and previous month.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

extension CashFlowKind: CaseIterable {}
