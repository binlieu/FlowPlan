import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func addingDuplicateAccountNameCaseInsensitivelyIsRejected() throws {
    let container = try PersistenceController.inMemory()
    let repository = FinanceRepository(context: container.mainContext)

    try repository.addAccount(named: "Checking")

    do {
        try repository.addAccount(named: "  checking  ")
        Issue.record("A duplicate account name should be rejected.")
    } catch let error as FinanceRepositoryError {
        #expect(error == .duplicateAccountName)
    }

    #expect(repository.accounts().map(\.name) == ["Checking"])
}

@Test
@MainActor
func deletingUsedAccountClearsLabelsWithoutChangingTransactionsOrProjection() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = accountsTestCalendar
    let repository = FinanceRepository(context: context, calendar: calendar)
    let month = MonthKey(year: 2026, month: 8)
    let referenceDate = accountsTestDate(day: 20, calendar: calendar)

    try repository.addAccount(named: "Checking")
    let account = try #require(repository.accounts().first)
    try repository.setStartingBalance(2_000, for: month)
    try repository.addTransaction(
        TransactionEntity(
            date: accountsTestDate(day: 8, calendar: calendar),
            amount: 125,
            type: .expense,
            category: "Groceries",
            detail: "Market",
            account: "Checking"
        )
    )
    try repository.addTransaction(
        TransactionEntity(
            date: accountsTestDate(day: 12, calendar: calendar),
            amount: 900,
            type: .income,
            category: "Income",
            detail: "Freelance",
            account: "checking"
        )
    )

    let engine = MonthlyProjectionEngine()
    let before = engine.project(
        repository.projectionInput(
            for: month,
            referenceDate: referenceDate,
            configuration: .default
        )
    )
    let transactionIDsBefore = Set(repository.transactions(in: month).map(\.id))

    #expect(repository.transactionCount(forAccount: account) == 2)
    try repository.deleteAccount(account)

    let after = engine.project(
        repository.projectionInput(
            for: month,
            referenceDate: referenceDate,
            configuration: .default
        )
    )
    let storedTransactions = try context.fetch(FetchDescriptor<TransactionEntity>())

    #expect(Set(repository.transactions(in: month).map(\.id)) == transactionIDsBefore)
    #expect(storedTransactions.count == 2)
    #expect(storedTransactions.allSatisfy { $0.account.isEmpty })
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

@Test
@MainActor
func deletingUnusedAccountRemovesIt() throws {
    let container = try PersistenceController.inMemory()
    let repository = FinanceRepository(context: container.mainContext)

    try repository.addAccount(named: "Cash")
    let account = try #require(repository.accounts().first)
    #expect(repository.transactionCount(forAccount: account) == 0)

    try repository.deleteAccount(account)

    #expect(repository.accounts().isEmpty)
}

@Test
@MainActor
func firstLaunchSeedsDistinctExistingAccountLabels() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = accountsTestCalendar

    context.insert(accountsTestTransaction(account: "Checking", day: 2, calendar: calendar))
    context.insert(accountsTestTransaction(account: " checking ", day: 3, calendar: calendar))
    context.insert(accountsTestTransaction(account: "Apple Card", day: 4, calendar: calendar))
    context.insert(accountsTestTransaction(account: "", day: 5, calendar: calendar))
    try context.save()

    let repository = FinanceRepository(context: context, calendar: calendar)
    let seededNames = repository.accounts().map(\.name)

    #expect(seededNames.count == 2)
    #expect(Set(seededNames.map { $0.lowercased() }) == ["checking", "apple card"])
}

@Test
@MainActor
func transactionEditorOptionsKeepStoredAccountMissingFromManagedList() {
    let options = AddTransactionView.accountOptions(
        managedAccounts: [Account(id: UUID(), name: "Savings")],
        storedValue: "Legacy Checking"
    )

    #expect(options.contains("Legacy Checking"))
    #expect(options.contains("Savings"))
}

private var accountsTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func accountsTestDate(day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = 2026
    components.month = 8
    components.day = day
    components.hour = 12
    return calendar.date(from: components) ?? .distantPast
}

private func accountsTestTransaction(
    account: String,
    day: Int,
    calendar: Calendar
) -> TransactionEntity {
    TransactionEntity(
        date: accountsTestDate(day: day, calendar: calendar),
        amount: 10,
        type: .expense,
        category: "Other",
        detail: "Existing",
        account: account
    )
}
