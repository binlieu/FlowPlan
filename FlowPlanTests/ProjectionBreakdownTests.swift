import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func seededProjectionBreakdownSumsToProjectedBalance() throws {
    let harness = try ProjectionBreakdownTestHarness()
    let projection = harness.store.projection
    let subtotal = projection.breakdown
        .filter { $0.kind != .total }
        .map(\.amount)
        .reduce(Decimal.zero, +)

    #expect(subtotal == projection.projectedEndOfMonthBalance)
    #expect(projection.breakdown.last?.amount == projection.projectedEndOfMonthBalance)
}

@Test
@MainActor
func seededProjectionBreakdownHasStableRowIDsAndOrder() throws {
    let harness = try ProjectionBreakdownTestHarness()

    #expect(harness.store.projection.breakdown.map(\.id) == [
        "currentAvailable",
        "remainingIncome",
        "remainingBills",
        "remainingSpending",
        "remainingSavings",
        "projectedBalance"
    ])
}

@Test
@MainActor
func twelveHundredExpenseSimulationDoesNotPersistOrMutateProjection() throws {
    let harness = try ProjectionBreakdownTestHarness()
    let originalProjection = harness.store.projection
    let originalTransactionCount = try harness.context.fetchCount(
        FetchDescriptor<TransactionEntity>()
    )
    let purchase = TransactionSnapshot(
        id: UUID(),
        date: harness.date(day: 20),
        amount: 1_200,
        type: .expense,
        category: "What If",
        detail: "What-if purchase"
    )

    let result = harness.store.simulate(
        WhatIfScenario(additionalTransactions: [purchase])
    )

    #expect(result.impact == -1_200)
    #expect(harness.store.projection == originalProjection)
    #expect(
        try harness.context.fetchCount(FetchDescriptor<TransactionEntity>())
            == originalTransactionCount
    )
}

@Test
@MainActor
func addingTwelveHundredExpenseThenRefreshingMovesProjectionExactly() throws {
    let harness = try ProjectionBreakdownTestHarness()
    let originalBalance = harness.store.projection.projectedEndOfMonthBalance

    try harness.repository.addTransaction(
        TransactionEntity(
            date: harness.date(day: 20),
            amount: 1_200,
            type: .expense,
            category: "What If",
            detail: "What-if purchase"
        )
    )
    harness.store.refresh()

    #expect(harness.store.projection.projectedEndOfMonthBalance == originalBalance - 1_200)
}

@MainActor
private struct ProjectionBreakdownTestHarness {
    let container: ModelContainer
    let context: ModelContext
    let repository: FinanceRepository
    let store: ProjectionStore

    private let calendar: Calendar

    init() throws {
        let container = try PersistenceController.inMemory()
        let context = container.mainContext
        let calendar = Self.makeCalendar()
        let month = MonthKey(year: 2026, month: 8)
        let repository = FinanceRepository(context: context, calendar: calendar)
        let appState = AppState(
            selectedMonth: month,
            calendar: calendar,
            userDefaults: try Self.makeDefaults()
        )

        try SampleData.seed(into: context, calendar: calendar)

        self.container = container
        self.context = context
        self.repository = repository
        self.store = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: context
        )
        self.calendar = calendar
    }

    func date(day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .distantPast
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "FlowPlanTests.ProjectionBreakdown.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
