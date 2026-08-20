import Foundation
import Testing
import FlowPlanDomain

@Test func carRepairReducesProjectionByExactlySixHundred() {
    let input = Fixtures.input(startingBalance: 2_000)
    let repair = Fixtures.transaction(
        amount: 600,
        type: .expense,
        category: "Car repair"
    )
    let result = MonthlyProjectionEngine().simulate(
        WhatIfScenario(additionalTransactions: [repair]),
        on: input
    )
    #expect(result.impact == -600)
}

@Test func additionalIncomeRaisesProjectionByExactlySevenHundred() {
    let income = Fixtures.transaction(amount: 700, type: .income)
    let result = MonthlyProjectionEngine().simulate(
        WhatIfScenario(additionalTransactions: [income]),
        on: Fixtures.input()
    )
    #expect(result.impact == 700)
}

@Test func savingsTargetIncreaseLowersProjectionByExactlyFiveHundred() {
    let input = Fixtures.input(savingsPlans: [Fixtures.savingsPlan(target: 1_000)])
    let result = MonthlyProjectionEngine().simulate(
        WhatIfScenario(savingsTargetOverride: 1_500),
        on: input
    )
    #expect(result.impact == -500)
    #expect(result.simulated.savingsTarget == 1_500)
}

@Test func purchaseImpactIsNegativeTwelveHundredAndBaseIsUnchanged() {
    let input = Fixtures.input(startingBalance: 3_000)
    let engine = MonthlyProjectionEngine()
    let original = engine.project(input)
    let purchase = Fixtures.transaction(amount: 1_200, type: .expense, category: "Purchase")
    let result = engine.simulate(
        WhatIfScenario(additionalTransactions: [purchase]),
        on: input
    )

    #expect(result.impact == -1_200)
    #expect(result.base == original)
    #expect(result.base.projectedEndOfMonthBalance == 3_000)
    #expect(result.simulated.projectedEndOfMonthBalance == 1_800)
}

@Test func whatIfAdditionalTransactionsDoNotMutateInputCollections() {
    let existing = Fixtures.transaction(amount: 100, type: .income)
    let added = Fixtures.transaction(id: Fixtures.id(40), amount: 50, type: .income)
    let input = Fixtures.input(transactions: [existing])
    _ = MonthlyProjectionEngine().simulate(
        WhatIfScenario(additionalTransactions: [added]),
        on: input
    )
    #expect(input.transactions == [existing])
}

@Test func whatIfWithoutChangesProducesZeroImpact() {
    let result = MonthlyProjectionEngine().simulate(WhatIfScenario(), on: Fixtures.input())
    #expect(result.impact == .zero)
    #expect(result.base == result.simulated)
}

@Test func whatIfBreakdownRemainsArithmeticallyConsistent() {
    let expense = Fixtures.transaction(amount: 325, type: .expense, category: "Unexpected")
    let result = MonthlyProjectionEngine().simulate(
        WhatIfScenario(additionalTransactions: [expense]),
        on: Fixtures.input(startingBalance: 1_000)
    )
    #expect(Fixtures.breakdownSubtotal(result.base) == result.base.projectedEndOfMonthBalance)
    #expect(Fixtures.breakdownSubtotal(result.simulated) == result.simulated.projectedEndOfMonthBalance)
}
