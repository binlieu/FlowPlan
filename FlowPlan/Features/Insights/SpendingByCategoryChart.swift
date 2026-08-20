import Accessibility
import Charts
import SwiftUI
import FlowPlanDomain

struct SpendingByCategoryChart: View {
    let transactions: [TransactionSnapshot]
    let currencyCode: String

    var body: some View {
        Chart(categories) { category in
            BarMark(
                x: .value("Amount", category.amountValue),
                y: .value("Category", category.name)
            )
            .foregroundStyle(Palette.accent)
            .accessibilityLabel(category.name)
            .accessibilityValue(
                MoneyFormatter.accessibleString(category.amount, currencyCode: currencyCode)
            )
        }
        .chartXAxis {
            AxisMarks { value in
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
        .chartYScale(domain: Array(categories.map(\.name).reversed()))
        .accessibilityChartDescriptor(
            SpendingChartDescriptor(categories: categories, currencyCode: currencyCode)
        )
        .frame(height: chartHeight)
    }

    private var categories: [CategorySpending] {
        let totals = transactions
            .filter { $0.type == .expense && !$0.category.isEmpty }
            .reduce(into: [String: Decimal]()) { result, transaction in
                result[transaction.category, default: .zero] += transaction.amount
            }
            .map { CategorySpending(name: $0.key, amount: $0.value) }
            .sorted {
                if $0.amount == $1.amount {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.amount > $1.amount
            }

        let topCategories = Array(totals.prefix(6))
        let otherTotal = totals.dropFirst(6).map(\.amount).reduce(.zero, +)
        guard otherTotal > .zero else {
            return topCategories
        }
        return topCategories + [CategorySpending(name: "Other", amount: otherTotal)]
    }

    private var chartHeight: CGFloat {
        CGFloat(max(categories.count, 1)) * 40 + 32
    }
}

private struct CategorySpending: Identifiable {
    let name: String
    let amount: Decimal

    var id: String { name }
    var amountValue: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

private struct SpendingChartDescriptor: AXChartDescriptorRepresentable {
    let categories: [CategorySpending]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let maximum = max(categories.map(\.amountValue).max() ?? 0, 1)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Category",
            categoryOrder: categories.map(\.name)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Amount",
            range: 0...maximum,
            gridlinePositions: []
        ) { value in
            MoneyFormatter.accessibleString(Decimal(value), currencyCode: currencyCode)
        }
        let series = AXDataSeriesDescriptor(
            name: "Spending",
            isContinuous: false,
            dataPoints: categories.map { AXDataPoint(x: $0.name, y: $0.amountValue) }
        )

        return AXChartDescriptor(
            title: "Spending by category",
            summary: "Expense spending grouped by category for the selected month.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
