import Foundation
import Testing
import FlowPlanDomain

@Test func weeklyRecurrenceReturnsEverySevenDays() {
    let rule = RecurrenceRule(frequency: .weekly, anchorDate: Fixtures.date(1))
    let dates = rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar)
    #expect(dates == [
        Fixtures.date(1), Fixtures.date(8), Fixtures.date(15),
        Fixtures.date(22), Fixtures.date(29)
    ])
}

@Test func biweeklyRecurrenceReturnsEveryFourteenDays() {
    let rule = RecurrenceRule(frequency: .biweekly, anchorDate: Fixtures.date(2))
    let dates = rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar)
    #expect(dates == [Fixtures.date(2), Fixtures.date(16), Fixtures.date(30)])
}

@Test func weeklyRecurrenceContinuesFromEarlierAnchor() {
    let rule = RecurrenceRule(
        frequency: .weekly,
        anchorDate: Fixtures.date(2026, 7, 29)
    )
    let dates = rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar)
    #expect(dates.first == Fixtures.date(5))
    #expect(dates.last == Fixtures.date(26))
}

@Test func monthlyRecurrenceClampsJanuary31ToFebruary28() {
    let rule = RecurrenceRule(
        frequency: .monthly,
        anchorDate: Fixtures.date(2027, 1, 31)
    )
    let dates = rule.occurrences(
        in: MonthKey(year: 2027, month: 2),
        calendar: Fixtures.calendar
    )
    #expect(dates == [Fixtures.date(2027, 2, 28)])
}

@Test func monthlyRecurrenceClampsJanuary31ToLeapDay() {
    let rule = RecurrenceRule(
        frequency: .monthly,
        anchorDate: Fixtures.date(2028, 1, 31)
    )
    let dates = rule.occurrences(
        in: MonthKey(year: 2028, month: 2),
        calendar: Fixtures.calendar
    )
    #expect(dates == [Fixtures.date(2028, 2, 29)])
}

@Test func monthlyRecurrenceRestoresAnchorDayAfterShortMonth() {
    let rule = RecurrenceRule(
        frequency: .monthly,
        anchorDate: Fixtures.date(2027, 1, 31)
    )
    let dates = rule.occurrences(
        in: MonthKey(year: 2027, month: 3),
        calendar: Fixtures.calendar
    )
    #expect(dates == [Fixtures.date(2027, 3, 31)])
}

@Test func quarterlyRecurrenceSkipsIntermediateMonths() {
    let rule = RecurrenceRule(
        frequency: .quarterly,
        anchorDate: Fixtures.date(2026, 1, 31)
    )
    #expect(rule.occurrences(in: MonthKey(year: 2026, month: 3), calendar: Fixtures.calendar).isEmpty)
    #expect(rule.occurrences(in: MonthKey(year: 2026, month: 4), calendar: Fixtures.calendar) == [
        Fixtures.date(2026, 4, 30)
    ])
}

@Test func semiannualRecurrenceOccursSixMonthsAfterAnchor() {
    let rule = RecurrenceRule(
        frequency: .semiannually,
        anchorDate: Fixtures.date(2026, 2, 15)
    )
    #expect(rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar) == [Fixtures.date(15)])
}

@Test func annualLeapDayRecurrenceClampsInNonLeapYear() {
    let rule = RecurrenceRule(
        frequency: .annually,
        anchorDate: Fixtures.date(2028, 2, 29)
    )
    let dates = rule.occurrences(
        in: MonthKey(year: 2029, month: 2),
        calendar: Fixtures.calendar
    )
    #expect(dates == [Fixtures.date(2029, 2, 28)])
}

@Test func recurrenceReturnsNothingBeforeAnchor() {
    let rule = RecurrenceRule(
        frequency: .monthly,
        anchorDate: Fixtures.date(2026, 9, 1)
    )
    #expect(rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar).isEmpty)
}

@Test func recurrenceEndDateIsInclusive() {
    let rule = RecurrenceRule(
        frequency: .weekly,
        anchorDate: Fixtures.date(1),
        endDate: Fixtures.date(15)
    )
    #expect(rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar) == [
        Fixtures.date(1), Fixtures.date(8), Fixtures.date(15)
    ])
}

@Test func recurrenceReturnsNothingAfterEndDate() {
    let rule = RecurrenceRule(
        frequency: .monthly,
        anchorDate: Fixtures.date(2026, 6, 10),
        endDate: Fixtures.date(2026, 7, 10)
    )
    #expect(rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar).isEmpty)
}

@Test func monthlyRecurrencePreservesAnchorTime() {
    let anchor = Fixtures.date(2026, 7, 30, hour: 18, minute: 45)
    let rule = RecurrenceRule(frequency: .monthly, anchorDate: anchor)
    #expect(rule.occurrences(in: Fixtures.month, calendar: Fixtures.calendar) == [
        Fixtures.date(30, hour: 18, minute: 45)
    ])
}
