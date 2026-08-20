import Foundation
import Testing
import FlowPlanDomain

@Test func baselineProjectionMatchesFullPlanExample() {
    let input = Fixtures.input(
        incomeSources: [Fixtures.income(amount: 8_500)],
        bills: [Fixtures.bill(amount: 2_393)],
        budgets: [Fixtures.budget(limit: 2_500)],
        savingsPlans: [Fixtures.savingsPlan(target: 2_000)]
    )
    let result = MonthlyProjectionEngine().project(input)

    #expect(result.projectedEndOfMonthBalance == 1_607)
    #expect(result.plannedEndOfMonthBalance == 1_607)
}

@Test func baselineProjectionMatchesBriefExample() {
    let input = Fixtures.input(
        incomeSources: [Fixtures.income(amount: 8_500)],
        bills: [Fixtures.bill(amount: 5_000)],
        savingsPlans: [Fixtures.savingsPlan(target: 2_000)]
    )
    #expect(MonthlyProjectionEngine().project(input).projectedEndOfMonthBalance == 1_500)
}

@Test func plannedTotalsInvariantHoldsWithoutAPlan() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 975)
    )

    #expect(plannedBalance(from: result) == result.plannedEndOfMonthBalance)
    #expect(result.plannedIncomeTotal == .zero)
    #expect(result.plannedBillsTotal == .zero)
    #expect(result.plannedSpendingTotal == .zero)
}

@Test func plannedTotalsInvariantHoldsForACompletePlan() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            startingBalance: 1_200,
            incomeSources: [Fixtures.income(amount: 6_500)],
            bills: [Fixtures.bill(amount: 1_850)],
            budgets: [Fixtures.budget(limit: 900)],
            savingsPlans: [Fixtures.savingsPlan(target: 1_000)]
        )
    )

    #expect(plannedBalance(from: result) == result.plannedEndOfMonthBalance)
}

@Test func plannedTotalsInvariantCountsEveryInMonthRecurrence() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            incomeSources: [
                Fixtures.income(
                    amount: 1_500,
                    frequency: .biweekly,
                    anchorDate: Fixtures.date(7)
                )
            ]
        )
    )

    #expect(result.plannedIncomeTotal == 3_000)
    #expect(plannedBalance(from: result) == result.plannedEndOfMonthBalance)
}

@Test func plannedBillTotalRemainsDistinctAfterBillIsPaid() {
    let billID = Fixtures.id(41)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            bills: [Fixtures.bill(id: billID, amount: 425)],
            transactions: [
                Fixtures.transaction(
                    amount: 425,
                    type: .expense,
                    settlesBillID: billID
                )
            ]
        )
    )

    #expect(result.plannedBillsTotal == 425)
    #expect(result.remainingBills == .zero)
    #expect(result.plannedBillsTotal != result.remainingBills)
}

@Test func transferTransactionsAreIgnoredEntirely() {
    let transfer = Fixtures.transaction(amount: 9_999, type: .transfer)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 1_000, transactions: [transfer])
    )
    #expect(result.currentAvailableBalance == 1_000)
    #expect(result.projectedEndOfMonthBalance == 1_000)
}

@Test func transactionsOutsideProjectionMonthAreIgnored() {
    let outsideIncome = Fixtures.transaction(
        date: Fixtures.date(2026, 9, 1),
        amount: 700,
        type: .income
    )
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(transactions: [outsideIncome])
    )
    #expect(result.incomeReceived == .zero)
}

@Test func savingsActualsReduceRemainingGoal() {
    let savings = Fixtures.transaction(amount: 600, type: .savings)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            incomeSources: [Fixtures.income(amount: 4_000)],
            savingsPlans: [Fixtures.savingsPlan(target: 1_000)],
            transactions: [savings]
        )
    )
    #expect(result.savingsCompleted == 600)
    #expect(result.remainingSavingsGoal == 400)
    #expect(result.savingsTarget == 1_000)
}

@Test func savingsCompletionAboveTargetDoesNotCreateNegativeGoal() {
    let savings = Fixtures.transaction(amount: 1_400, type: .savings)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            savingsPlans: [Fixtures.savingsPlan(target: 1_000)],
            transactions: [savings]
        )
    )
    #expect(result.remainingSavingsGoal == .zero)
}

@Test func negativeProjectionIsPreservedAndMarkedNegative() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(bills: [Fixtures.bill(amount: 420)])
    )
    #expect(result.projectedEndOfMonthBalance == -420)
    #expect(result.status == .negative)
}

