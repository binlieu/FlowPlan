import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func raisingSalaryRaisesPlannedBalanceByExactlyTwoHundredFifty() throws {
    let environment = try PlanEditingEnvironment()
    let salaryID = UUID()

    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            id: salaryID,
            name: "Salary",
            expectedAmount: 6_500,
            frequency: .monthly,
            anchorDate: environment.date(day: 5)
        )
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection.plannedEndOfMonthBalance

    try environment.repository.updateIncomeSource(
        IncomeSourceEntity(
            id: salaryID,
            name: "Salary",
            expectedAmount: 6_750,
            frequency: .monthly,
            anchorDate: environment.date(day: 5)
        )
    )
    environment.projectionStore.refresh()

    #expect(environment.projectionStore.projection.plannedEndOfMonthBalance == before + 250)
}

@Test
@MainActor
func committingSavingsSliderTargetMovesPlannedBalanceAndCardTotalBySameAmount() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 4_000)
    let goalID = UUID()
    let originalTarget: Decimal = 1_000
    let updatedTarget: Decimal = 1_500

    try environment.repository.addSavingsGoal(
        SavingsGoalEntity(
            id: goalID,
            name: "Emergency Fund",
            targetAmount: 20_000,
            monthlyTarget: originalTarget
        )
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection

    // This is the persistence and refresh path used when the savings slider commits.
    try environment.repository.updateSavingsGoal(
        SavingsGoalEntity(
            id: goalID,
            name: "Emergency Fund",
            targetAmount: 20_000,
            monthlyTarget: updatedTarget
        )
    )
    environment.projectionStore.refresh()
    let after = environment.projectionStore.projection
    let targetIncrease = updatedTarget - originalTarget

    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance - targetIncrease)
    #expect(after.plannedEndOfMonthBalance == before.plannedEndOfMonthBalance - targetIncrease)
    #expect(MonthlyProjectionCard.total(for: after) == MonthlyProjectionCard.total(for: before) - targetIncrease)
    expectProjectionCardReconciles(after)
}

@Test
@MainActor
func addingBillLowersProjectionForEveryOccurrenceInMonth() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 2_000)
    let before = environment.projectionStore.projection.projectedEndOfMonthBalance

    try environment.repository.addBill(
        RecurringBillEntity(
            name: "Housekeeping",
            amount: 100,
            amountType: .fixed,
            category: "Home",
            frequency: .biweekly,
            anchorDate: environment.date(day: 7)
        )
    )
    environment.projectionStore.refresh()

    #expect(environment.projectionStore.projection.plannedBillsTotal == 200)
    #expect(environment.projectionStore.projection.projectedEndOfMonthBalance == before - 200)
}

@Test
@MainActor
func deactivatingBillRemovesItFromRemainingBills() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 2_000)
    let billID = UUID()
    let anchorDate = environment.date(day: 12)

    try environment.repository.addBill(
        RecurringBillEntity(
            id: billID,
            name: "Internet",
            amount: 90,
            amountType: .fixed,
            category: "Utilities",
            frequency: .monthly,
            anchorDate: anchorDate
        )
    )
    environment.projectionStore.refresh()
    #expect(environment.projectionStore.projection.remainingBills == 90)

    try environment.repository.updateBill(
        RecurringBillEntity(
            id: billID,
            name: "Internet",
            amount: 90,
            amountType: .fixed,
            category: "Utilities",
            frequency: .monthly,
            anchorDate: anchorDate,
            isActive: false
        )
    )
    environment.projectionStore.refresh()

    #expect(environment.projectionStore.projection.remainingBills == .zero)
}

@Test
@MainActor
func addingBudgetCategoryLowersProjectionByItsUnspentRemainder() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 2_000)

    try environment.repository.addTransaction(
        TransactionEntity(
            date: environment.date(day: 10),
            amount: 200,
            type: .expense,
            category: "Groceries",
            detail: "Market"
        )
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection.projectedEndOfMonthBalance

    try environment.repository.addBudget(
        BudgetEntity(category: "Groceries", monthlyLimit: 500)
    )
    environment.projectionStore.refresh()

    #expect(environment.projectionStore.projection.remainingVariableSpending == 300)
    #expect(environment.projectionStore.projection.projectedEndOfMonthBalance == before - 300)
}

