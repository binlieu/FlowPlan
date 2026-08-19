import Foundation

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case semiannually
    case annually
}

public struct RecurrenceRule: Hashable, Codable, Sendable {
    public let frequency: RecurrenceFrequency
    public let anchorDate: Date
    public let endDate: Date?

    public init(frequency: RecurrenceFrequency, anchorDate: Date, endDate: Date? = nil) {
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.endDate = endDate
    }

    public func occurrences(in month: MonthKey, calendar: Calendar) -> [Date] {
        let monthStart = month.startDate(calendar: calendar)
        let monthEndExclusive = month.next.startDate(calendar: calendar)

        if anchorDate >= monthEndExclusive || endDate.map({ $0 < monthStart }) == true {
            return []
        }

        switch frequency {
        case .weekly:
            return dayBasedOccurrences(
                every: 7,
                monthStart: monthStart,
                monthEndExclusive: monthEndExclusive,
                calendar: calendar
            )
        case .biweekly:
            return dayBasedOccurrences(
                every: 14,
                monthStart: monthStart,
                monthEndExclusive: monthEndExclusive,
                calendar: calendar
            )
        case .monthly:
            return monthlyOccurrences(
                every: 1,
                monthStart: monthStart,
                monthEndExclusive: monthEndExclusive,
                calendar: calendar
            )
        case .quarterly:
            return monthlyOccurrences(
                every: 3,
                monthStart: monthStart,
                monthEndExclusive: monthEndExclusive,
                calendar: calendar
            )
        case .semiannually:
            return monthlyOccurrences(
                every: 6,
                monthStart: monthStart,
                monthEndExclusive: monthEndExclusive,
                calendar: calendar
            )
        case .annually:
            return monthlyOccurrences(
                every: 12,
                monthStart: monthStart,
                monthEndExclusive: monthEndExclusive,
                calendar: calendar
            )
        }
    }

    private func dayBasedOccurrences(
        every intervalDays: Int,
        monthStart: Date,
        monthEndExclusive: Date,
        calendar: Calendar
    ) -> [Date] {
        var occurrence = anchorDate

        if occurrence < monthStart {
            let anchorDay = calendar.startOfDay(for: anchorDate)
            let targetDay = calendar.startOfDay(for: monthStart)
            let elapsedDays = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
            let completedIntervals = max(0, elapsedDays / intervalDays)
            occurrence = adding(days: completedIntervals * intervalDays, to: anchorDate, calendar: calendar)

            while occurrence < monthStart {
                occurrence = adding(days: intervalDays, to: occurrence, calendar: calendar)
            }
        }

        var results: [Date] = []
        while occurrence < monthEndExclusive {
            if occurrence >= monthStart && isBeforeOrOnEndDate(occurrence) {
                results.append(occurrence)
            }

            if endDate.map({ occurrence >= $0 }) == true {
                break
            }

            occurrence = adding(days: intervalDays, to: occurrence, calendar: calendar)
        }

        return results
    }

    private func monthlyOccurrences(
        every intervalMonths: Int,
        monthStart: Date,
        monthEndExclusive: Date,
        calendar: Calendar
    ) -> [Date] {
        let anchorMonthStart = calendar.dateInterval(of: .month, for: anchorDate)?.start ?? anchorDate
        let elapsedMonths = calendar.dateComponents([.month], from: anchorMonthStart, to: monthStart).month ?? 0
        var occurrenceIndex = max(0, elapsedMonths / intervalMonths)
        var occurrence = monthlyOccurrence(
            at: occurrenceIndex,
            intervalMonths: intervalMonths,
            calendar: calendar
        )

        while occurrence < monthStart {
            occurrenceIndex += 1
            occurrence = monthlyOccurrence(
                at: occurrenceIndex,
                intervalMonths: intervalMonths,
                calendar: calendar
            )
        }

        guard occurrence < monthEndExclusive, isBeforeOrOnEndDate(occurrence) else {
            return []
        }

        return [occurrence]
    }

    private func monthlyOccurrence(
        at index: Int,
        intervalMonths: Int,
        calendar: Calendar
    ) -> Date {
        guard
            let anchorMonthStart = calendar.dateInterval(of: .month, for: anchorDate)?.start,
            let targetMonthStart = calendar.date(
                byAdding: .month,
                value: index * intervalMonths,
                to: anchorMonthStart
            ),
            let validDays = calendar.range(of: .day, in: .month, for: targetMonthStart)
        else {
            preconditionFailure("The supplied calendar could not calculate a monthly occurrence.")
        }

        let anchorComponents = calendar.dateComponents(
            [.hour, .minute, .second, .nanosecond, .day],
            from: anchorDate
        )
        let targetComponents = calendar.dateComponents([.era, .year, .month], from: targetMonthStart)

        var occurrenceComponents = DateComponents()
        occurrenceComponents.calendar = calendar
        occurrenceComponents.timeZone = calendar.timeZone
        occurrenceComponents.era = targetComponents.era
        occurrenceComponents.year = targetComponents.year
        occurrenceComponents.month = targetComponents.month
        occurrenceComponents.day = min(anchorComponents.day ?? 1, validDays.count)
        occurrenceComponents.hour = anchorComponents.hour
        occurrenceComponents.minute = anchorComponents.minute
        occurrenceComponents.second = anchorComponents.second
        occurrenceComponents.nanosecond = anchorComponents.nanosecond

        guard let occurrence = calendar.date(from: occurrenceComponents) else {
            preconditionFailure("The supplied calendar could not construct a monthly occurrence.")
        }

        return occurrence
    }

    private func adding(days: Int, to date: Date, calendar: Calendar) -> Date {
        guard let result = calendar.date(byAdding: .day, value: days, to: date) else {
            preconditionFailure("The supplied calendar could not calculate a day-based occurrence.")
        }

        return result
    }

    private func isBeforeOrOnEndDate(_ occurrence: Date) -> Bool {
        endDate.map({ occurrence <= $0 }) ?? true
    }
}
