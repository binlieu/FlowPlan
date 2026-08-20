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

@Test func dueDayClampsToTheLastDayOfShortMonths() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let debt = Fixtures.debt(balance: 10_000, monthlyPayment: 100, dueDay: 31)
    let schedule = DebtSchedule(startingIn: MonthKey(year: 2026, month: 4))

    let aprilDate = try #require(
        schedule.paymentDate(
            for: debt,
            in: MonthKey(year: 2026, month: 4),
            calendar: calendar
        )
    )
    let february2027Date = try #require(
        schedule.paymentDate(
            for: debt,
            in: MonthKey(year: 2027, month: 2),
            calendar: calendar
        )
    )
    let february2028Date = try #require(
        schedule.paymentDate(
            for: debt,
            in: MonthKey(year: 2028, month: 2),
            calendar: calendar
        )
    )

    #expect(calendar.component(.day, from: aprilDate) == 30)
    #expect(calendar.component(.day, from: february2027Date) == 28)
    #expect(calendar.component(.day, from: february2028Date) == 29)
}

@Test func paymentDateIsNilAfterThePayoffMonth() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let march = MonthKey(year: 2027, month: 3)
    let debt = Fixtures.debt(balance: 100, monthlyPayment: 150, dueDay: 15)
    let schedule = DebtSchedule(startingIn: march)

    #expect(schedule.paymentDate(for: debt, in: march, calendar: calendar) != nil)
    #expect(schedule.paymentDate(for: debt, in: march.next, calendar: calendar) == nil)
}

@Test func futureFirstPaymentMonthHasNoPaymentOrDateBeforeIt() {
    let october = MonthKey(year: 2026, month: 10)
    let debt = Fixtures.debt(
        balance: 10_000,
        monthlyPayment: 500,
        firstPaymentMonth: october,
        dueDay: 15
    )
    let schedule = DebtSchedule(startingIn: MonthKey(year: 2026, month: 8))

    #expect(schedule.paymentDue(for: debt, in: MonthKey(year: 2026, month: 8)) == .zero)
    #expect(schedule.paymentDue(for: debt, in: MonthKey(year: 2026, month: 9)) == .zero)
    #expect(
        schedule.paymentDate(
            for: debt,
            in: MonthKey(year: 2026, month: 9),
            calendar: Fixtures.calendar
        ) == nil
    )
    #expect(schedule.paymentDue(for: debt, in: october) == 500)
    #expect(schedule.paymentDate(for: debt, in: october, calendar: Fixtures.calendar) != nil)
}