@Test
@MainActor
func editingAlreadyOverspentBudgetDoesNotMoveProjection() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 2_000)
    let budgetID = UUID()

    try environment.repository.addTransaction(
        TransactionEntity(
            date: environment.date(day: 10),
            amount: 600,
            type: .expense,
            category: "Dining",
            detail: "Meals"
        )
    )
    try environment.repository.addBudget(
        BudgetEntity(id: budgetID, category: "Dining", monthlyLimit: 500)
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection.projectedEndOfMonthBalance

    try environment.repository.updateBudget(
        BudgetEntity(id: budgetID, category: "Dining", monthlyLimit: 550)
    )
    environment.projectionStore.refresh()

    #expect(environment.projectionStore.projection.remainingVariableSpending == .zero)
    #expect(environment.projectionStore.projection.projectedEndOfMonthBalance == before)
}

@Test
@MainActor
func projectionCardReconcilesWithZeroStartingBalance() throws {
    let environment = try PlanEditingEnvironment()
    try addCompletePlan(to: environment)
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let rows = MonthlyProjectionCard.rows(for: projection)

    #expect(rows.first == ProjectionCardRow(
        id: "startingBalance",
        label: "Starting balance",
        amount: .zero,
        direction: .addition
    ))
    expectProjectionCardReconciles(projection)
}

@Test
@MainActor
func projectionCardReconcilesWithNonZeroStartingBalance() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 1_200)
    try addCompletePlan(to: environment)
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let rows = MonthlyProjectionCard.rows(for: projection)

    #expect(rows.map(\.label) == [
        "Starting balance",
        "Expected income",
        "Recurring bills",
        "Debt payments",
        "Planned spending",
        "Savings goal"
    ])
    #expect(rows.map(\.amount) == [
        projection.startingBalance,
        projection.plannedIncomeTotal,
        projection.plannedBillsTotal,
        projection.debtPaymentsDue,
        projection.plannedSpendingTotal,
        projection.savingsTarget
    ])
    expectProjectionCardReconciles(projection)
}

@Test
@MainActor
func projectionCardReconcilesForMonthWithNoPlan() throws {
    let environment = try PlanEditingEnvironment()
    let projection = environment.projectionStore.projection
    let rows = MonthlyProjectionCard.rows(for: projection)

    #expect(rows.count == 6)
    #expect(rows.allSatisfy { $0.amount == .zero })
    expectProjectionCardReconciles(projection)
}

@MainActor
private func addCompletePlan(to environment: PlanEditingEnvironment) throws {
    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            name: "Salary",
            expectedAmount: 6_500,
            frequency: .monthly,
            anchorDate: environment.date(day: 5)
        )
    )
    try environment.repository.addBill(
        RecurringBillEntity(
            name: "Rent",
            amount: 1_850,
            amountType: .fixed,
            category: "Housing",
            frequency: .monthly,
            anchorDate: environment.date(day: 1)
        )
    )
    try environment.repository.addBudget(
        BudgetEntity(category: "Groceries", monthlyLimit: 800)
    )
    try environment.repository.addSavingsGoal(
        SavingsGoalEntity(
            name: "Emergency Fund",
            targetAmount: 20_000,
            monthlyTarget: 1_000
        )
    )
}

private func expectProjectionCardReconciles(
    _ projection: MonthlyProjection,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let rows = MonthlyProjectionCard.rows(for: projection)
    let displayedRowsTotal = rows.reduce(Decimal.zero) { $0 + $1.displayedAmount }
    let displayedCardTotal = MonthlyProjectionCard.total(for: projection)

    #expect(displayedRowsTotal == displayedCardTotal, sourceLocation: sourceLocation)
}

@MainActor
private struct PlanEditingEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let calendar: Calendar
    let container: ModelContainer
    let repository: FinanceRepository
    let projectionStore: ProjectionStore

    init(startingBalance: Decimal = .zero) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar

        let container = try PersistenceController.inMemory()
        self.container = container
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
            now: { Self.date(day: 20, calendar: calendar) }
        )
        let defaults = try Self.makeDefaults()
        let appState = AppState(
            selectedMonth: month,
            calendar: calendar,
            userDefaults: defaults,
            now: { Self.date(day: 20, calendar: calendar) }
        )

        if startingBalance != .zero {
            try repository.setStartingBalance(startingBalance, for: month)
        }

        self.repository = repository
        projectionStore = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: container.mainContext
        )
    }

    func date(day: Int) -> Date {
        Self.date(day: day, calendar: calendar)
    }

    private static func date(day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .distantPast
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "FlowPlanTests.PlanEditing.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
