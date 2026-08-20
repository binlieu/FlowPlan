import Foundation
import Testing
import FlowPlanDomain

@Test func daysRemainingOnFirstDayIncludesWholeMonth() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(1))
    )
    #expect(result.daysRemaining == 31)
}

@Test func daysRemainingMidMonthIsInclusive() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(17))
    )
    #expect(result.daysRemaining == 15)
}

@Test func daysRemainingOnLastDayIsOne() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(31, hour: 23, minute: 59))
    )
    #expect(result.daysRemaining == 1)
}

@Test func pastMonthHasNoDaysRemaining() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(2026, 9, 1))
    )
    #expect(result.daysRemaining == 0)
}

@Test func futureMonthHasEveryDayRemaining() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(2026, 7, 31))
    )
    #expect(result.daysRemaining == 31)
}

@Test func dailySafeToSpendIsZeroWithNoDaysRemaining() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            referenceDate: Fixtures.date(2026, 9, 1),
            startingBalance: 1_200
        )
    )
    #expect(result.daysRemaining == 0)
    #expect(result.dailySafeToSpend == .zero)
}

@Test func dailySafeToSpendDividesSpendableAcrossRemainingDays() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(17), startingBalance: 1_200)
    )
    #expect(result.daysRemaining == 15)
    #expect(result.spendableRemaining == 1_200)
    #expect(result.dailySafeToSpend == 80)
}

@Test func dailySafeToSpendRoundsDownToTwoDecimalPlaces() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(29), startingBalance: 100)
    )
    #expect(result.daysRemaining == 3)
    #expect(result.dailySafeToSpend == Decimal(string: "33.33"))
}

@Test func dailySafeToSpendNeverExposesNegativeAmount() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(referenceDate: Fixtures.date(31), startingBalance: -500)
    )
    #expect(result.dailySafeToSpend == .zero)
}

@Test func spendableRemainingIgnoresVariableBudget() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 1_000, budgets: [Fixtures.budget(limit: 800)])
    )
    #expect(result.projectedEndOfMonthBalance == 200)
    #expect(result.spendableRemaining == 1_000)
}
