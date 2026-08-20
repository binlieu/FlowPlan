import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func refreshAfterUnbudgetedExpenseMovesProjectionByExactlyMinusSixHundred() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = projectionStoreTestCalendar
    let month = MonthKey(year: 2026, month: 8)
    let repository = FinanceRepository(context: context, calendar: calendar)
    let appState = AppState(
        selectedMonth: month,
        calendar: calendar,
        userDefaults: try projectionStoreTestDefaults()
    )

    try repository.setStartingBalance(2_000, for: month)
    let store = ProjectionStore(
        repository: repository,
        appState: appState,
        modelContext: context
    )
    let originalBalance = store.projection.projectedEndOfMonthBalance

    try repository.addTransaction(
        TransactionEntity(
            date: projectionStoreDate(day: 18, calendar: calendar),
            amount: 600,
            type: .expense,
            category: "Car Repair",
            detail: "Unexpected repair"
        )
    )
    store.refresh()

    #expect(store.projection.projectedEndOfMonthBalance == originalBalance - 600)
}

@Test
@MainActor
func simulateDoesNotPersistOrMutateStoredProjection() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = projectionStoreTestCalendar
    let month = MonthKey(year: 2026, month: 8)
    let repository = FinanceRepository(context: context, calendar: calendar)
    let appState = AppState(
        selectedMonth: month,
        calendar: calendar,
        userDefaults: try projectionStoreTestDefaults()
    )

    try repository.setStartingBalance(2_000, for: month)
    let store = ProjectionStore(
        repository: repository,
        appState: appState,
        modelContext: context
    )
    let storedProjection = store.projection
    let transactionCount = try context.fetchCount(FetchDescriptor<TransactionEntity>())
    let scenarioTransaction = TransactionSnapshot(
        id: UUID(),
        date: projectionStoreDate(day: 20, calendar: calendar),
        amount: 350,
        type: .expense,
        category: "Unexpected",
        detail: "What-if only"
    )

    let result = store.simulate(
        WhatIfScenario(additionalTransactions: [scenarioTransaction])
    )

    #expect(result.impact == -350)
    #expect(store.projection == storedProjection)
    #expect(try context.fetchCount(FetchDescriptor<TransactionEntity>()) == transactionCount)
}

private var projectionStoreTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func projectionStoreDate(day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = 2026
    components.month = 8
    components.day = day
    components.hour = 12
    return calendar.date(from: components) ?? .distantPast
}

private func projectionStoreTestDefaults() throws -> UserDefaults {
    let suiteName = "FlowPlanTests.ProjectionStore.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
