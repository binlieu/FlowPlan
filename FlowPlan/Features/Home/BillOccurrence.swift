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

enum HomePaymentOccurrence: Identifiable, Hashable {
    case bill(BillOccurrence)
    case debt(DebtOccurrence)

    var id: String {
        switch self {
        case .bill(let occurrence):
            return "bill-\(occurrence.id)"
        case .debt(let occurrence):
            return "debt-\(occurrence.debtID.uuidString)"
                + "-\(occurrence.date.timeIntervalSinceReferenceDate)"
        }
    }

    var name: String {
        switch self {
        case .bill(let occurrence):
            return occurrence.bill.name
        case .debt(let occurrence):
            return occurrence.name
        }
    }

    var date: Date {
        switch self {
        case .bill(let occurrence):
            return occurrence.date
        case .debt(let occurrence):
            return occurrence.date
        }
    }

    var amount: Decimal {
        switch self {
        case .bill(let occurrence):
            return occurrence.bill.amount
        case .debt(let occurrence):
            return occurrence.amount
        }
    }

    var monogram: String {
        switch self {
        case .bill(let occurrence):
            return occurrence.monogram
        case .debt:
            let letters = name.filter(\.isLetter)
            let source = letters.isEmpty ? name : letters
            return String(source.prefix(2)).uppercased()
        }
    }

    var billOccurrence: BillOccurrence? {
        guard case .bill(let occurrence) = self else {
            return nil
        }
        return occurrence
    }

    var debtOccurrence: DebtOccurrence? {
        guard case .debt(let occurrence) = self else {
            return nil
        }
        return occurrence
    }

    var isDebt: Bool {
        debtOccurrence != nil
    }

    var isPaidThroughBills: Bool {
        debtOccurrence?.isPaidThroughBills ?? false
    }

    func isAutoPay(autoPayDebtIDs: Set<UUID>) -> Bool {
        switch self {
        case .bill(let occurrence):
            return occurrence.bill.isAutoPay
        case .debt(let occurrence):
            return autoPayDebtIDs.contains(occurrence.debtID)
        }
    }

    func dismissalID(calendar: Calendar) -> String {
        switch self {
        case .bill(let occurrence):
            return occurrence.dismissalID(calendar: calendar)
        case .debt(let occurrence):
            let components = calendar.dateComponents(
                [.year, .month, .day],
                from: occurrence.date
            )
            let dateComponents = [components.year, components.month, components.day]
                .map { String($0 ?? 0) }
                .joined(separator: "-")
            return "debt-\(occurrence.debtID.uuidString)-\(dateComponents)"
        }
    }

