import Foundation
import Testing
import FlowPlanDomain

@Test func monthKeyNormalizesMonthAboveRange() {
    #expect(MonthKey(year: 2026, month: 13) == MonthKey(year: 2027, month: 1))
}

@Test func monthKeyNormalizesMonthZero() {
    #expect(MonthKey(year: 2026, month: 0) == MonthKey(year: 2025, month: 12))
}

@Test func monthKeyNormalizesLargeNegativeMonth() {
    #expect(MonthKey(year: 2026, month: -12) == MonthKey(year: 2024, month: 12))
}

@Test func monthKeyInitializesFromDate() {
    let key = MonthKey(date: Fixtures.date(2028, 2, 29), calendar: Fixtures.calendar)
    #expect(key == MonthKey(year: 2028, month: 2))
}

@Test func monthKeyOrdersChronologically() {
    #expect(MonthKey(year: 2025, month: 12) < MonthKey(year: 2026, month: 1))
    #expect(MonthKey(year: 2026, month: 1) < MonthKey(year: 2026, month: 2))
}

@Test func monthKeyNextAndPreviousCrossYears() {
    #expect(MonthKey(year: 2026, month: 12).next == MonthKey(year: 2027, month: 1))
    #expect(MonthKey(year: 2026, month: 1).previous == MonthKey(year: 2025, month: 12))
}

@Test func monthKeyAddsPositiveAndNegativeMonths() {
    let month = MonthKey(year: 2026, month: 6)
    #expect(month.adding(months: 20) == MonthKey(year: 2028, month: 2))
    #expect(month.adding(months: -20) == MonthKey(year: 2024, month: 10))
}

@Test func monthKeyStartDateIsFirstInstant() {
    let start = MonthKey(year: 2026, month: 8).startDate(calendar: Fixtures.calendar)
    #expect(start == Fixtures.date(2026, 8, 1, hour: 0))
}

@Test func monthKeyEndDateIsLastSecond() {
    let end = MonthKey(year: 2026, month: 8).endDate(calendar: Fixtures.calendar)
    #expect(end == Fixtures.date(2026, 8, 31, hour: 23, minute: 59, second: 59))
}

@Test func monthKeyContainsStartAndExcludesNextMonth() {
    let month = MonthKey(year: 2026, month: 8)
    #expect(month.contains(Fixtures.date(2026, 8, 1, hour: 0), calendar: Fixtures.calendar))
    #expect(!month.contains(Fixtures.date(2026, 9, 1, hour: 0), calendar: Fixtures.calendar))
}

@Test func monthKeyReportsCommonMonthLengths() {
    #expect(MonthKey(year: 2027, month: 1).dayCount(calendar: Fixtures.calendar) == 31)
    #expect(MonthKey(year: 2027, month: 2).dayCount(calendar: Fixtures.calendar) == 28)
    #expect(MonthKey(year: 2028, month: 2).dayCount(calendar: Fixtures.calendar) == 29)
    #expect(MonthKey(year: 2027, month: 4).dayCount(calendar: Fixtures.calendar) == 30)
}
