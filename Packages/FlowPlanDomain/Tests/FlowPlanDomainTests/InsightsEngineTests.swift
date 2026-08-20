import Foundation
import Testing
import FlowPlanDomain

@Test func categorySpendingInsightReportsChangeAboveTenPercent() throws {
    let currentProjection = projection()
    let previousProjection = projection(month: Fixtures.month.previous)
    let insights = InsightsEngine().insights(
        for: currentProjection,
        previous: previousProjection,
        transactions: [expense(id: 60, amount: 112, category: "Groceries")],
        previousTransactions: [expense(id: 61, amount: 100, category: "Groceries")],
        bills: []
    )

    let spending = try #require(insights.first { $0.kind == .spending })
    #expect(spending.message == "Your grocery spending is 12% higher than last month.")
}

@Test func categorySpendingInsightSkipsMissingPreviousDataAndTenPercentThreshold() {
    let currentProjection = projection()
    let previousProjection = projection(month: Fixtures.month.previous)
    let engine = InsightsEngine()

    let missingPrevious = engine.insights(
        for: currentProjection,
        previous: previousProjection,
        transactions: [expense(id: 62, amount: 120, category: "Groceries")],
        previousTransactions: [],
        bills: []
    )
    let exactlyTenPercent = engine.insights(
        for: currentProjection,
        previous: previousProjection,
        transactions: [expense(id: 63, amount: 110, category: "Groceries")],
        previousTransactions: [expense(id: 64, amount: 100, category: "Groceries")],
        bills: []
    )

    #expect(!missingPrevious.contains { $0.kind == .spending })
    #expect(!exactlyTenPercent.contains { $0.kind == .spending })
}

@Test func categorySpendingPercentageGuardsZeroDenominator() {
    let insights = InsightsEngine().insights(
        for: projection(),
        previous: projection(month: Fixtures.month.previous),
        transactions: [expense(id: 65, amount: 100, category: "Dining")],
        previousTransactions: [expense(id: 66, amount: .zero, category: "Dining")],
        bills: []
    )

    #expect(!insights.contains { $0.kind == .spending })
}

@Test func savingsPaceInsightUsesTheMonthlyTarget() throws {
    let projection = projection(savingsTarget: 1_920)
    let insights = InsightsEngine().insights(
        for: projection,
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    let savings = try #require(insights.first { $0.kind == .savings })
    #expect(savings.message == "You're on track to save $1,920 this month.")
}

@Test func savingsPaceInsightSkipsMissingTarget() {
    let insights = InsightsEngine().insights(
        for: projection(),
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.kind == .savings })
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
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: bills
    )

    let subscriptions = try #require(insights.first { $0.kind == .subscriptions })
    #expect(subscriptions.message == "Your subscriptions total $184/month.")
}

@Test func subscriptionsInsightSkipsWhenNoBillsQualify() {
    let insights = InsightsEngine().insights(
        for: projection(),
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: [bill(id: 77, amount: 50)]
    )

    #expect(!insights.contains { $0.kind == .subscriptions })
}

@Test func projectionInsightReportsVarianceAgainstPlan() throws {
    let projection = projection(expectedIncome: 6_500, extraIncome: 620)
    let insights = InsightsEngine().insights(
        for: projection,
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    let variance = try #require(insights.first { $0.kind == .projection })
    #expect(variance.message == "You're projected to finish August $620 ahead of plan.")
}

@Test func projectionInsightSkipsZeroVariance() {
    let insights = InsightsEngine().insights(
        for: projection(),
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.kind == .projection })
}

@Test func projectionInsightSkipsWhenNoPlanExists() {
    let projection = projection(extraIncome: 620)
    let insights = InsightsEngine().insights(
        for: projection,
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.kind == .projection })
}

@Test func incomeInsightReportsReceivedExpectedAndRemainingAmounts() throws {
    let projection = projection(expectedIncome: 6_500)
    let insights = InsightsEngine().insights(
        for: projection,
        previous: nil,
        transactions: [],
        previousTransactions: [],
        bills: []
    )

    let income = try #require(insights.first { $0.kind == .income })
    #expect(income.message == "You've received $0 of $6,500 expected income; $6,500 remains.")
}

@Test func incomeInsightSkipsWhenNoGapRemains() {
    let receivedIncome = Fixtures.transaction(amount: 1_000, type: .income)
    let projection = MonthlyProjectionEngine().project(
        Fixtures.input(transactions: [receivedIncome])
    )
    let insights = InsightsEngine().insights(
        for: projection,
        previous: nil,
        transactions: [receivedIncome],
        previousTransactions: [],
        bills: []
    )

    #expect(!insights.contains { $0.kind == .income })
}

@Test func insightMessagesRemainFactualAndResultCountIsCapped() {
    let categories = (0..<10).map { "Category \($0)" }
    let current = categories.enumerated().map { index, category in
        expense(id: UInt8(100 + index), amount: Decimal(200 + index * 10), category: category)
    }
    let previous = categories.enumerated().map { index, category in
        expense(id: UInt8(120 + index), amount: 100, category: category)
    }
    let insights = InsightsEngine().insights(
        for: projection(expectedIncome: 6_500, savingsTarget: 1_000, extraIncome: 620),
        previous: projection(month: Fixtures.month.previous),
        transactions: current,
        previousTransactions: previous,
        bills: [bill(id: 90, amount: 25)]
    )
    let judgementalWords = ["bad", "good", "overspent", "worse", "great", "poor", "should"]

    #expect(insights.count == 6)
    #expect(insights.allSatisfy { insight in
        judgementalWords.allSatisfy {
            !insight.message.lowercased().contains($0)
        }
    })
}

@Test func noInsightsAreInventedFromEmptyInputs() {
    let insights = InsightsEngine().insights(
        for: projection(),
        previous: nil,
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
