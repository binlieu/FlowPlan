import Foundation
import Testing
import FlowPlanDomain

@Test func zeroAPRAmortisesInCeilingOfBalanceDividedByPayment() {
    let debt = Fixtures.debt(balance: 1_001, monthlyPayment: 250)
    let schedule = DebtSchedule()

    #expect(schedule.remainingPayments(for: debt) == .value(5))
    #expect(
        schedule.payoffMonth(for: debt, startingIn: MonthKey(year: 2026, month: 11))
            == .value(MonthKey(year: 2027, month: 3))
    )
}

@Test func finalPaymentIsOnlyTheRemainingBalanceAtZeroAPR() {
    let debt = Fixtures.debt(balance: 85.42, monthlyPayment: 200)

    #expect(
        DebtSchedule().paymentDue(
            for: debt,
            in: MonthKey(year: 2026, month: 8)
        ) == 85.42
    )
}

@Test func paidOffDebtContributesNothingAfterItsPayoffMonth() {
    let march = MonthKey(year: 2027, month: 3)
    let april = march.next
    let debt = Fixtures.debt(balance: 100, monthlyPayment: 150)
    let schedule = DebtSchedule(startingIn: march)

    #expect(schedule.payoffMonth(for: debt, startingIn: march) == .value(march))
    #expect(schedule.paymentDue(for: debt, in: march) == 100)
    #expect(schedule.paymentDue(for: debt, in: april) == .zero)
}

@Test func paymentAtOrBelowMonthlyInterestNeverAmortises() {
    let belowInterest = Fixtures.debt(
        balance: 12_000,
        annualInterestRate: 0.12,
        monthlyPayment: 99
    )
    let equalToInterest = Fixtures.debt(
        balance: 12_000,
        annualInterestRate: 0.12,
        monthlyPayment: 120
    )

    #expect(DebtSchedule().remainingPayments(for: belowInterest) == .neverAmortises)
    #expect(DebtSchedule().remainingPayments(for: equalToInterest) == .neverAmortises)
    #expect(
        DebtSchedule().payoffMonth(
            for: belowInterest,
            startingIn: MonthKey(year: 2026, month: 8)
        ) == .neverAmortises
    )
}

@Test func everyScheduleTraversalIsCappedAtSixHundredMonths() {
    let slowDebt = Fixtures.debt(
        balance: 1_000_000,
        annualInterestRate: .zero,
        monthlyPayment: 1
    )

    #expect(DebtSchedule.maximumMonths == 600)
    #expect(DebtSchedule().remainingPayments(for: slowDebt) == .exceedsMaximumTerm)
}
