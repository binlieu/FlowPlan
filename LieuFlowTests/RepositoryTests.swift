import Foundation
import SwiftData
import Testing
import LieuFlowDomain
@testable import LieuFlow

@Test
@MainActor
func entitiesRoundTripThroughPersistenceAndDomain() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = repositoryTestCalendar
    let anchorDate = repositoryDate(2026, 8, 5, calendar: calendar)

    let transaction = TransactionSnapshot(
        id: repositoryID(1),
        date: anchorDate,
        amount: 125,
        type: .expense,
        category: "Groceries",
        detail: "Market"
    )
    let income = PlannedIncome(
        id: repositoryID(2),
        name: "Salary",
        expectedAmount: 6_500,
        recurrence: RecurrenceRule(frequency: .monthly, anchorDate: anchorDate),
        isActive: true
    )
    let bill = PlannedBill(
        id: repositoryID(3),
        name: "Internet",
        amount: 89.99,
        amountType: .fixed,
        category: "Utilities",
        recurrence: RecurrenceRule(frequency: .monthly, anchorDate: anchorDate),
        isAutoPay: true,
        isActive: true
    )
    let budget = BudgetAllocation(
        id: repositoryID(4),
        category: "Groceries",
        monthlyLimit: 800
    )
    let savings = SavingsPlan(
        id: repositoryID(5),
        name: "Emergency Fund",
        monthlyTarget: 2_000
    )

    context.insert(TransactionEntity(domain: transaction, note: "Weekly", account: "Checking"))
    context.insert(IncomeSourceEntity(domain: income))
    context.insert(RecurringBillEntity(domain: bill))
    context.insert(BudgetEntity(domain: budget, scopeYear: 2026, scopeMonth: 8))
    context.insert(
        SavingsGoalEntity(
            domain: savings,
            targetAmount: 24_000,
            currentAmount: 4_000,
            targetDate: repositoryDate(2027, 8, 5, calendar: calendar)
        )
    )
    context.insert(MonthSettingsEntity(year: 2026, month: 8, startingBalance: 2_400))
    try context.save()

    let storedTransaction = try #require(
        context.fetch(FetchDescriptor<TransactionEntity>()).first
    )
    let storedIncome = try #require(
        context.fetch(FetchDescriptor<IncomeSourceEntity>()).first
    )
    let storedBill = try #require(
        context.fetch(FetchDescriptor<RecurringBillEntity>()).first
    )
    let storedBudget = try #require(
        context.fetch(FetchDescriptor<BudgetEntity>()).first
    )
    let storedSavings = try #require(
        context.fetch(FetchDescriptor<SavingsGoalEntity>()).first
    )
    let storedSettings = try #require(
        context.fetch(FetchDescriptor<MonthSettingsEntity>()).first
    )

    #expect(storedTransaction.toDomain() == transaction)
    #expect(storedIncome.toDomain() == income)
    #expect(storedBill.toDomain() == bill)
    #expect(storedBudget.toDomain() == budget)
    #expect(storedSavings.toDomain() == savings)
    #expect(storedBudget.scopeYear == 2026)
    #expect(storedBudget.scopeMonth == 8)
    #expect(storedSavings.targetAmount == 24_000)
    #expect(storedSavings.currentAmount == 4_000)
    #expect(storedSettings.toDomain().month == MonthKey(year: 2026, month: 8))
    #expect(storedSettings.toDomain().startingBalance == 2_400)

    storedTransaction.typeRaw = "invalid"
    storedIncome.frequencyRaw = "invalid"
    storedBill.amountTypeRaw = "invalid"
    storedBill.frequencyRaw = "invalid"
    #expect(storedTransaction.type == .expense)
    #expect(storedIncome.frequency == .monthly)
    #expect(storedBill.amountType == .fixed)
    #expect(storedBill.frequency == .monthly)
}

