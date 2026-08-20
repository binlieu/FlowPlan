import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test func greetingUsesMorningAfternoonAndEveningPeriods() {
    let calendar = presentationTestCalendar

    #expect(
        HomeView.greeting(
            name: "Taylor",
            at: presentationTestDate(hour: 9, calendar: calendar),
            calendar: calendar
        ) == "Good morning, Taylor"
    )
    #expect(
        HomeView.greeting(
            name: "Taylor",
            at: presentationTestDate(hour: 14, calendar: calendar),
            calendar: calendar
        ) == "Good afternoon, Taylor"
    )
    #expect(
        HomeView.greeting(
            name: "Taylor",
            at: presentationTestDate(hour: 21, calendar: calendar),
            calendar: calendar
        ) == "Good evening, Taylor"
    )
}

@Test func greetingWithEmptyNameHasNoTrailingComma() {
    let calendar = presentationTestCalendar
    let greeting = HomeView.greeting(
        name: "  \n",
        at: presentationTestDate(hour: 9, calendar: calendar),
        calendar: calendar
    )

    #expect(greeting == "Good morning")
}

@Test
@MainActor
func explicitZeroStartingBalanceCountsAsEntered() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = presentationTestCalendar
    let month = MonthKey(year: 2026, month: 8)
    let repository = FinanceRepository(context: context, calendar: calendar)
    let appState = AppState(
        selectedMonth: month,
        calendar: calendar,
        userDefaults: try presentationTestDefaults()
    )

    try repository.setStartingBalance(.zero, for: month)
    let store = ProjectionStore(
        repository: repository,
        appState: appState,
        modelContext: context
    )

    #expect(store.projection.startingBalance == .zero)
    #expect(store.hasStartingBalance)
    #expect(store.completeness.hasStartingBalance)
    #expect(!store.completeness.hasNoPlanningInputs)
}

@Test
@MainActor
func projectionStoreCachesTransactionsAndStructuredInsights() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = presentationTestCalendar
    let month = MonthKey(year: 2026, month: 8)
    let repository = FinanceRepository(context: context, calendar: calendar)
    let appState = AppState(
        selectedMonth: month,
        calendar: calendar,
        userDefaults: try presentationTestDefaults()
    )

    try repository.addTransaction(
        TransactionEntity(
            date: presentationTestDate(month: 8, day: 10, hour: 12, calendar: calendar),
            amount: 120,
            type: .expense,
            category: "Groceries",
            detail: "Market"
        )
    )
    try repository.addTransaction(
        TransactionEntity(
            date: presentationTestDate(month: 7, day: 10, hour: 12, calendar: calendar),
            amount: 100,
            type: .expense,
            category: "Groceries",
            detail: "Market"
        )
    )

    let store = ProjectionStore(
        repository: repository,
        appState: appState,
        modelContext: context
    )

    #expect(store.currentTransactions.count == 1)
    #expect(store.previousTransactions.count == 1)
    #expect(
        store.insights.first { $0.id == "spending-groceries" }?.kind
            == .spending(category: "Groceries", percentageChange: 20)
    )
}

@Test func savingsSliderTargetClampsBeforeIntegerConversion() {
    #expect(SavingsGoalSection.decimalTarget(from: 124.6) == 125)
    #expect(SavingsGoalSection.decimalTarget(from: -50) == .zero)
    #expect(SavingsGoalSection.decimalTarget(from: .infinity) == Decimal(Int.max))
    #expect(SavingsGoalSection.decimalTarget(from: Double(Int.max)) == Decimal(Int.max))
}

private var presentationTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func presentationTestDate(
    month: Int = 8,
    day: Int = 19,
    hour: Int,
    calendar: Calendar
) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = 2026
    components.month = month
    components.day = day
    components.hour = hour
    return calendar.date(from: components) ?? .distantPast
}

private func presentationTestDefaults() throws -> UserDefaults {
    let suiteName = "FlowPlanTests.QAPresentation.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
