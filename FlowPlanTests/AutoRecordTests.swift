import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func refreshAutoRecordsOverdueAutopayBillAndDebtExactlyOnce() throws {
    let environment = try AutoRecordTestEnvironment(startingBalance: 2_000)
    #expect(environment.appState.recordAutopayAutomatically)
    let billID = try environment.addBill(
        name: "Internet",
        amount: 120,
        dueDay: 10,
        isAutoPay: true
    )
    let debtID = try environment.addDebt(
        name: "Car loan",
        balance: 5_000,
        payment: 300,
        dueDay: 15,
        isAutoPay: true
    )

    environment.projectionStore.refresh()
    environment.projectionStore.refresh()
    environment.projectionStore.refresh()

    let transactions = environment.repository.transactions(in: environment.month)
    #expect(transactions.count == 2)
    #expect(transactions.allSatisfy { $0.isAutoRecorded })
    #expect(Set(transactions.compactMap(\.settlesBillID)) == Set([billID]))
    #expect(Set(transactions.compactMap(\.settlesDebtID)) == Set([debtID]))
}

@Test
@MainActor
func refreshDoesNotDuplicatePaymentsAlreadySettledByHand() throws {
    let environment = try AutoRecordTestEnvironment()
    let billID = try environment.addBill(
        name: "Phone",
        amount: 90,
        dueDay: 8,
        isAutoPay: true
    )
    let debtID = try environment.addDebt(
        name: "Student loan",
        balance: 4_000,
        payment: 250,
        dueDay: 12,
        isAutoPay: true
    )

    try environment.repository.markBillPaid(
        billID: billID,
        occurrence: environment.date(day: 8),
        amount: 90,
        on: environment.date(day: 8)
    )
    try environment.repository.markDebtPaymentMade(
        debtID: debtID,
        amount: 250,
        on: environment.date(day: 12)
    )

    environment.projectionStore.refresh()
    environment.projectionStore.refresh()

    let transactions = environment.repository.transactions(in: environment.month)
    #expect(transactions.count == 2)
    #expect(transactions.allSatisfy { !$0.isAutoRecorded })
}

@Test
@MainActor
func refreshLeavesFutureAndNonAutopayPaymentsUnrecorded() throws {
    let environment = try AutoRecordTestEnvironment()
    _ = try environment.addBill(
        name: "Future auto bill",
        amount: 100,
        dueDay: 25,
        isAutoPay: true
    )
    _ = try environment.addDebt(
        name: "Future auto debt",
        balance: 2_000,
        payment: 100,
        dueDay: 25,
        isAutoPay: true
    )
    _ = try environment.addBill(
        name: "Auto bill due today",
        amount: 70,
        dueDay: 20,
        isAutoPay: true
    )
    _ = try environment.addDebt(
        name: "Auto debt due today",
        balance: 1_000,
        payment: 50,
        dueDay: 20,
        isAutoPay: true
    )
    _ = try environment.addBill(
        name: "Manual bill",
        amount: 80,
        dueDay: 5,
        isAutoPay: false
    )
    _ = try environment.addDebt(
        name: "Manual debt",
        balance: 1_500,
        payment: 75,
        dueDay: 5,
        isAutoPay: false
    )

    environment.projectionStore.refresh()

    #expect(environment.repository.transactions(in: environment.month).isEmpty)
}

@Test
@MainActor
func disabledPreferenceRestoresPromptOnlyAutopayWorkflow() throws {
    let environment = try AutoRecordTestEnvironment(recordAutopayAutomatically: false)
    _ = try environment.addBill(
        name: "Rent",
        amount: 900,
        dueDay: 1,
        isAutoPay: true
    )
    _ = try environment.addDebt(
        name: "Mortgage",
        balance: 200_000,
        payment: 1_200,
        dueDay: 1,
        isAutoPay: true
    )

    environment.projectionStore.refresh()

    #expect(environment.repository.transactions(in: environment.month).isEmpty)
}

