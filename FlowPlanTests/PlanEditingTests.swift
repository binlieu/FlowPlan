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
    #expect(environment.repository.bills().reduce(Decimal.zero) { $0 + $1.amount } == 100)
    #expect(
        MonthlyBillsSection.totalRowContent(
            plannedTotal: environment.projectionStore.projection.plannedBillsTotal
        ).amount == 200
    )
    #expect(environment.projectionStore.projection.projectedEndOfMonthBalance == before - 200)
}

@Test
@MainActor
func monthlyBillsTotalDisplaysProjectionTotalForSeveralBills() throws {
    let environment = try PlanEditingEnvironment()

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
    try environment.repository.addBill(
        RecurringBillEntity(
            name: "Utilities",
            amount: 542.98,
            amountType: .variable,
            category: "Utilities",
            frequency: .monthly,
            anchorDate: environment.date(day: 15)
        )
    )
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let totalRow = MonthlyBillsSection.totalRowContent(
        plannedTotal: projection.plannedBillsTotal
    )

    #expect(projection.plannedBillsTotal == 2_392.98)
    #expect(totalRow.amount == projection.plannedBillsTotal)
    #expect(totalRow.label == "TOTAL MONTHLY BILLS")
    #expect(
        MonthlyBillsSection.formattedTotal(totalRow.amount, currencyCode: "USD")
            == "-$2,392.98"
    )
}

@Test
@MainActor
func deactivatingBillLowersMonthlyBillsTotal() throws {
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
    let activeTotal = MonthlyBillsSection.totalRowContent(
        plannedTotal: environment.projectionStore.projection.plannedBillsTotal
    ).amount

    #expect(environment.projectionStore.projection.remainingBills == 90)
    #expect(activeTotal == 90)

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
    let inactiveTotal = MonthlyBillsSection.totalRowContent(
        plannedTotal: environment.projectionStore.projection.plannedBillsTotal
    ).amount

    #expect(environment.projectionStore.projection.remainingBills == .zero)
    #expect(environment.projectionStore.projection.plannedBillsTotal == .zero)
    #expect(inactiveTotal == .zero)
    #expect(inactiveTotal < activeTotal)
}

@Test
@MainActor
func monthlyBillsTotalRowShowsNegativeZeroWhenThereAreNoBills() throws {
    let environment = try PlanEditingEnvironment()
    let totalRow = MonthlyBillsSection.totalRowContent(
        plannedTotal: environment.projectionStore.projection.plannedBillsTotal
    )

    #expect(environment.repository.bills().isEmpty)
    #expect(totalRow.amount == .zero)
    #expect(MonthlyBillsSection.formattedTotal(totalRow.amount, currencyCode: "USD") == "-$0")
}

@Test
@MainActor
func monthlyBillsTotalMatchesProjectionCardRecurringBills() throws {
    let environment = try PlanEditingEnvironment()
    try addCompletePlan(to: environment)
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let planTotal = MonthlyBillsSection.totalRowContent(
        plannedTotal: PlanView.monthlyBillsTotal(for: projection)
    )
    let projectionCardTotal = try #require(
        MonthlyProjectionCard.rows(for: projection).first { $0.id == "plannedBills" }
    )

    #expect(planTotal.amount == projectionCardTotal.amount)
    #expect(projectionCardTotal.direction == .deduction)
}

