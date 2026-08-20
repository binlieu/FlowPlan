import Foundation
import Observation
import FlowPlanDomain

struct TransactionDaySection: Identifiable, Equatable {
    let day: Date
    let title: String
    let transactions: [TransactionSnapshot]
    let netTotal: Decimal

    var id: Date { day }
}

struct TransactionSettlementOccurrence: Identifiable, Hashable {
    enum Kind: Hashable {
        case income
        case bill
    }

    let kind: Kind
    let sourceID: UUID
    let name: String
    let amount: Decimal
    let category: String
    let occurrenceDate: Date

    var id: String {
        "\(kind)-\(sourceID.uuidString)-\(occurrenceDate.timeIntervalSinceReferenceDate)"
    }

    var transactionType: TransactionType {
        kind == .income ? .income : .expense
    }
}

@MainActor
struct TransactionSettlementOccurrenceProvider {
    let repository: FinanceRepository
    let calendar: Calendar

    init(repository: FinanceRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    func unsettledOccurrences(
        for type: TransactionType,
        in month: MonthKey
    ) -> [TransactionSettlementOccurrence] {
        let transactions = repository.transactions(in: month)

        let occurrences: [TransactionSettlementOccurrence]
        switch type {
        case .income:
            let settledCounts = settlementCounts(
                transactions
                    .filter { $0.type == .income }
                    .compactMap(\.settlesIncomeID)
            )
            occurrences = repository.incomeSources()
                .filter(\.isActive)
                .flatMap { source in
                    source.recurrence.occurrences(in: month, calendar: calendar)
                        .dropFirst(settledCounts[source.id, default: 0])
                        .map { occurrenceDate in
                            TransactionSettlementOccurrence(
                                kind: .income,
                                sourceID: source.id,
                                name: source.name,
                                amount: source.expectedAmount,
                                category: "Income",
                                occurrenceDate: occurrenceDate
                            )
                        }
                }
        case .expense:
            let settledCounts = settlementCounts(
                transactions
                    .filter { $0.type == .expense }
                    .compactMap(\.settlesBillID)
            )
            occurrences = repository.bills()
                .filter(\.isActive)
                .flatMap { bill in
                    bill.recurrence.occurrences(in: month, calendar: calendar)
                        .dropFirst(settledCounts[bill.id, default: 0])
                        .prefix(1)
                        .map { occurrenceDate in
                            TransactionSettlementOccurrence(
                                kind: .bill,
                                sourceID: bill.id,
                                name: bill.name,
                                amount: bill.amount,
                                category: bill.category,
                                occurrenceDate: occurrenceDate
                            )
                        }
                }
        case .savings, .transfer:
            occurrences = []
        }

        return occurrences.sorted { lhs, rhs in
            if lhs.occurrenceDate != rhs.occurrenceDate {
                return lhs.occurrenceDate < rhs.occurrenceDate
            }

            let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return lhs.sourceID.uuidString < rhs.sourceID.uuidString
        }
    }

    private func settlementCounts(_ sourceIDs: [UUID]) -> [UUID: Int] {
        Dictionary(grouping: sourceIDs, by: { $0 }).mapValues(\.count)
    }
}

@Observable
@MainActor
final class TransactionsViewModel {
    var filter = TransactionFilter() {
        didSet { rebuildSections() }
    }

    var searchText = "" {
        didSet { rebuildSections() }
    }

    private(set) var sections: [TransactionDaySection] = []
    private(set) var availableCategories: [String] = []

    var isNarrowingResults: Bool {
        filter.isActive || !trimmedSearchText.isEmpty
    }

    @ObservationIgnored private let repository: FinanceRepository
    @ObservationIgnored private let projectionStore: ProjectionStore
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var transactions: [TransactionSnapshot] = []

    init(
        repository: FinanceRepository,
        projectionStore: ProjectionStore,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.projectionStore = projectionStore
        self.calendar = calendar
        self.now = now
    }

    func load(month: MonthKey) {
        transactions = repository.transactions(in: month)
        availableCategories = categories(in: month)
        rebuildSections()
    }

