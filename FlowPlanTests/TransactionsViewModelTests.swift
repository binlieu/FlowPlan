import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func transactionFilteringByTypeAndCategoryReturnsExpectedSubsets() throws {
    let environment = try TransactionsTestEnvironment()
    let incomeID = UUID()
    let groceryID = UUID()
    let diningID = UUID()

    try environment.repository.addTransaction(
        environment.transaction(
            id: incomeID,
            day: 3,
            amount: 1_000,
            type: .income,
            category: "Income",
            detail: "Paycheck"
        )
    )
    try environment.repository.addTransaction(
        environment.transaction(
            id: groceryID,
            day: 4,
            amount: 75,
            type: .expense,
            category: "Groceries",
            detail: "Market"
        )
    )
    try environment.repository.addTransaction(
        environment.transaction(
            id: diningID,
            day: 5,
            amount: 40,
            type: .expense,
            category: "Dining",
            detail: "Lunch"
        )
    )
    environment.viewModel.load(month: environment.month)

    environment.viewModel.filter = TransactionFilter(type: .expense)
    #expect(Set(environment.visibleTransactionIDs) == [groceryID, diningID])

    environment.viewModel.filter = TransactionFilter(categories: ["Groceries"])
    #expect(environment.visibleTransactionIDs == [groceryID])
}

@Test
@MainActor
func transactionSearchMatchesDescriptionAndCategoryCaseInsensitively() throws {
    let environment = try TransactionsTestEnvironment()
    let descriptionMatchID = UUID()
    let categoryMatchID = UUID()

    try environment.repository.addTransaction(
        environment.transaction(
            id: descriptionMatchID,
            day: 7,
            amount: 25,
            type: .expense,
            category: "Other",
            detail: "Neighborhood MARKET"
        )
    )
    try environment.repository.addTransaction(
        environment.transaction(
            id: categoryMatchID,
            day: 8,
            amount: 80,
            type: .expense,
            category: "Groceries",
            detail: "Weekly shop"
        )
    )
    environment.viewModel.load(month: environment.month)

    environment.viewModel.searchText = "market"
    #expect(environment.visibleTransactionIDs == [descriptionMatchID])

    environment.viewModel.searchText = "gRoCeRiEs"
    #expect(environment.visibleTransactionIDs == [categoryMatchID])
}

@Test
@MainActor
func transactionGroupingOrdersDaysNewestFirstAndCalculatesNetTotals() throws {
    let environment = try TransactionsTestEnvironment()

    try environment.repository.addTransaction(
        environment.transaction(
            day: 10,
            amount: 1_000,
            type: .income,
            category: "Income",
            detail: "Paycheck"
        )
    )
    try environment.repository.addTransaction(
        environment.transaction(
            day: 10,
            amount: 250,
            type: .expense,
            category: "Groceries",
            detail: "Market"
        )
    )
    try environment.repository.addTransaction(
        environment.transaction(
            day: 10,
            amount: 50,
            type: .savings,
            category: "Savings",
            detail: "Emergency fund"
        )
    )
    try environment.repository.addTransaction(
        environment.transaction(
            day: 12,
            amount: 30,
            type: .expense,
            category: "Dining",
            detail: "Lunch"
        )
    )
    environment.viewModel.load(month: environment.month)

    #expect(environment.viewModel.sections.count == 2)
    #expect(environment.viewModel.sections.map(\.day) == [
        environment.date(day: 12, hour: 0),
        environment.date(day: 10, hour: 0)
    ])
    #expect(environment.viewModel.sections.map(\.netTotal) == [-30, 700])
}

@Test
@MainActor
func deletingExpenseThroughViewModelRestoresItsAmountToProjection() throws {
    let environment = try TransactionsTestEnvironment(startingBalance: 2_000)
    let expenseID = UUID()

    try environment.repository.addTransaction(
        environment.transaction(
            id: expenseID,
            day: 14,
            amount: 125,
            type: .expense,
            category: "Unexpected",
            detail: "Repair"
        )
    )
    environment.projectionStore.refresh()
    environment.viewModel.load(month: environment.month)
    let beforeDelete = environment.projectionStore.projection.projectedEndOfMonthBalance
    let transaction = try #require(
        environment.viewModel.sections
            .flatMap(\.transactions)
            .first { $0.id == expenseID }
    )

    try environment.viewModel.delete(transaction, in: environment.month)

    #expect(
        environment.projectionStore.projection.projectedEndOfMonthBalance
            == beforeDelete + 125
    )
}

@Test
@MainActor
func addingSixHundredUnbudgetedExpenseThroughViewModelMovesProjectionExactlyMinusSixHundred() throws {
    let environment = try TransactionsTestEnvironment(startingBalance: 2_000)
    let originalBalance = environment.projectionStore.projection.projectedEndOfMonthBalance

    try environment.viewModel.addTransaction(
        date: environment.date(day: 18),
        amount: 600,
        type: .expense,
        category: "Car Repair",
        detail: "Unexpected repair",
        in: environment.month
    )

    #expect(
        environment.projectionStore.projection.projectedEndOfMonthBalance
            == originalBalance - 600
    )
}

@MainActor
private struct TransactionsTestEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let calendar: Calendar
    /// Retained deliberately. The repository holds this container's `mainContext`; if the
    /// container is only a local in `init` it deallocates on return and every later `save()`
    /// is a use-after-free that traps. That shows up as tests passing alone and crashing in a
    /// full run, which is the least obvious way for this bug to present.
    let container: ModelContainer
    let repository: FinanceRepository
    let projectionStore: ProjectionStore
    let viewModel: TransactionsViewModel

    init(startingBalance: Decimal = .zero) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar

        let container = try PersistenceController.inMemory()
        self.container = container
        let repository = FinanceRepository(context: container.mainContext, calendar: calendar)
        let defaults = try Self.makeDefaults()
        let appState = AppState(
            selectedMonth: month,
            calendar: calendar,
            userDefaults: defaults,
            now: { Self.date(day: 20, hour: 12, calendar: calendar) }
        )

        if startingBalance != .zero {
            try repository.setStartingBalance(startingBalance, for: month)
        }

        let projectionStore = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: container.mainContext
        )
        self.repository = repository
        self.projectionStore = projectionStore
        viewModel = TransactionsViewModel(
            repository: repository,
            projectionStore: projectionStore,
            calendar: calendar,
            now: { Self.date(day: 20, hour: 12, calendar: calendar) }
        )
    }

    var visibleTransactionIDs: [UUID] {
        viewModel.sections.flatMap(\.transactions).map(\.id)
    }

    func transaction(
        id: UUID = UUID(),
        day: Int,
        amount: Decimal,
        type: TransactionType,
        category: String,
        detail: String
    ) -> TransactionEntity {
        TransactionEntity(
            id: id,
            date: date(day: day),
            amount: amount,
            type: type,
            category: category,
            detail: detail
        )
    }

    func date(day: Int, hour: Int = 12) -> Date {
        Self.date(day: day, hour: hour, calendar: calendar)
    }

    private static func date(day: Int, hour: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? .distantPast
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "FlowPlanTests.TransactionsViewModel.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
