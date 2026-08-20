import Foundation
import FlowPlanDomain

enum BillOccurrenceStatus: String, Equatable {
    case overdue = "OVERDUE"
    case autoPay = "AUTO PAY"
    case estimated = "ESTIMATED"
    case upcoming = "UPCOMING"

    static func status(
        for bill: PlannedBill,
        occurrenceDate: Date,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        if calendar.startOfDay(for: occurrenceDate) < calendar.startOfDay(for: referenceDate) {
            return .overdue
        }
        if bill.isAutoPay {
            return .autoPay
        }
        if bill.amountType == .estimated {
            return .estimated
        }
        return .upcoming
    }
}

struct BillOccurrence: Identifiable, Hashable {
    let bill: PlannedBill
    let date: Date

    var id: String {
        "\(bill.id.uuidString)-\(date.timeIntervalSinceReferenceDate)"
    }

    var monogram: String {
        let letters = bill.name.filter(\.isLetter)
        let source = letters.isEmpty ? bill.name : letters
        return String(source.prefix(2)).uppercased()
    }

    func dismissalID(calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateComponents = [components.year, components.month, components.day]
            .map { String($0 ?? 0) }
            .joined(separator: "-")
        return "\(bill.id.uuidString)-\(dateComponents)"
    }
}

@MainActor
struct BillOccurrenceProvider {
    let repository: FinanceRepository
    let calendar: Calendar

    func unsettledOccurrences(
        in month: MonthKey,
        relativeTo referenceDate: Date
    ) -> [BillOccurrence] {
        let settledBillIDs = repository.transactions(in: month)
            .compactMap { transaction -> UUID? in
                guard transaction.type == .expense, let billID = transaction.settlesBillID else {
                    return nil
                }
                return billID
            }
        let settledCounts = Dictionary(grouping: settledBillIDs, by: { $0 }).mapValues(\.count)
        let occurrences = repository.bills()
            .filter(\.isActive)
            .flatMap { bill -> [BillOccurrence] in
                let dates = bill.recurrence.occurrences(in: month, calendar: calendar)
                let settledCount = settledCounts[bill.id, default: 0]
                return dates.dropFirst(settledCount).map {
                    BillOccurrence(bill: bill, date: $0)
                }
            }

        return Self.sortedOccurrences(
            occurrences,
            relativeTo: referenceDate,
            calendar: calendar
        )
    }

    static func sortedOccurrences(
        _ occurrences: [BillOccurrence],
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [BillOccurrence] {
        occurrences.sorted { lhs, rhs in
            let lhsIsOverdue = BillOccurrenceStatus.status(
                for: lhs.bill,
                occurrenceDate: lhs.date,
                relativeTo: referenceDate,
                calendar: calendar
            ) == .overdue
            let rhsIsOverdue = BillOccurrenceStatus.status(
                for: rhs.bill,
                occurrenceDate: rhs.date,
                relativeTo: referenceDate,
                calendar: calendar
            ) == .overdue

            if lhsIsOverdue != rhsIsOverdue {
                return lhsIsOverdue
            }
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            let nameOrder = lhs.bill.name.localizedCaseInsensitiveCompare(rhs.bill.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.bill.id.uuidString < rhs.bill.id.uuidString
        }
    }
}

struct OverdueAutopayPromptDismissalStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "overdueAutopayPrompt.dismissedOccurrenceSets.v1"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func undismissedOccurrences(
        in occurrences: [BillOccurrence],
        calendar: Calendar
    ) -> [BillOccurrence] {
        let dismissedSets = Set(userDefaults.stringArray(forKey: key) ?? [])
        return dismissedSets.contains(signature(for: occurrences, calendar: calendar))
            ? []
            : occurrences
    }

    func dismiss(_ occurrences: [BillOccurrence], calendar: Calendar) {
        guard !occurrences.isEmpty else {
            return
        }

        var dismissedSets = Set(userDefaults.stringArray(forKey: key) ?? [])
        dismissedSets.insert(signature(for: occurrences, calendar: calendar))
        userDefaults.set(Array(dismissedSets).sorted(), forKey: key)
    }

    private func signature(for occurrences: [BillOccurrence], calendar: Calendar) -> String {
        occurrences
            .map { $0.dismissalID(calendar: calendar) }
            .sorted()
            .joined(separator: "|")
    }
}

enum BillSettlementError: String, Identifiable, Equatable {
    case unableToRecord

    var id: String { rawValue }

    var message: String {
        "The bill could not be marked as paid. Please try again."
    }
}

@MainActor
enum OverdueAutopaySettlementAction {
    @discardableResult
    static func markAllAsPaid(
        from occurrences: [BillOccurrence],
        relativeTo referenceDate: Date,
        repository: FinanceRepository,
        projectionStore: ProjectionStore,
        calendar: Calendar
    ) -> BillSettlementError? {
        let overdueAutopayOccurrences = BillOccurrenceProvider.sortedOccurrences(
            occurrences.filter { occurrence in
                occurrence.bill.isAutoPay
                    && BillOccurrenceStatus.status(
                        for: occurrence.bill,
                        occurrenceDate: occurrence.date,
                        relativeTo: referenceDate,
                        calendar: calendar
                    ) == .overdue
            },
            relativeTo: referenceDate,
            calendar: calendar
        )

        guard !overdueAutopayOccurrences.isEmpty else {
            return nil
        }

        defer { projectionStore.refresh() }

        var settlementError: BillSettlementError?
        for occurrence in overdueAutopayOccurrences {
            do {
                try repository.markBillPaid(
                    billID: occurrence.bill.id,
                    occurrence: occurrence.date,
                    amount: occurrence.bill.amount,
                    on: occurrence.date
                )
            } catch {
                settlementError = .unableToRecord
            }
        }

        return settlementError
    }
}