    func addTransaction(
        date: Date,
        amount: Decimal,
        type: TransactionType,
        category: String,
        detail: String,
        note: String = "",
        account: String = "",
        settlement: TransactionSettlementOccurrence? = nil,
        in month: MonthKey
    ) throws {
        if let settlement {
            guard settlement.transactionType == type else {
                throw FinanceRepositoryError.settlementMustUseDedicatedMethod
            }

            switch settlement.kind {
            case .income:
                try repository.markIncomeReceived(
                    incomeID: settlement.sourceID,
                    occurrence: settlement.occurrenceDate,
                    amount: amount,
                    on: date
                )
            case .bill:
                try repository.markBillPaid(
                    billID: settlement.sourceID,
                    occurrence: settlement.occurrenceDate,
                    amount: amount,
                    on: date
                )
            }
        } else {
            try repository.addTransaction(
                TransactionEntity(
                    date: date,
                    amount: amount,
                    type: type,
                    category: category,
                    detail: detail,
                    note: note,
                    account: account
                )
            )
        }
        refreshAfterWrite(month: month)
    }

    func unsettledOccurrences(
        for type: TransactionType,
        in month: MonthKey
    ) -> [TransactionSettlementOccurrence] {
        TransactionSettlementOccurrenceProvider(
            repository: repository,
            calendar: calendar
        ).unsettledOccurrences(for: type, in: month)
    }

    func updateTransaction(
        _ transaction: TransactionSnapshot,
        date: Date,
        amount: Decimal,
        type: TransactionType,
        category: String,
        detail: String,
        note: String = "",
        account: String = "",
        in month: MonthKey
    ) throws {
        try repository.updateTransaction(
            TransactionEntity(
                id: transaction.id,
                date: date,
                amount: amount,
                type: type,
                category: category,
                detail: detail,
                note: note,
                account: account,
                settlesBillID: transaction.settlesBillID,
                settlesIncomeID: transaction.settlesIncomeID
            )
        )
        refreshAfterWrite(month: month)
    }

    func delete(_ transaction: TransactionSnapshot, in month: MonthKey) throws {
        try repository.deleteTransaction(id: transaction.id)
        refreshAfterWrite(month: month)
    }

    func toggleCategory(_ category: String) {
        var updatedFilter = filter
        updatedFilter.toggleCategory(category)
        filter = updatedFilter
    }

    func removeCategoryFilter(_ category: String) {
        var updatedFilter = filter
        updatedFilter.categories.remove(category)
        filter = updatedFilter
    }

    func clearFilters() {
        filter.clear()
    }

    private func refreshAfterWrite(month: MonthKey) {
        projectionStore.refresh()
        load(month: month)
    }

    private func categories(in month: MonthKey) -> [String] {
        var categories = Set(transactions.map(\.category).filter { !$0.isEmpty })
        categories.formUnion(
            repository.budgets(for: month).map(\.category).filter { !$0.isEmpty }
        )
        categories.formUnion(
            repository.bills().map(\.category).filter { !$0.isEmpty }
        )

        if !repository.incomeSources().isEmpty {
            categories.insert("Income")
        }

        return categories.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func rebuildSections() {
        let matchingTransactions = transactions.filter { transaction in
            filter.matches(transaction) && matchesSearch(transaction)
        }
        let grouped = Dictionary(grouping: matchingTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        sections = grouped.keys.sorted(by: >).map { day in
            let dayTransactions = grouped[day, default: []].sorted { lhs, rhs in
                lhs.date > rhs.date
            }
            let netTotal = dayTransactions.reduce(Decimal.zero) { total, transaction in
                total + transaction.type.netAmount(for: transaction.amount)
            }

            return TransactionDaySection(
                day: day,
                title: sectionTitle(for: day),
                transactions: dayTransactions,
                netTotal: netTotal
            )
        }
    }

    private func matchesSearch(_ transaction: TransactionSnapshot) -> Bool {
        guard !trimmedSearchText.isEmpty else {
            return true
        }

        return transaction.detail.localizedCaseInsensitiveContains(trimmedSearchText)
            || transaction.category.localizedCaseInsensitiveContains(trimmedSearchText)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionTitle(for day: Date) -> String {
        let today = calendar.startOfDay(for: now())
        if day == today {
            return "Today"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           day == yesterday {
            return "Yesterday"
        }

        return day.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day()
                .locale(calendar.locale ?? .current)
        )
    }
}
