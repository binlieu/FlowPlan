import Foundation
import Testing
import FlowPlanDomain

@Test func debtAutopayChangesNoProjectionFigure() {
    let debtID = Fixtures.id(70)
    let manualDebt = Fixtures.debt(
        id: debtID,
        balance: 8_000,
        annualInterestRate: 0.0649,
        monthlyPayment: 505,
        dueDay: 15
    )
    let autopayDebt = Fixtures.debt(
        id: debtID,
        balance: 8_000,
        annualInterestRate: 0.0649,
        monthlyPayment: 505,
        dueDay: 15,
        isAutoPay: true
    )
    let engine = MonthlyProjectionEngine()

    let manualProjection = engine.project(
        Fixtures.input(startingBalance: 2_000, debts: [manualDebt])
    )
    let autopayProjection = engine.project(
        Fixtures.input(startingBalance: 2_000, debts: [autopayDebt])
    )

    #expect(autopayProjection == manualProjection)
}

@Test func debtPaidThroughBillsChangesNoProjectionFigure() {
    let engine = MonthlyProjectionEngine()
    let base = engine.project(Fixtures.input(startingBalance: 2_000))
    let trackedOnly = engine.project(
        Fixtures.input(
            startingBalance: 2_000,
            debts: [
                Fixtures.debt(
                    balance: 250_000,
                    annualInterestRate: 0.0649,
                    monthlyPayment: 1_850,
                    isPaidThroughBills: true
                )
            ]
        )
    )

    #expect(trackedOnly == base)
    #expect(trackedOnly.debtPaymentsDue == .zero)
    #expect(trackedOnly.debtPaymentsMade == .zero)
    #expect(trackedOnly.remainingDebtPayments == .zero)
}

@Test func separatelyCountedDebtReducesEveryCommittedProjectionFigure() {
    let debt = Fixtures.debt(balance: 8_000, monthlyPayment: 505)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 2_000, debts: [debt])
    )

    #expect(result.debtPaymentsDue == 505)
    #expect(result.remainingDebtPayments == 505)
    #expect(result.projectedEndOfMonthBalance == 1_495)
    #expect(result.plannedEndOfMonthBalance == 1_495)
    #expect(result.spendableRemaining == 1_495)
}

@Test func settlingDebtMovesDueToMadeWithoutChangingProjection() {
    let debtID = Fixtures.id(71)
    let debt = Fixtures.debt(id: debtID, balance: 8_000, monthlyPayment: 505)
    let engine = MonthlyProjectionEngine()
    let before = engine.project(Fixtures.input(startingBalance: 2_000, debts: [debt]))
    let payment = Fixtures.transaction(
        amount: 505,
        type: .expense,
        settlesDebtID: debtID
    )
    let after = engine.project(
        Fixtures.input(startingBalance: 2_000, debts: [debt], transactions: [payment])
    )

    #expect(before.remainingDebtPayments == 505)
    #expect(after.remainingDebtPayments == .zero)
    #expect(after.debtPaymentsMade == 505)
    #expect(after.actualVariableSpending == .zero)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

@Test func inactiveDebtContributesNothing() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            startingBalance: 2_000,
            debts: [Fixtures.debt(balance: 8_000, monthlyPayment: 505, isActive: false)]
        )
    )

    #expect(result.debtPaymentsDue == .zero)
    #expect(result.projectedEndOfMonthBalance == 2_000)
}

@Test func breakdownRowsReconcileWithDebtPresent() {
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            startingBalance: 2_000,
            incomeSources: [Fixtures.income(amount: 3_000)],
            bills: [Fixtures.bill(amount: 800)],
            debts: [Fixtures.debt(balance: 8_000, monthlyPayment: 505)],
            budgets: [Fixtures.budget(limit: 400)],
            savingsPlans: [Fixtures.savingsPlan(target: 300)]
        )
    )

    #expect(result.breakdown.map(\.id) == [
        "currentAvailable",
        "remainingIncome",
        "remainingBills",
        "remainingDebt",
        "remainingSpending",
        "remainingSavings",
        "projectedBalance"
    ])
    #expect(result.breakdown[3].label == "Debt payments")
    #expect(result.breakdown[3].amount == -505)
    #expect(Fixtures.breakdownSubtotal(result) == result.projectedEndOfMonthBalance)
}