@Test
@MainActor
func budgetsUseExactMonthOverridesWithoutMixingDefaults() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let repository = FinanceRepository(context: context, calendar: repositoryTestCalendar)

    context.insert(BudgetEntity(id: repositoryID(10), category: "Default A", monthlyLimit: 100))
    context.insert(BudgetEntity(id: repositoryID(11), category: "Default B", monthlyLimit: 200))
    context.insert(
        BudgetEntity(
            id: repositoryID(12),
            category: "August Only",
            monthlyLimit: 350,
            scopeYear: 2026,
            scopeMonth: 8
        )
    )
    context.insert(
        BudgetEntity(
            id: repositoryID(13),
            category: "September Only",
            monthlyLimit: 450,
            scopeYear: 2026,
            scopeMonth: 9
        )
    )
    try context.save()

    let august = repository.budgets(for: MonthKey(year: 2026, month: 8))
    let october = repository.budgets(for: MonthKey(year: 2026, month: 10))

    #expect(august.map(\.category) == ["August Only"])
    #expect(Set(october.map(\.category)) == Set(["Default A", "Default B"]))
}

@Test
@MainActor
func transactionsFetchIncludesFirstAndLastDayAndExcludesOtherMonths() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = repositoryTestCalendar
    let repository = FinanceRepository(context: context, calendar: calendar)

    let firstDay = repositoryDate(2026, 8, 1, hour: 0, calendar: calendar)
    let lastDay = repositoryDate(
        2026,
        8,
        31,
        hour: 23,
        minute: 59,
        second: 59,
        nanosecond: 500_000_000,
        calendar: calendar
    )
    let previousMonth = repositoryDate(2026, 7, 31, hour: 23, calendar: calendar)
    let nextMonth = repositoryDate(2026, 9, 1, hour: 0, calendar: calendar)

    context.insert(transactionEntity(id: 20, date: firstDay))
    context.insert(transactionEntity(id: 21, date: lastDay))
    context.insert(transactionEntity(id: 22, date: previousMonth))
    context.insert(transactionEntity(id: 23, date: nextMonth))
    try context.save()

    let transactions = repository.transactions(in: MonthKey(year: 2026, month: 8))

    #expect(transactions.map(\.id) == [repositoryID(21), repositoryID(20)])
}

@Test
@MainActor
func markingBillPaidLinksOneTransactionWithoutDoubleCounting() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = repositoryTestCalendar
    let repository = FinanceRepository(context: context, calendar: calendar)
    let month = MonthKey(year: 2026, month: 8)
    let billID = repositoryID(30)
    let occurrence = repositoryDate(2026, 8, 10, calendar: calendar)

    try repository.addBill(
        RecurringBillEntity(
            id: billID,
            name: "Mortgage",
            amount: 1_850,
            amountType: .fixed,
            category: "Housing",
            frequency: .monthly,
            anchorDate: occurrence
        )
    )
    try repository.setStartingBalance(5_000, for: month)

    let engine = MonthlyProjectionEngine()
    let before = engine.project(
        repository.projectionInput(
            for: month,
            referenceDate: repositoryDate(2026, 8, 15, calendar: calendar),
            configuration: .default
        )
    )

    try repository.markBillPaid(
        billID: billID,
        occurrence: occurrence,
        amount: 1_850,
        on: repositoryDate(2026, 8, 12, calendar: calendar)
    )

    let linkedTransactions = repository.transactions(in: month).filter {
        $0.settlesBillID == billID
    }
    let after = engine.project(
        repository.projectionInput(
            for: month,
            referenceDate: repositoryDate(2026, 8, 15, calendar: calendar),
            configuration: .default
        )
    )

    #expect(linkedTransactions.count == 1)
    #expect(linkedTransactions.first?.type == .expense)
    #expect(before.remainingBills == 1_850)
    #expect(after.remainingBills == .zero)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

private var repositoryTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func repositoryDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 12,
    minute: Int = 0,
    second: Int = 0,
    nanosecond: Int = 0,
    calendar: Calendar
) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    components.nanosecond = nanosecond
    return calendar.date(from: components) ?? .distantPast
}

private func repositoryID(_ value: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, value))
}

private func transactionEntity(id: UInt8, date: Date) -> TransactionEntity {
    TransactionEntity(
        id: repositoryID(id),
        date: date,
        amount: 10,
        type: .expense,
        category: "Test",
        detail: "Boundary"
    )
}
