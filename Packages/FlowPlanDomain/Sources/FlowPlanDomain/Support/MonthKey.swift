import Foundation

public struct MonthKey: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        let zeroBasedMonth = month - 1
        var yearOffset = zeroBasedMonth / 12
        var normalizedMonth = zeroBasedMonth % 12

        if normalizedMonth < 0 {
            normalizedMonth += 12
            yearOffset -= 1
        }

        self.year = year + yearOffset
        self.month = normalizedMonth + 1
    }

    public init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            preconditionFailure("The supplied calendar could not resolve a year and month.")
        }

        self.init(year: year, month: month)
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }

        return lhs.month < rhs.month
    }

    public var next: MonthKey {
        adding(months: 1)
    }

    public var previous: MonthKey {
        adding(months: -1)
    }

    public func startDate(calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = 1

        guard let date = calendar.date(from: components) else {
            preconditionFailure("The supplied calendar could not construct the month start date.")
        }

        return date
    }

    public func endDate(calendar: Calendar) -> Date {
        let nextMonthStart = next.startDate(calendar: calendar)
        guard let date = calendar.date(byAdding: .second, value: -1, to: nextMonthStart) else {
            preconditionFailure("The supplied calendar could not construct the month end date.")
        }

        return date
    }

    public func dayCount(calendar: Calendar) -> Int {
        let start = startDate(calendar: calendar)
        guard let range = calendar.range(of: .day, in: .month, for: start) else {
            preconditionFailure("The supplied calendar could not determine the month's day count.")
        }

        return range.count
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let start = startDate(calendar: calendar)
        let endExclusive = next.startDate(calendar: calendar)
        return date >= start && date < endExclusive
    }

    public func adding(months: Int) -> MonthKey {
        MonthKey(year: year, month: month + months)
    }
}
