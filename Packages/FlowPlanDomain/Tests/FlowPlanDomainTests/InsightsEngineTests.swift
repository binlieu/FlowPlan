import Foundation
import Testing
import FlowPlanDomain

@Test func categorySpendingInsightReportsChangeAboveTenPercent() throws {
    let currentProjection = projection()
    let insights = InsightsEngine().insights(
        for: currentProjection,
        transactions: [expense(id: 60, amount: 112, category: "Groceries")],
        previousTransactions: [expense(id: 61, amount: 100, category: "Groceries")],
        bills: []
    )

    let spending = try #require(insights.first { $0.id == "spending-groceries" })
    #expect(
        spending.kind == .spending(
            category: "Groceries",
            percentageChange: 12
        )
    )
}

@Test func categorySpendingInsightSkipsMissingPreviousDataAndTenPercentThreshold() {
    let currentProjection = projection()
    let engine = InsightsEngine()

    let missingPrevious = engine.insights(
        for: currentProjection,
        transactions: [expense(id: 62, amount: 120, category: "Groceries")],
        previousTransactions: [],
        bills: []
    )
    let exactlyTenPercent = engine.insights(
        for: currentProjection,
        transactions: [expense(id: 63, amount: 110, category: "Groceries")],
        previousTransactions: [expense(id: 64, amount: 100, category: "Groceries")],
        bills: []
    )

    #expect(!missingPrevious.contains { $0.id.hasPrefix("spending-") })
    #expect(!exactlyTenPercent.contains { $0.id.hasPrefix("spending-") })
}

@Test func categorySpendingPercentageGuardsZeroDenominator() {
    let insights = InsightsEngine().insights(
        for: projection(),
        transactions: [expense(id: 65, amount: 100, category: "Dining")],
        previousTransactions: [expense(id: 66, amount: .zero, category: "Dining")],
        bills: []
    )

    #expect(!insights.contains { $0.id.hasPrefix("spending-") })
}

@Test func savingsPaceInsightUsesTheMonthlyTarget() throws {
    let projection = projection(savingsTarget: 1_920)
    let insights = InsightsEngine().insights(
        for: projection,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    let savings = try #require(insights.first { $0.id == "savings-pace" })
    #expect(savings.kind == .savings(monthlyTarget: 1_920))
}

@Test func savingsPaceInsightSkipsMissingTarget() {
    let insights = InsightsEngine().insights(
        for: projection(),
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.id == "savings-pace" })
}

@Test func subscriptionsInsightSumsOnlyActiveMonthlyBillsUnderFiftyDollars() throws {
    let bills = [
        bill(id: 70, amount: 46),
        bill(id: 71, amount: 46),
        bill(id: 72, amount: 46),
        bill(id: 73, amount: 46),
        bill(id: 74, amount: 50),
        bill(id: 75, amount: 20, frequency: .annually),
        bill(id: 76, amount: 20, isActive: false)
    ]
    let insights = InsightsEngine().insights(
        for: projection(),
        transactions: [],
        previousTransactions: [],
        bills: bills
    )

    let subscriptions = try #require(insights.first { $0.id == "subscriptions-total" })
    #expect(subscriptions.kind == .subscriptions(monthlyTotal: 184))
}

@Test func subscriptionsInsightSkipsWhenNoBillsQualify() {
    let insights = InsightsEngine().insights(
        for: projection(),
        transactions: [],
        previousTransactions: [],
        bills: [bill(id: 77, amount: 50)]
    )

    #expect(!insights.contains { $0.id == "subscriptions-total" })
}

@Test func projectionInsightReportsVarianceAgainstPlan() throws {
    let projection = projection(expectedIncome: 6_500, extraIncome: 620)
    let insights = InsightsEngine().insights(
        for: projection,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    let variance = try #require(insights.first { $0.id == "projection-vs-plan" })
    #expect(variance.kind == .projection(month: 8, varianceFromPlan: 620))
}

@Test func projectionInsightSkipsZeroVariance() {
    let insights = InsightsEngine().insights(
        for: projection(),
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.id == "projection-vs-plan" })
}

@Test func projectionInsightSkipsWhenNoPlanExists() {
    let projection = projection(extraIncome: 620)
    let insights = InsightsEngine().insights(
        for: projection,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.id == "projection-vs-plan" })
}

@Test func incomeInsightReportsReceivedExpectedAndRemainingAmounts() throws {
    let projection = projection(expectedIncome: 6_500)
    let insights = InsightsEngine().insights(
        for: projection,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    let income = try #require(insights.first { $0.id == "income-remaining" })
    #expect(
        income.kind == .income(
            received: .zero,
            expected: 6_500,
            remaining: 6_500
        )
    )
}

@Test func incomeInsightSkipsWhenNoGapRemains() {
    let receivedIncome = Fixtures.transaction(amount: 1_000, type: .income)
    let projection = MonthlyProjectionEngine().project(
        Fixtures.input(transactions: [receivedIncome])
    )
    let insights = InsightsEngine().insights(
        for: projection,
        transactions: [receivedIncome],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.id == "income-remaining" })
}

@Test func structuredInsightsContainNoPresentationCopyAndResultCountIsCapped() {
    let categories = (0..<10).map { "Category \($0)" }
    let current = categories.enumerated().map { index, category in
        expense(id: UInt8(100 + index), amount: Decimal(200 + index * 10), category: category)
    }
    let previous = categories.enumerated().map { index, category in
        expense(id: UInt8(120 + index), amount: 100, category: category)
    }
    let insights = InsightsEngine().insights(
        for: projection(expectedIncome: 6_500, savingsTarget: 1_000, extraIncome: 620),
        transactions: current,
        previousTransactions: previous,
        bills: [bill(id: 90, amount: 25)]
    )
    #expect(insights.count == 6)
    #expect(insights.allSatisfy { !$0.id.isEmpty })
}

@Test func noInsightsAreInventedFromEmptyInputs() {
    let insights = InsightsEngine().insights(
        for: projection(),
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(insights.isEmpty)
}

private func projection(
    month: MonthKey = Fixtures.month,
    expectedIncome: Decimal = .zero,
    savingsTarget: Decimal = .zero,
    extraIncome: Decimal = .zero
) -> MonthlyProjection {
    var transactions: [TransactionSnapshot] = []
    if extraIncome > .zero {
        transactions.append(
            Fixtures.transaction(id: Fixtures.id(59), amount: extraIncome, type: .income)
        )
    }

    return MonthlyProjectionEngine().project(
        Fixtures.input(
            month: month,
            referenceDate: month.startDate(calendar: Fixtures.calendar),
            incomeSources: expectedIncome > .zero ? [Fixtures.income(amount: expectedIncome)] : [],
            savingsPlans: savingsTarget > .zero ? [Fixtures.savingsPlan(target: savingsTarget)] : [],
            transactions: transactions
        )
    )
}

private func expense(id: UInt8, amount: Decimal, category: String) -> TransactionSnapshot {
    Fixtures.transaction(
        id: Fixtures.id(id),
        amount: amount,
        type: .expense,
        category: category
    )
}

private func bill(
    id: UInt8,
    amount: Decimal,
    frequency: RecurrenceFrequency = .monthly,
    isActive: Bool = true
) -> PlannedBill {
    Fixtures.bill(
        id: Fixtures.id(id),
        amount: amount,
        frequency: frequency,
        isActive: isActive
    )
}