@Test
@MainActor
func everyPlanSectionTotalMatchesItsProjectionFieldAndCardRow() throws {
    let environment = try PlanEditingEnvironment(startingBalance: 1_200)
    try addCompletePlan(to: environment)
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let planTotals: [(rowID: String, amount: Decimal, direction: ProjectionCardRow.Direction)] = [
        ("plannedIncome", projection.plannedIncomeTotal, .addition),
        ("plannedBills", PlanView.monthlyBillsTotal(for: projection), .deduction),
        ("debtPayments", projection.debtPaymentsDue, .deduction),
        (
            "plannedSpending",
            SpendingBudgetSection.totalRowContent(
                plannedTotal: PlanView.spendingBudgetTotal(for: projection)
            ).amount,
            .deduction
        ),
        (
            "savingsTarget",
            SavingsGoalSection.totalRowContent(
                plannedTotal: PlanView.savingsGoalTotal(for: projection)
            ).amount,
            .deduction
        )
    ]
    let projectionFields = [
        projection.plannedIncomeTotal,
        projection.plannedBillsTotal,
        projection.debtPaymentsDue,
        projection.plannedSpendingTotal,
        projection.savingsTarget
    ]
    let cardRows = MonthlyProjectionCard.rows(for: projection)

    #expect(planTotals.map { $0.amount } == projectionFields)

    for planTotal in planTotals {
        let cardRow = try #require(cardRows.first { $0.id == planTotal.rowID })
        #expect(planTotal.amount == cardRow.amount)
        #expect(planTotal.direction == cardRow.direction)
    }
}

@Test
@MainActor
func addingAndRemovingBudgetCategoryMovesSpendingTotal() throws {
    let environment = try PlanEditingEnvironment()
    let groceriesID = UUID()
    let diningID = UUID()

    try environment.repository.addBudget(
        BudgetEntity(id: groceriesID, category: "Groceries", monthlyLimit: 800)
    )
    environment.projectionStore.refresh()
    let firstTotal = PlanView.spendingBudgetTotal(
        for: environment.projectionStore.projection
    )

    try environment.repository.addBudget(
        BudgetEntity(id: diningID, category: "Dining", monthlyLimit: 1_250)
    )
    environment.projectionStore.refresh()
    let addedTotal = PlanView.spendingBudgetTotal(
        for: environment.projectionStore.projection
    )

    try environment.repository.deleteBudget(id: groceriesID)
    environment.projectionStore.refresh()
    let removedTotal = PlanView.spendingBudgetTotal(
        for: environment.projectionStore.projection
    )

    #expect(firstTotal == 800)
    #expect(addedTotal == 2_050)
    #expect(removedTotal == 1_250)
    #expect(
        SpendingBudgetSection.totalRowContent(plannedTotal: addedTotal)
            == SpendingBudgetSection.TotalRowContent(
                label: "TOTAL SPENDING BUDGET",
                amount: 2_050
            )
    )
}

@Test
@MainActor
func secondSavingsGoalIsIncludedInSavingsTotal() throws {
    let environment = try PlanEditingEnvironment()

    try environment.repository.addSavingsGoal(
        SavingsGoalEntity(
            name: "Emergency Fund",
            targetAmount: 20_000,
            monthlyTarget: 1_250
        )
    )
    try environment.repository.addSavingsGoal(
        SavingsGoalEntity(
            name: "Vacation",
            targetAmount: 8_000,
            monthlyTarget: 750
        )
    )
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let totalRow = SavingsGoalSection.totalRowContent(
        plannedTotal: PlanView.savingsGoalTotal(for: projection)
    )

    #expect(environment.repository.savingsPlans().count == 2)
    #expect(projection.savingsTarget == 2_000)
    #expect(totalRow.amount == projection.savingsTarget)
    #expect(totalRow.label == "TOTAL SAVINGS GOAL")
}

@Test
@MainActor
func emptySpendingAndSavingsSectionsStillProvideZeroTotalRows() throws {
    let environment = try PlanEditingEnvironment()
    let projection = environment.projectionStore.projection
    let spendingTotal = SpendingBudgetSection.totalRowContent(
        plannedTotal: PlanView.spendingBudgetTotal(for: projection)
    )
    let savingsTotal = SavingsGoalSection.totalRowContent(
        plannedTotal: PlanView.savingsGoalTotal(for: projection)
    )

    #expect(environment.repository.budgets(for: environment.month).isEmpty)
    #expect(environment.repository.savingsPlans().isEmpty)
    #expect(spendingTotal.label == "TOTAL SPENDING BUDGET")
    #expect(spendingTotal.amount == .zero)
    #expect(savingsTotal.label == "TOTAL SAVINGS GOAL")
    #expect(savingsTotal.amount == .zero)
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