@Test func statusIsTightBelowConfiguredThreshold() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 150)
    )
    #expect(result.status == .tight)
}

@Test func statusIsHealthyAtTightThreshold() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 200)
    )
    #expect(result.status == .healthy)
}

@Test func extraIncomeCanProduceAheadOfPlanStatus() {
    let extraIncome = Fixtures.transaction(amount: 700, type: .income)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 500, transactions: [extraIncome])
    )
    #expect(result.varianceVsPlan == 700)
    #expect(result.status == .aheadOfPlan)
}

@Test func savingsRateUsesExpectedIncomeAndSavingsGoal() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            incomeSources: [Fixtures.income(amount: 4_000)],
            savingsPlans: [Fixtures.savingsPlan(target: 1_000)]
        )
    )
    #expect(result.savingsRate == Decimal(string: "0.25"))
}

@Test func savingsRateIsZeroWithoutExpectedIncome() {
    let result = MonthlyProjectionEngine().project(Fixtures.input())
    #expect(result.savingsRate == .zero)
}

@Test func inactivePlansDoNotEnterProjection() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            incomeSources: [Fixtures.income(amount: 5_000, isActive: false)],
            bills: [Fixtures.bill(amount: 2_000, isActive: false)]
        )
    )
    #expect(result.remainingExpectedIncome == .zero)
    #expect(result.remainingBills == .zero)
}

@Test func emptyInputReportsEveryCompletenessGapInStableOrder() {
    let completeness = MonthlyProjectionEngine().project(Fixtures.input()).completeness
    #expect(!completeness.isComplete)
    #expect(completeness.missing == [
        "Starting balance",
        "Planned income",
        "Bills",
        "Spending budget",
        "Savings goal"
    ])
}

@Test func populatedInputIsComplete() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            startingBalance: 1,
            incomeSources: [Fixtures.income(amount: 1)],
            bills: [Fixtures.bill(amount: 1)],
            budgets: [Fixtures.budget(limit: 1)],
            savingsPlans: [Fixtures.savingsPlan(target: .zero)]
        )
    )
    #expect(result.completeness.isComplete)
    #expect(result.completeness.missing.isEmpty)
}

@Test func breakdownHasRequiredOrderKindsAndSigns() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            startingBalance: 100,
            incomeSources: [Fixtures.income(amount: 1_000)],
            bills: [Fixtures.bill(amount: 200)],
            budgets: [Fixtures.budget(limit: 300)],
            savingsPlans: [Fixtures.savingsPlan(target: 100)]
        )
    )
    #expect(result.breakdown.map(\.id) == [
        "currentAvailable", "remainingIncome", "remainingBills",
        "remainingDebt", "remainingSpending", "remainingSavings", "projectedBalance"
    ])
    #expect(result.breakdown.map(\.kind) == [
        .opening, .addition, .deduction, .deduction, .deduction, .deduction, .total
    ])
    #expect(result.breakdown[2].amount < .zero)
    #expect(result.breakdown[3].amount == .zero)
    #expect(result.breakdown[4].amount < .zero)
    #expect(result.breakdown[5].amount < .zero)
}

@Test func breakdownSubtotalMatchesProjectionInBaseline() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            incomeSources: [Fixtures.income(amount: 8_500)],
            bills: [Fixtures.bill(amount: 2_393)],
            budgets: [Fixtures.budget(limit: 2_500)],
            savingsPlans: [Fixtures.savingsPlan(target: 2_000)]
        )
    )
    #expect(Fixtures.breakdownSubtotal(result) == result.projectedEndOfMonthBalance)
}

@Test func breakdownSubtotalMatchesProjectionWithActuals() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            startingBalance: 600,
            incomeSources: [Fixtures.income(amount: 2_000)],
            budgets: [Fixtures.budget(limit: 500)],
            transactions: [
                Fixtures.transaction(amount: 900, type: .income),
                Fixtures.transaction(id: Fixtures.id(6), amount: 200, type: .expense, category: "Food")
            ]
        )
    )
    #expect(Fixtures.breakdownSubtotal(result) == result.projectedEndOfMonthBalance)
}

private func plannedBalance(from projection: MonthlyProjection) -> Decimal {
    projection.startingBalance
        + projection.plannedIncomeTotal
        - projection.plannedBillsTotal
        - projection.debtPaymentsDue
        - projection.plannedSpendingTotal
        - projection.savingsTarget
}
