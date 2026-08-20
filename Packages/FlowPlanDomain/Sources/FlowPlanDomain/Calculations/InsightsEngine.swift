import Foundation

public struct InsightsEngine: Sendable {
    public init() {}

    public func insights(
        for projection: MonthlyProjection,
        previous: MonthlyProjection?,
        transactions: [TransactionSnapshot],
        previousTransactions: [TransactionSnapshot],
        bills: [PlannedBill]
    ) -> [Insight] {
        var results: [Insight] = []

        if let projectionInsight = projectionInsight(for: projection) {
            results.append(projectionInsight)
        }

        if let incomeInsight = incomeInsight(for: projection) {
            results.append(incomeInsight)
        }

        if let savingsInsight = savingsInsight(for: projection) {
            results.append(savingsInsight)
        }

        if previous != nil {
            results.append(
                contentsOf: spendingInsights(
                    transactions: transactions,
                    previousTransactions: previousTransactions
                )
            )
        }

        if let subscriptionsInsight = subscriptionsInsight(for: bills) {
            results.append(subscriptionsInsight)
        }

        return Array(results.prefix(6))
    }

    private func projectionInsight(for projection: MonthlyProjection) -> Insight? {
        let hasPlan = projection.plannedIncomeTotal > .zero
            || projection.plannedBillsTotal > .zero
            || projection.plannedSpendingTotal > .zero
            || projection.savingsTarget > .zero
        guard hasPlan, projection.varianceVsPlan != .zero else {
            return nil
        }

        let direction = projection.varianceVsPlan > .zero ? "ahead of" : "behind"
        let amount = formatCurrency(absoluteValue(projection.varianceVsPlan))
        let month = monthName(projection.month.month)

        return Insight(
            id: "projection-vs-plan",
            kind: .projection,
            message: "You're projected to finish \(month) \(amount) \(direction) plan.",
            symbolName: "chart.line.uptrend.xyaxis"
        )
    }

    private func incomeInsight(for projection: MonthlyProjection) -> Insight? {
        guard
            projection.totalExpectedIncome > .zero,
            projection.remainingExpectedIncome > .zero
        else {
            return nil
        }

        return Insight(
            id: "income-remaining",
            kind: .income,
            message: "You've received \(formatCurrency(projection.incomeReceived)) of "
                + "\(formatCurrency(projection.totalExpectedIncome)) expected income; "
                + "\(formatCurrency(projection.remainingExpectedIncome)) remains.",
            symbolName: "banknote"
        )
    }

    private func savingsInsight(for projection: MonthlyProjection) -> Insight? {
        guard projection.savingsTarget > .zero else {
            return nil
        }

        return Insight(
            id: "savings-pace",
            kind: .savings,
            message: "You're on track to save \(formatCurrency(projection.savingsTarget)) this month.",
            symbolName: "target"
        )
    }

    private func spendingInsights(
        transactions: [TransactionSnapshot],
        previousTransactions: [TransactionSnapshot]
    ) -> [Insight] {
        let currentByCategory = spendingByCategory(transactions)
        let previousByCategory = spendingByCategory(previousTransactions)

        let changes = currentByCategory.compactMap { category, currentAmount -> SpendingChange? in
            guard
                currentAmount > .zero,
                let previousAmount = previousByCategory[category],
                previousAmount > .zero
            else {
                return nil
            }

            let delta = ((currentAmount - previousAmount) / previousAmount) * 100
            guard absoluteValue(delta) > 10 else {
                return nil
            }

            return SpendingChange(category: category, percentage: roundedWholeNumber(delta))
        }

        return changes
            .sorted { lhs, rhs in
                let lhsMagnitude = absoluteValue(lhs.percentage)
                let rhsMagnitude = absoluteValue(rhs.percentage)
                if lhsMagnitude == rhsMagnitude {
                    let locale = Locale(identifier: "en_US_POSIX")
                    return lhs.category.lowercased(with: locale) < rhs.category.lowercased(with: locale)
                }
                return lhsMagnitude > rhsMagnitude
            }
            .map { change in
                let direction = change.percentage > .zero ? "higher" : "lower"
                let percentage = NSDecimalNumber(decimal: absoluteValue(change.percentage)).intValue
                let category = insightCategoryName(change.category)

                return Insight(
                    id: "spending-\(stableIDComponent(change.category))",
                    kind: .spending,
                    message: "Your \(category) spending is \(percentage)% \(direction) than last month.",
                    symbolName: direction == "higher" ? "arrow.up.right" : "arrow.down.right"
                )
            }
    }

    private func subscriptionsInsight(for bills: [PlannedBill]) -> Insight? {
        let subscriptions = bills.filter {
            $0.isActive
                && $0.amount > .zero
                && $0.amount < 50
                && $0.recurrence.frequency == .monthly
        }
        guard !subscriptions.isEmpty else {
            return nil
        }

        let total = subscriptions.map(\.amount).reduce(.zero, +)
        return Insight(
            id: "subscriptions-total",
            kind: .subscriptions,
            message: "Your subscriptions total \(formatCurrency(total))/month.",
            symbolName: "repeat.circle"
        )
    }

    private func spendingByCategory(
        _ transactions: [TransactionSnapshot]
    ) -> [String: Decimal] {
        transactions
            .filter { $0.type == .expense && !$0.category.isEmpty }
            .reduce(into: [String: Decimal]()) { totals, transaction in
                totals[transaction.category, default: .zero] += transaction.amount
            }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        amount.formatted(
            Decimal.FormatStyle.Currency(code: "USD")
                .precision(.fractionLength(0...2))
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func monthName(_ month: Int) -> String {
        let names = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]
        guard names.indices.contains(month - 1) else {
            return "the month"
        }
        return names[month - 1]
    }

    private func insightCategoryName(_ category: String) -> String {
        let lowercased = category.lowercased(with: Locale(identifier: "en_US_POSIX"))
        return lowercased == "groceries" ? "grocery" : lowercased
    }

    private func stableIDComponent(_ value: String) -> String {
        value
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: " ", with: "-")
    }

    private func roundedWholeNumber(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal.zero
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }

    private func absoluteValue(_ value: Decimal) -> Decimal {
        value < .zero ? -value : value
    }
}

private struct SpendingChange {
    let category: String
    let percentage: Decimal
}
