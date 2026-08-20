import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func enteredPaycheckCanSettlePlannedIncomeWithoutDoubleCounting() throws {
    let environment = try QACorrectnessEnvironment()
    let incomeID = UUID()

    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            id: incomeID,
            name: "Salary",
            expectedAmount: 1_000,
            frequency: .monthly,
            anchorDate: environment.date(day: 5)
        )
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection
    let occurrence = try #require(
        environment.transactionsViewModel
            .unsettledOccurrences(for: .income, in: environment.month)
            .first
    )

    try environment.transactionsViewModel.addTransaction(
        date: environment.date(day: 5),
        amount: 1_000,
        type: .income,
        category: "Income",
        detail: "Salary",
        settlement: occurrence,
        in: environment.month
    )

    let after = environment.projectionStore.projection
    #expect(before.totalExpectedIncome == 1_000)
    #expect(before.remainingExpectedIncome == 1_000)
    #expect(after.totalExpectedIncome == before.totalExpectedIncome)
    #expect(after.incomeReceived == 1_000)
    #expect(
        after.currentAvailableBalance
            == before.currentAvailableBalance + 1_000
    )
    #expect(
        after.remainingExpectedIncome
            == before.remainingExpectedIncome - 1_000
    )
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

@Test
@MainActor
func extraIncomeRaisesTotalWithoutSettlingPlannedIncome() throws {
    let environment = try QACorrectnessEnvironment()

    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            name: "Salary",
            expectedAmount: 1_000,
            frequency: .monthly,
            anchorDate: environment.date(day: 5)
        )
    )
    environment.projectionStore.refresh()

    try environment.transactionsViewModel.addTransaction(
        date: environment.date(day: 12),
        amount: 250,
        type: .income,
        category: "Income",
        detail: "Extra income",
        in: environment.month
    )

    let projection = environment.projectionStore.projection
    #expect(projection.totalExpectedIncome == 1_250)
    #expect(projection.incomeReceived == 250)
    #expect(projection.remainingExpectedIncome == 1_000)
}

@Test
@MainActor
func markIncomeReceivedRejectsDuplicateOccurrence() throws {
    let environment = try QACorrectnessEnvironment()
    let incomeID = UUID()
    let occurrence = environment.date(day: 5)

    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            id: incomeID,
            name: "Salary",
            expectedAmount: 1_000,
            frequency: .monthly,
            anchorDate: occurrence
        )
    )
    let unsettledOccurrence = try #require(
        ExpectedIncomeSection.unsettledOccurrences(
            repository: environment.repository,
            month: environment.month,
            calendar: environment.calendar
        ).first
    )

    let firstResult = ExpectedIncomeSettlementAction.markAsReceived(
        unsettledOccurrence,
        amount: 1_000,
        repository: environment.repository,
        projectionStore: environment.projectionStore,
        calendar: environment.calendar
    )
    let secondResult = ExpectedIncomeSettlementAction.markAsReceived(
        unsettledOccurrence,
        amount: 1_000,
        repository: environment.repository,
        projectionStore: environment.projectionStore,
        calendar: environment.calendar
    )

    #expect(firstResult == nil)
    #expect(secondResult == .alreadyReceived)
    #expect(
        secondResult?.message
            == "This income occurrence has already been marked as received."
    )

    #expect(
        environment.repository.transactions(in: environment.month).count {
            $0.settlesIncomeID == incomeID
        } == 1
    )
}

@Test
@MainActor
func expectedIncomeOccurrenceStatusUsesCalendarDays() {
    let calendar = QACorrectnessEnvironment.testCalendar
    let referenceDate = QACorrectnessEnvironment.date(day: 20, calendar: calendar)

    #expect(
        ExpectedIncomeOccurrenceStatus.status(
            for: QACorrectnessEnvironment.date(day: 19, calendar: calendar),
            relativeTo: referenceDate,
            calendar: calendar
        ) == .overdue
    )
    #expect(
        ExpectedIncomeOccurrenceStatus.status(
            for: QACorrectnessEnvironment.date(day: 21, calendar: calendar),
            relativeTo: referenceDate,
            calendar: calendar
        ) == .expected
    )
    #expect(
        ExpectedIncomeOccurrenceStatus.status(
            for: QACorrectnessEnvironment.date(day: 20, calendar: calendar),
            relativeTo: referenceDate,
            calendar: calendar
        ) == .expected
    )
}

