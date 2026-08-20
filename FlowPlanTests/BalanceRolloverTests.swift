import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func explicitStartingBalanceWinsOverPreviousMonthClosingCash() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let previousMonth = MonthKey(year: 2026, month: 7)
    let month = previousMonth.next

    try environment.repository.setStartingBalance(1_000, for: previousMonth)
    try environment.addTransaction(amount: 500, type: .income, in: previousMonth)
    try environment.repository.setStartingBalance(275, for: month)

    let resolution = environment.repository.startingBalanceResolution(for: month)

    #expect(resolution.amount == 275)
    #expect(resolution.source == .explicit)
}

@Test
@MainActor
func unsetMonthOpensWithPreviousMonthsActualClosingCash() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let previousMonth = MonthKey(year: 2026, month: 7)
    let month = previousMonth.next

    try environment.repository.setStartingBalance(1_000, for: previousMonth)
    try environment.addTransaction(amount: 500, type: .income, in: previousMonth)
    try environment.addTransaction(amount: 125, type: .expense, in: previousMonth)

    let resolution = environment.repository.startingBalanceResolution(for: month)
    let storedMonths = try environment.context.fetch(FetchDescriptor<MonthSettingsEntity>())
        .map { $0.toDomain().month }

    #expect(resolution.amount == 1_375)
    #expect(resolution.source == .rolledOver(from: previousMonth))
    #expect(!storedMonths.contains(month))
}

@Test
@MainActor
func threeMonthRolloverChainUpdatesWhenFirstExplicitBalanceChanges() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let firstMonth = MonthKey(year: 2026, month: 6)
    let secondMonth = firstMonth.next
    let thirdMonth = secondMonth.next

    try environment.repository.setStartingBalance(1_000, for: firstMonth)
    try environment.addTransaction(amount: 100, type: .expense, in: firstMonth)
    try environment.addTransaction(amount: 300, type: .income, in: secondMonth)

    #expect(environment.repository.startingBalance(for: thirdMonth) == 1_200)

    try environment.repository.setStartingBalance(2_000, for: firstMonth)

    #expect(environment.repository.startingBalance(for: thirdMonth) == 2_200)
}

@Test
@MainActor
func completedSavingsReduceTheBalanceCarriedIntoTheNextMonth() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let previousMonth = MonthKey(year: 2026, month: 7)

    try environment.repository.setStartingBalance(1_000, for: previousMonth)
    try environment.addTransaction(amount: 250, type: .savings, in: previousMonth)

    #expect(environment.repository.startingBalance(for: previousMonth.next) == 750)
}

@Test
@MainActor
func expectedButUnreceivedIncomeDoesNotCarryForward() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let previousMonth = MonthKey(year: 2026, month: 7)
    let expectedPayDate = environment.date(in: previousMonth, day: 5)

    try environment.repository.setStartingBalance(1_000, for: previousMonth)
    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            name: "Expected salary",
            expectedAmount: 500,
            frequency: .monthly,
            anchorDate: expectedPayDate
        )
    )

    let previousProjection = MonthlyProjectionEngine().project(
        environment.repository.projectionInput(
            for: previousMonth,
            referenceDate: environment.date(in: previousMonth, day: 28),
            configuration: .default
        )
    )

    #expect(previousProjection.projectedEndOfMonthBalance == 1_500)
    #expect(previousProjection.currentAvailableBalance == 1_000)
    #expect(environment.repository.startingBalance(for: previousMonth.next) == 1_000)
}

@Test
@MainActor
func rolloverWalkStopsAfterTwentyFourMonthsWithoutAnExplicitBalance() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let targetMonth = MonthKey(year: 2026, month: 8)

    try environment.repository.setStartingBalance(
        900,
        for: targetMonth.adding(months: -25)
    )

    let resolution = environment.repository.startingBalanceResolution(for: targetMonth)

    #expect(resolution.amount == .zero)
    #expect(resolution.source == .rolledOver(from: targetMonth.previous))
}

@Test
@MainActor
func disabledCarryBalanceForwardRestoresExplicitOrZeroBehavior() throws {
    let environment = try BalanceRolloverTestEnvironment(carryBalanceForward: false)
    let previousMonth = MonthKey(year: 2026, month: 7)
    let month = previousMonth.next

    try environment.repository.setStartingBalance(1_000, for: previousMonth)

    let resolution = environment.repository.startingBalanceResolution(for: month)

    #expect(resolution.amount == .zero)
    #expect(resolution.source == .unset)
}

@Test
@MainActor
func resolvingLongRolloverChainUsesBoundedFetches() throws {
    var fetchCount = 0
    let environment = try BalanceRolloverTestEnvironment(
        shouldFailReads: {
            fetchCount += 1
            return false
        }
    )
    let targetMonth = MonthKey(year: 2026, month: 8)

    try environment.repository.setStartingBalance(
        1_000,
        for: targetMonth.adding(months: -24)
    )
    fetchCount = 0

    #expect(environment.repository.startingBalance(for: targetMonth) == 1_000)
    #expect(fetchCount == 2)
}

@Test
@MainActor
func deletingExplicitStartingBalanceResumesRollover() throws {
    let environment = try BalanceRolloverTestEnvironment()
    let previousMonth = MonthKey(year: 2026, month: 7)
    let month = previousMonth.next

    try environment.repository.setStartingBalance(600, for: previousMonth)
    try environment.repository.setStartingBalance(900, for: month)
    try environment.repository.deleteStartingBalance(for: month)

    let resolution = environment.repository.startingBalanceResolution(for: month)

    #expect(resolution.amount == 600)
    #expect(resolution.source == .rolledOver(from: previousMonth))
}

@Test
@MainActor
func carryBalanceForwardPreferenceDefaultsToTrueAndPersists() throws {
    let suiteName = "FlowPlanTests.BalanceRollover.AppState.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let appState = AppState(userDefaults: defaults)

    #expect(appState.carryBalanceForward)

    appState.carryBalanceForward = false

    #expect(defaults.object(forKey: "carryBalanceForward") as? Bool == false)
}

@MainActor
private struct BalanceRolloverTestEnvironment {
    let calendar: Calendar
    let container: ModelContainer
    let context: ModelContext
    let repository: FinanceRepository

    init(
        carryBalanceForward: Bool? = nil,
        shouldFailReads: @escaping () -> Bool = { false }
    ) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar

        let container = try PersistenceController.inMemory()
        self.container = container
        context = container.mainContext

        let suiteName = "FlowPlanTests.BalanceRollover.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        if let carryBalanceForward {
            defaults.set(carryBalanceForward, forKey: "carryBalanceForward")
        }

        repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
            userDefaults: defaults,
            shouldFailReads: shouldFailReads
        )
    }

    func addTransaction(
        amount: Decimal,
        type: TransactionType,
        in month: MonthKey
    ) throws {
        try repository.addTransaction(
            TransactionEntity(
                date: date(in: month, day: 10),
                amount: amount,
                type: type,
                category: "Test",
                detail: "Rollover test"
            )
        )
    }

    func date(in month: MonthKey, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = month.year
        components.month = month.month
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .distantPast
    }
}