    func status(
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> BillOccurrenceStatus {
        if calendar.startOfDay(for: date) < calendar.startOfDay(for: referenceDate) {
            return .overdue
        }

        switch self {
        case .bill(let occurrence):
            return BillOccurrenceStatus.status(
                for: occurrence.bill,
                occurrenceDate: occurrence.date,
                relativeTo: referenceDate,
                calendar: calendar
            )
        case .debt:
            return .upcoming
        }
    }

    static func sorted(
        _ occurrences: [HomePaymentOccurrence],
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [HomePaymentOccurrence] {
        occurrences.sorted { lhs, rhs in
            let lhsIsOverdue = lhs.status(
                relativeTo: referenceDate,
                calendar: calendar
            ) == .overdue
            let rhsIsOverdue = rhs.status(
                relativeTo: referenceDate,
                calendar: calendar
            ) == .overdue

            if lhsIsOverdue != rhsIsOverdue {
                return lhsIsOverdue
            }
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.id < rhs.id
        }
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
        userDefaults: UserDefaults,
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

    func undismissedOccurrences(
        in occurrences: [HomePaymentOccurrence],
        calendar: Calendar
    ) -> [HomePaymentOccurrence] {
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

    func dismiss(_ occurrences: [HomePaymentOccurrence], calendar: Calendar) {
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

    private func signature(
        for occurrences: [HomePaymentOccurrence],
        calendar: Calendar
    ) -> String {
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
        "The payment could not be marked as paid. Please try again."
    }
}

@MainActor
enum HomePaymentSettlementAction {
    @discardableResult
    static func markAsPaid(
        _ occurrence: HomePaymentOccurrence,
        repository: FinanceRepository,
        projectionStore: ProjectionStore
    ) -> BillSettlementError? {
        do {
            switch occurrence {
            case .bill(let billOccurrence):
                try repository.markBillPaid(
                    billID: billOccurrence.bill.id,
                    occurrence: billOccurrence.date,
                    amount: billOccurrence.bill.amount,
                    on: billOccurrence.date
                )
            case .debt(let debtOccurrence):
                try repository.markDebtPaymentMade(
                    debtID: debtOccurrence.debtID,
                    amount: debtOccurrence.amount,
                    on: debtOccurrence.date
                )
            }

            projectionStore.refresh()
            return nil
        } catch {
            return .unableToRecord
        }
    }
}

@MainActor
enum OverdueAutopaySettlementAction {
    static func overdueAutopayOccurrences(
        from occurrences: [HomePaymentOccurrence],
        autoPayDebtIDs: Set<UUID>,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [HomePaymentOccurrence] {
        HomePaymentOccurrence.sorted(
            occurrences.filter { occurrence in
                occurrence.isAutoPay(autoPayDebtIDs: autoPayDebtIDs)
                    && !occurrence.isPaidThroughBills
                    && occurrence.status(
                        relativeTo: referenceDate,
                        calendar: calendar
                    ) == .overdue
            },
            relativeTo: referenceDate,
            calendar: calendar
        )
    }

    static func overdueNonAutopayOccurrences(
        from occurrences: [HomePaymentOccurrence],
        autoPayDebtIDs: Set<UUID>,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [HomePaymentOccurrence] {
        HomePaymentOccurrence.sorted(
            occurrences.filter { occurrence in
                !occurrence.isAutoPay(autoPayDebtIDs: autoPayDebtIDs)
                    && !occurrence.isPaidThroughBills
                    && occurrence.status(
                        relativeTo: referenceDate,
                        calendar: calendar
                    ) == .overdue
            },
            relativeTo: referenceDate,
            calendar: calendar
        )
    }

    @discardableResult
    static func markAllAsPaid(
        _ occurrences: [HomePaymentOccurrence],
        repository: FinanceRepository,
        projectionStore: ProjectionStore
    ) -> BillSettlementError? {
        guard !occurrences.isEmpty else {
            return nil
        }

        defer { projectionStore.refresh() }

        var settlementError: BillSettlementError?
        for occurrence in occurrences {
            do {
                switch occurrence {
                case .bill(let billOccurrence):
                    try repository.markBillPaid(
                        billID: billOccurrence.bill.id,
                        occurrence: billOccurrence.date,
                        amount: billOccurrence.bill.amount,
                        on: billOccurrence.date
                    )
                case .debt(let debtOccurrence):
                    try repository.markDebtPaymentMade(
                        debtID: debtOccurrence.debtID,
                        amount: debtOccurrence.amount,
                        on: debtOccurrence.date
                    )
                }
            } catch {
                settlementError = .unableToRecord
            }
        }

        return settlementError
    }

    @discardableResult
    static func markAllAsPaid(
        from occurrences: [HomePaymentOccurrence],
        autoPayDebtIDs: Set<UUID>,
        relativeTo referenceDate: Date,
        repository: FinanceRepository,
        projectionStore: ProjectionStore,
        calendar: Calendar
    ) -> BillSettlementError? {
        let overdueAutopayOccurrences = overdueAutopayOccurrences(
            from: occurrences,
            autoPayDebtIDs: autoPayDebtIDs,
            relativeTo: referenceDate,
            calendar: calendar
        )

        return markAllAsPaid(
            overdueAutopayOccurrences,
            repository: repository,
            projectionStore: projectionStore
        )
    }

    @discardableResult
    static func markAllAsPaid(
        from occurrences: [BillOccurrence],
        relativeTo referenceDate: Date,
        repository: FinanceRepository,
        projectionStore: ProjectionStore,
        calendar: Calendar
    ) -> BillSettlementError? {
        markAllAsPaid(
            from: occurrences.map(HomePaymentOccurrence.bill),
            autoPayDebtIDs: [],
            relativeTo: referenceDate,
            repository: repository,
            projectionStore: projectionStore,
            calendar: calendar
        )
    }
}
