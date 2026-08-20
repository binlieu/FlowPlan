import Foundation
import Testing
import FlowPlanDomain

@Test func settlingBillMovesAmountFromRemainingToPaidWithoutChangingProjection() {
    let billID = Fixtures.id(20)
    let bill = Fixtures.bill(id: billID, amount: 1_850)
    let base = MonthlyProjectionEngine().project(Fixtures.input(bills: [bill]))
    let payment = Fixtures.transaction(
        amount: 1_850,
        type: .expense,
        settlesBillID: billID
    )
    let paid = MonthlyProjectionEngine().project(
        Fixtures.input(bills: [bill], transactions: [payment])
    )

    #expect(base.remainingBills == 1_850)
    #expect(paid.remainingBills == .zero)
    #expect(paid.billsPaid == 1_850)
    #expect(paid.projectedEndOfMonthBalance == base.projectedEndOfMonthBalance)
}

@Test func unlinkedIncomeIsExtraAndDoesNotSettleExpectation() {
    let income = Fixtures.income(amount: 2_000)
    let extra = Fixtures.transaction(amount: 700, type: .income)
    let base = MonthlyProjectionEngine().project(Fixtures.input(incomeSources: [income]))
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(incomeSources: [income], transactions: [extra])
    )

    #expect(result.incomeReceived == 700)
    #expect(result.remainingExpectedIncome == 2_000)
    #expect(result.totalExpectedIncome == 2_700)
    #expect(result.projectedEndOfMonthBalance == base.projectedEndOfMonthBalance + 700)
}

@Test func twoPaychecksSettleTwoOfThreeOccurrences() {
    let incomeID = Fixtures.id(21)
    let income = Fixtures.income(
        id: incomeID,
        amount: 1_000,
        frequency: .biweekly,
        anchorDate: Fixtures.date(2)
    )
    let first = Fixtures.transaction(
        id: Fixtures.id(22),
        date: Fixtures.date(2),
        amount: 1_000,
        type: .income,
        settlesIncomeID: incomeID
    )
    let second = Fixtures.transaction(
        id: Fixtures.id(23),
        date: Fixtures.date(16),
        amount: 1_000,
        type: .income,
        settlesIncomeID: incomeID
    )
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(incomeSources: [income], transactions: [second, first])
    )

    #expect(result.incomeReceived == 2_000)
    #expect(result.remainingExpectedIncome == 1_000)
    #expect(result.totalExpectedIncome == 3_000)
}

@Test func onePaymentSettlesAtMostOneRepeatedBillOccurrence() {
    let billID = Fixtures.id(24)
    let bill = Fixtures.bill(
        id: billID,
        amount: 100,
        frequency: .weekly,
        anchorDate: Fixtures.date(1)
    )
    let payment = Fixtures.transaction(
        amount: 500,
        type: .expense,
        settlesBillID: billID
    )
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(bills: [bill], transactions: [payment])
    )

    #expect(result.billsPaid == 500)
    #expect(result.remainingBills == 400)
}

@Test func linkedExpenseIsNotDiscretionarySpending() {
    let billID = Fixtures.id(25)
    let payment = Fixtures.transaction(
        amount: 300,
        type: .expense,
        category: "Food",
        settlesBillID: billID
    )
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            budgets: [Fixtures.budget(limit: 500)],
            transactions: [payment]
        )
    )
    #expect(result.billsPaid == 300)
    #expect(result.actualVariableSpending == .zero)
    #expect(result.remainingVariableSpending == 500)
}

@Test func linkedTransactionForUnknownBillStillCountsAsPaidActual() {
    let payment = Fixtures.transaction(
        amount: 275,
        type: .expense,
        settlesBillID: Fixtures.id(26)
    )
    let result = MonthlyProjectionEngine().project(Fixtures.input(transactions: [payment]))
    #expect(result.billsPaid == 275)
    #expect(result.expensesPaid == 275)
    #expect(result.currentAvailableBalance == -275)
}

@Test func duplicateBudgetRowsShareCategorySpending() {
    let expense = Fixtures.transaction(amount: 250, type: .expense, category: "Food")
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            budgets: [
                Fixtures.budget(id: Fixtures.id(27), limit: 200),
                Fixtures.budget(id: Fixtures.id(28), limit: 300)
            ],
            transactions: [expense]
        )
    )
    #expect(result.remainingVariableSpending == 250)
}

@Test func expenseInsideBudgetConsumesBudgetWithoutChangingProjection() {
    let baseInput = Fixtures.input(budgets: [Fixtures.budget(limit: 1_000)])
    let expense = Fixtures.transaction(amount: 500, type: .expense, category: "Food")
    let engine = MonthlyProjectionEngine()
    let base = engine.project(baseInput)
    let actual = engine.project(
        Fixtures.input(budgets: baseInput.budgets, transactions: [expense])
    )
    #expect(actual.projectedEndOfMonthBalance == base.projectedEndOfMonthBalance)
}

@Test func expenseBeyondBudgetReducesProjectionOnlyByOverspend() {
    let engine = MonthlyProjectionEngine()
    let base = engine.project(Fixtures.input(budgets: [Fixtures.budget(limit: 1_000)]))
    let expense = Fixtures.transaction(amount: 1_250, type: .expense, category: "Food")
    let actual = engine.project(
        Fixtures.input(budgets: [Fixtures.budget(limit: 1_000)], transactions: [expense])
    )
    #expect(actual.projectedEndOfMonthBalance == base.projectedEndOfMonthBalance - 250)
    #expect(actual.remainingVariableSpending == .zero)
}

@Test func unbudgetedCategorySpendingReducesProjectionByFullAmount() {
    let engine = MonthlyProjectionEngine()
    let base = engine.project(Fixtures.input(budgets: [Fixtures.budget(limit: 1_000)]))
    let expense = Fixtures.transaction(amount: 500, type: .expense, category: "Travel")
    let actual = engine.project(
        Fixtures.input(budgets: [Fixtures.budget(limit: 1_000)], transactions: [expense])
    )
    #expect(actual.projectedEndOfMonthBalance == base.projectedEndOfMonthBalance - 500)
    #expect(actual.remainingVariableSpending == 1_000)
}