@Test
@MainActor
func homeAndAddTransactionOfferTheSameUnsettledIncomeOccurrences() throws {
    let environment = try QACorrectnessEnvironment()
    let incomeID = UUID()

    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            id: incomeID,
            name: "Weekly salary",
            expectedAmount: 1_000,
            frequency: .weekly,
            anchorDate: environment.date(day: 2)
        )
    )
    try environment.repository.markIncomeReceived(
        incomeID: incomeID,
        occurrence: environment.date(day: 2),
        amount: 1_000,
        on: environment.date(day: 2)
    )
    environment.projectionStore.refresh()

    let homeOccurrences = ExpectedIncomeSection.unsettledOccurrences(
        repository: environment.repository,
        month: environment.month,
        calendar: environment.calendar
    )
    let pickerOccurrences = AddTransactionView.unsettledOccurrences(
        for: .income,
        in: environment.month,
        repository: environment.repository,
        calendar: environment.calendar
    )

    #expect(homeOccurrences == pickerOccurrences)
    #expect(
        homeOccurrences.map(\.occurrenceDate)
            == [9, 16, 23, 30].map { environment.date(day: $0) }
    )
}

@Test
@MainActor
func partialIncomeReceiptSettlesOccurrenceAndCreditsActualAmount() throws {
    let environment = try QACorrectnessEnvironment()

    try environment.repository.addIncomeSource(
        IncomeSourceEntity(
            name: "Salary",
            expectedAmount: 1_000,
            frequency: .monthly,
            anchorDate: environment.date(day: 5)
        )
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection
    let occurrence = try #require(
        ExpectedIncomeSection.unsettledOccurrences(
            repository: environment.repository,
            month: environment.month,
            calendar: environment.calendar
        ).first
    )

    let result = ExpectedIncomeSettlementAction.markAsReceived(
        occurrence,
        amount: 900,
        repository: environment.repository,
        projectionStore: environment.projectionStore,
        calendar: environment.calendar
    )

    let after = environment.projectionStore.projection
    #expect(result == nil)
    #expect(after.currentAvailableBalance == before.currentAvailableBalance + 900)
    #expect(after.incomeReceived == 900)
    #expect(after.remainingExpectedIncome == .zero)
    #expect(
        ExpectedIncomeSection.unsettledOccurrences(
            repository: environment.repository,
            month: environment.month,
            calendar: environment.calendar
        ).isEmpty
    )
}

@Test
@MainActor
func enteredExpenseCanSettlePlannedBillWithoutDoubleCounting() throws {
    let environment = try QACorrectnessEnvironment(startingBalance: 2_000)
    let billID = UUID()

    try environment.repository.addBill(
        RecurringBillEntity(
            id: billID,
            name: "Internet",
            amount: 100,
            amountType: .fixed,
            category: "Utilities",
            frequency: .monthly,
            anchorDate: environment.date(day: 10)
        )
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection
    let occurrence = try #require(
        environment.transactionsViewModel
            .unsettledOccurrences(for: .expense, in: environment.month)
            .first
    )

    try environment.transactionsViewModel.addTransaction(
        date: environment.date(day: 10),
        amount: 100,
        type: .expense,
        category: "Utilities",
        detail: "Internet",
        settlement: occurrence,
        in: environment.month
    )

    let after = environment.projectionStore.projection
    #expect(before.remainingBills == 100)
    #expect(after.remainingBills == .zero)
    #expect(after.billsPaid == 100)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

@Test
@MainActor
func startingBalancePersistsPerMonthAndMovesBalancesExactly() throws {
    let environment = try QACorrectnessEnvironment()
    let before = environment.projectionStore.projection

    try environment.repository.setStartingBalance(2_400, for: environment.month)
    environment.projectionStore.refresh()

    let after = environment.projectionStore.projection
    #expect(after.currentAvailableBalance == before.currentAvailableBalance + 2_400)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance + 2_400)

    let reloadedRepository = FinanceRepository(
        context: ModelContext(environment.container),
        calendar: environment.calendar,
        userDefaults: environment.userDefaults
    )
    #expect(reloadedRepository.startingBalance(for: environment.month) == 2_400)
    #expect(reloadedRepository.startingBalance(for: environment.month.next) == 2_400)
}

@Test
func planAmountParserUsesLocaleSeparatorsAndRoundTrips() {
    let cases: [(locale: Locale, text: String, value: Decimal)] = [
        (Locale(identifier: "en_US"), "12.50", Decimal(string: "12.50")!),
        (Locale(identifier: "en_US"), "1,234.56", Decimal(string: "1234.56")!),
        (Locale(identifier: "de_DE"), "12,50", Decimal(string: "12.50")!),
        (Locale(identifier: "de_DE"), "1.234,56", Decimal(string: "1234.56")!),
        (Locale(identifier: "fr_FR"), "12,50", Decimal(string: "12.50")!),
        (Locale(identifier: "fr_FR"), "1\u{202F}234,56", Decimal(string: "1234.56")!)
    ]

    for item in cases {
        let parsed = PlanAmountParser.decimal(from: item.text, locale: item.locale)
        #expect(parsed == item.value)
        #expect(parsed.map { PlanAmountParser.text($0, locale: item.locale) } == item.text)
    }

    #expect(
        PlanAmountParser.decimal(
            from: "12.50",
            locale: Locale(identifier: "de_DE")
        ) == Decimal(string: "12.50")
    )
}