@Test
@MainActor
func deletingAutoRecordedPaymentsRestoresProjectionAndKeepsThemDeleted() throws {
    let environment = try AutoRecordTestEnvironment(
        startingBalance: 2_000,
        recordAutopayAutomatically: false
    )
    _ = try environment.addBill(
        name: "Utilities",
        amount: 150,
        dueDay: 10,
        isAutoPay: true
    )
    let debtID = try environment.addDebt(
        name: "Car loan",
        balance: 5_000,
        payment: 300,
        dueDay: 15,
        isAutoPay: true
    )
    environment.projectionStore.refresh()
    let before = environment.projectionStore.projection

    environment.appState.recordAutopayAutomatically = true
    environment.projectionStore.refresh()
    let recorded = environment.projectionStore.projection
    let autoRecordedTransactions = environment.repository.transactions(in: environment.month)

    #expect(autoRecordedTransactions.count == 2)
    #expect(recorded.currentAvailableBalance == before.currentAvailableBalance - 450)
    #expect(recorded.expensesPaid == before.expensesPaid + 450)
    #expect(recorded.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
    #expect(environment.repository.debts().first { $0.id == debtID }?.currentBalance == 4_700)

    for transaction in autoRecordedTransactions {
        try environment.repository.deleteTransaction(id: transaction.id)
    }
    environment.projectionStore.refresh()
    environment.projectionStore.refresh()
    let restored = environment.projectionStore.projection

    #expect(environment.repository.transactions(in: environment.month).isEmpty)
    #expect(restored.currentAvailableBalance == before.currentAvailableBalance)
    #expect(restored.expensesPaid == before.expensesPaid)
    #expect(restored.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
    #expect(environment.repository.debts().first { $0.id == debtID }?.currentBalance == 5_000)
}

@Test
@MainActor
func debtFirstPaymentMonthPersistsAndPreventsEarlyAutoRecording() throws {
    let environment = try AutoRecordTestEnvironment()
    let october = MonthKey(year: 2026, month: 10)
    let debtID = try environment.addDebt(
        name: "New loan",
        balance: 10_000,
        payment: 500,
        dueDay: 1,
        isAutoPay: true,
        firstPaymentMonth: october
    )

    environment.projectionStore.refresh()

    let debt = try #require(environment.repository.debts().first { $0.id == debtID })
    #expect(debt.firstPaymentMonth == october)
    #expect(environment.repository.transactions(in: environment.month).isEmpty)
    #expect(environment.projectionStore.projection.debtPaymentsDue == .zero)
}

@MainActor
private struct AutoRecordTestEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let referenceDate: Date
    let calendar: Calendar
    let container: ModelContainer
    let repository: FinanceRepository
    let appState: AppState
    let projectionStore: ProjectionStore

    init(
        startingBalance: Decimal = .zero,
        recordAutopayAutomatically: Bool = true
    ) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        referenceDate = Self.date(day: 20, calendar: calendar)

        let container = try PersistenceController.inMemory()
        self.container = container
        let userDefaults = try isolatedTestUserDefaults(
            suitePrefix: "FlowPlanTests.AutoRecord"
        )
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
            userDefaults: userDefaults,
            now: { Self.date(day: 20, calendar: calendar) }
        )
        self.repository = repository

        if startingBalance != .zero {
            try repository.setStartingBalance(startingBalance, for: month)
        }

        let appState = AppState(
            selectedMonth: month,
            calendar: calendar,
            userDefaults: userDefaults,
            now: { Self.date(day: 20, calendar: calendar) }
        )
        if !recordAutopayAutomatically {
            appState.recordAutopayAutomatically = false
        }
        self.appState = appState
        projectionStore = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: container.mainContext,
            now: { Self.date(day: 20, calendar: calendar) }
        )
    }

    @discardableResult
    func addBill(
        name: String,
        amount: Decimal,
        dueDay: Int,
        isAutoPay: Bool
    ) throws -> UUID {
        let id = UUID()
        try repository.addBill(
            RecurringBillEntity(
                id: id,
                name: name,
                amount: amount,
                amountType: .fixed,
                category: "Bills",
                frequency: .monthly,
                anchorDate: date(day: dueDay),
                isAutoPay: isAutoPay
            )
        )
        return id
    }

    @discardableResult
    func addDebt(
        name: String,
        balance: Decimal,
        payment: Decimal,
        dueDay: Int,
        isAutoPay: Bool,
        firstPaymentMonth: MonthKey? = nil
    ) throws -> UUID {
        let id = UUID()
        try repository.addDebt(
            DebtEntity(
                id: id,
                name: name,
                currentBalance: balance,
                annualInterestRate: .zero,
                monthlyPayment: payment,
                category: "Debt",
                firstPaymentMonth: firstPaymentMonth,
                dueDay: dueDay,
                isAutoPay: isAutoPay,
                isPaidThroughBills: false
            )
        )
        return id
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
}