@Test func debtThatPaysOffInMarchDoesNotEnterAprilProjection() {
    let march = MonthKey(year: 2027, month: 3)
    let april = march.next
    let debt = Fixtures.debt(balance: 100, monthlyPayment: 150)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            month: april,
            referenceDate: Fixtures.date(2027, 3, 15),
            startingBalance: 500,
            debts: [debt]
        )
    )

    #expect(DebtSchedule().payoffMonth(for: debt, startingIn: march) == .value(march))
    #expect(result.debtPaymentsDue == .zero)
    #expect(result.projectedEndOfMonthBalance == 500)
}

@Test func projectionProvidesAnUnsettledDatedDebtOccurrence() throws {
    let debtID = Fixtures.id(72)
    let debt = Fixtures.debt(
        id: debtID,
        balance: 8_000,
        monthlyPayment: 505,
        dueDay: 31
    )
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            month: MonthKey(year: 2026, month: 4),
            startingBalance: 2_000,
            debts: [debt]
        )
    )
    let occurrence = try #require(result.debtOccurrences.first)

    #expect(result.debtOccurrences.count == 1)
    #expect(occurrence.debtID == debtID)
    #expect(occurrence.name == debt.name)
    #expect(occurrence.amount == 505)
    #expect(!occurrence.isPaidThroughBills)
    #expect(result.month.contains(occurrence.date, calendar: Fixtures.calendar))
    #expect(Fixtures.calendar.component(.day, from: occurrence.date) == 30)
}

@Test func settledAndBillPaidDebtsDoNotProduceHomeOccurrences() {
    let separateDebtID = Fixtures.id(73)
    let separateDebt = Fixtures.debt(
        id: separateDebtID,
        balance: 8_000,
        monthlyPayment: 505,
        dueDay: 15
    )
    let paidThroughBills = Fixtures.debt(
        id: Fixtures.id(74),
        balance: 250_000,
        monthlyPayment: 1_850,
        dueDay: 1,
        isPaidThroughBills: true
    )
    let payment = Fixtures.transaction(
        amount: 505,
        type: .expense,
        settlesDebtID: separateDebtID
    )
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(
            debts: [separateDebt, paidThroughBills],
            transactions: [payment]
        )
    )

    #expect(result.debtOccurrences.isEmpty)
}

@Test func debtContributesNothingUntilItsFirstPaymentMonth() {
    let october = MonthKey(year: 2026, month: 10)
    let debt = Fixtures.debt(
        balance: 8_000,
        monthlyPayment: 505,
        firstPaymentMonth: october
    )
    let engine = MonthlyProjectionEngine()

    for month in [MonthKey(year: 2026, month: 8), MonthKey(year: 2026, month: 9)] {
        let result = engine.project(
            Fixtures.input(
                month: month,
                referenceDate: Fixtures.date(2026, 8, 20),
                startingBalance: 2_000,
                debts: [debt]
            )
        )

        #expect(result.debtPaymentsDue == .zero)
        #expect(result.remainingDebtPayments == .zero)
        #expect(result.projectedEndOfMonthBalance == 2_000)
        #expect(result.plannedEndOfMonthBalance == 2_000)
        #expect(result.spendableRemaining == 2_000)
        #expect(result.debtOccurrences.isEmpty)
    }

    let firstMonth = engine.project(
        Fixtures.input(
            month: october,
            referenceDate: Fixtures.date(2026, 8, 20),
            startingBalance: 2_000,
            debts: [debt]
        )
    )

    #expect(firstMonth.debtPaymentsDue == 505)
    #expect(firstMonth.remainingDebtPayments == 505)
    #expect(firstMonth.projectedEndOfMonthBalance == 1_495)
    #expect(firstMonth.debtOccurrences.count == 1)
}

@Test func nilFirstPaymentMonthPreservesImmediateStartBehavior() {
    let debt = Fixtures.debt(balance: 8_000, monthlyPayment: 505)
    let result = MonthlyProjectionEngine().project(
        Fixtures.input(startingBalance: 2_000, debts: [debt])
    )

    #expect(debt.firstPaymentMonth == nil)
    #expect(result.debtPaymentsDue == 505)
    #expect(result.remainingDebtPayments == 505)
    #expect(result.projectedEndOfMonthBalance == 1_495)
}