@Test
@MainActor
func categoryIdentityMatchesCaseInsensitivelyAndListsOnce() throws {
    let environment = try QACorrectnessEnvironment(startingBalance: 1_000)

    try environment.repository.addBudget(
        BudgetEntity(category: "  Groceries  ", monthlyLimit: 500)
    )
    try environment.repository.addTransaction(
        TransactionEntity(
            date: environment.date(day: 8),
            amount: 100,
            type: .expense,
            category: "groceries",
            detail: "Market"
        )
    )
    environment.projectionStore.refresh()
    environment.transactionsViewModel.load(month: environment.month)

    #expect(environment.projectionStore.projection.actualVariableSpending == 100)
    #expect(environment.projectionStore.projection.remainingVariableSpending == 400)
    #expect(
        environment.transactionsViewModel.availableCategories.filter {
            $0.caseInsensitiveCompare("Groceries") == .orderedSame
        }.count == 1
    )
}

@Test
@MainActor
func failedRefreshRetainsLastKnownProjectionAndMarksItStale() throws {
    var shouldFailReads = false
    let environment = try QACorrectnessEnvironment(
        startingBalance: 2_400,
        shouldFailReads: { shouldFailReads }
    )
    let knownProjection = environment.projectionStore.projection

    shouldFailReads = true
    environment.projectionStore.refresh()

    #expect(environment.projectionStore.projection == knownProjection)
    #expect(environment.projectionStore.isStale)
    #expect(environment.projectionStore.loadError == .dataLoadFailed)
    #expect(
        environment.projectionStore.loadErrorMessage
            == "Your data couldn't be loaded. The figures below may be out of date."
    )

    shouldFailReads = false
    environment.projectionStore.refresh()
    #expect(!environment.projectionStore.isStale)
    #expect(environment.projectionStore.loadError == nil)
}

@MainActor
private struct QACorrectnessEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let calendar: Calendar
    let container: ModelContainer
    let userDefaults: UserDefaults
    let repository: FinanceRepository
    let projectionStore: ProjectionStore
    let transactionsViewModel: TransactionsViewModel

    init(
        startingBalance: Decimal = .zero,
        shouldFailReads: @escaping () -> Bool = { false }
    ) throws {
        let calendar = Self.testCalendar
        self.calendar = calendar

        let container = try PersistenceController.inMemory()
        self.container = container
        let defaults = try isolatedTestUserDefaults(
            suitePrefix: "FlowPlanTests.QACorrectness"
        )
        userDefaults = defaults
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
            userDefaults: defaults,
            now: { Self.date(day: 20, calendar: calendar) },
            shouldFailReads: shouldFailReads
        )
        self.repository = repository

        if startingBalance != .zero {
            try repository.setStartingBalance(startingBalance, for: month)
        }

        let appState = AppState(
            selectedMonth: month,
            calendar: calendar,
            userDefaults: defaults,
            now: { Self.date(day: 20, calendar: calendar) }
        )
        let projectionStore = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: container.mainContext
        )
        self.projectionStore = projectionStore
        transactionsViewModel = TransactionsViewModel(
            repository: repository,
            projectionStore: projectionStore,
            calendar: calendar,
            now: { Self.date(day: 20, calendar: calendar) }
        )
    }

    func date(day: Int) -> Date {
        Self.date(day: day, calendar: calendar)
    }

    static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func date(day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .distantPast
    }
}
