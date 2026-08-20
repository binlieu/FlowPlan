import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func billOccurrenceStatusUsesCalendarDaysBeforeNormalBillStatus() {
    let calendar = OverdueBillsTestEnvironment.testCalendar
    let referenceDate = OverdueBillsTestEnvironment.date(day: 20, calendar: calendar)
    let autopayBill = overdueBillsPlannedBill(name: "Internet", isAutoPay: true)
    let estimatedBill = overdueBillsPlannedBill(
        name: "Electricity",
        amountType: .estimated
    )
    let manualBill = overdueBillsPlannedBill(name: "Rent")

    #expect(
        BillOccurrenceStatus.status(
            for: autopayBill,
            occurrenceDate: OverdueBillsTestEnvironment.date(day: 19, calendar: calendar),
            relativeTo: referenceDate,
            calendar: calendar
        ) == .overdue
    )
    #expect(
        BillOccurrenceStatus.status(
            for: autopayBill,
            occurrenceDate: OverdueBillsTestEnvironment.date(day: 21, calendar: calendar),
            relativeTo: referenceDate,
            calendar: calendar
        ) == .autoPay
    )
    #expect(
        BillOccurrenceStatus.status(
            for: autopayBill,
            occurrenceDate: referenceDate,
            relativeTo: referenceDate,
            calendar: calendar
        ) == .autoPay
    )
    #expect(
        BillOccurrenceStatus.status(
            for: estimatedBill,
            occurrenceDate: referenceDate,
            relativeTo: referenceDate,
            calendar: calendar
        ) == .estimated
    )
    #expect(
        BillOccurrenceStatus.status(
            for: manualBill,
            occurrenceDate: referenceDate,
            relativeTo: referenceDate,
            calendar: calendar
        ) == .upcoming
    )
}

@Test
@MainActor
func overdueBillOccurrencesSortFirstAndOldestFirst() {
    let calendar = OverdueBillsTestEnvironment.testCalendar
    let referenceDate = OverdueBillsTestEnvironment.date(day: 20, calendar: calendar)
    let occurrences = [25, 10, 20, 5].map { day in
        BillOccurrence(
            bill: overdueBillsPlannedBill(name: "Bill \(day)"),
            date: OverdueBillsTestEnvironment.date(day: day, calendar: calendar)
        )
    }

    let sorted = UpcomingBillsSection.sortedOccurrences(
        occurrences,
        relativeTo: referenceDate,
        calendar: calendar
    )

    #expect(
        sorted.map { calendar.component(.day, from: $0.date) }
            == [5, 10, 20, 25]
    )
    #expect(
        sorted.prefix(2).allSatisfy {
            BillOccurrenceStatus.status(
                for: $0.bill,
                occurrenceDate: $0.date,
                relativeTo: referenceDate,
                calendar: calendar
            ) == .overdue
        }
    )
}

@Test
@MainActor
func markAllAsPaidSettlesOnlyOverdueAutopayBillsAndPreservesProjection() throws {
    let environment = try OverdueBillsTestEnvironment(startingBalance: 2_000)
    let overdueAutopayID = try environment.addBill(
        name: "Internet",
        amount: 100,
        dueDay: 10,
        isAutoPay: true
    )
    let secondOverdueAutopayID = try environment.addBill(
        name: "Phone",
        amount: 50,
        dueDay: 12,
        isAutoPay: true
    )
    let overdueManualID = try environment.addBill(
        name: "Rent",
        amount: 200,
        dueDay: 11,
        isAutoPay: false
    )
    let futureAutopayID = try environment.addBill(
        name: "Insurance",
        amount: 300,
        dueDay: 25,
        isAutoPay: true
    )
    environment.projectionStore.refresh()

    let occurrences = environment.unsettledOccurrences()
    let before = environment.projectionStore.projection
    let result = OverdueAutopaySettlementAction.markAllAsPaid(
        from: occurrences,
        relativeTo: environment.referenceDate,
        repository: environment.repository,
        projectionStore: environment.projectionStore,
        calendar: environment.calendar
    )

    let after = environment.projectionStore.projection
    let settlements = environment.repository.transactions(in: environment.month).filter {
        $0.settlesBillID != nil
    }
    let remainingBillIDs = Set(environment.unsettledOccurrences().map(\.bill.id))

    #expect(result == nil)
    #expect(settlements.count == 2)
    #expect(Set(settlements.compactMap(\.settlesBillID)) == [
        overdueAutopayID,
        secondOverdueAutopayID
    ])
    #expect(Set(settlements.map(\.date)) == [
        environment.date(day: 10),
        environment.date(day: 12)
    ])
    #expect(settlements.reduce(Decimal.zero) { $0 + $1.amount } == 150)
    #expect(remainingBillIDs.contains(overdueManualID))
    #expect(remainingBillIDs.contains(futureAutopayID))
    #expect(!remainingBillIDs.contains(overdueAutopayID))
    #expect(!remainingBillIDs.contains(secondOverdueAutopayID))
    #expect(after.remainingBills == before.remainingBills - 150)
    #expect(after.expensesPaid == before.expensesPaid + 150)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
    #expect(after.currentAvailableBalance == before.currentAvailableBalance - 150)
}

@Test
@MainActor
func overdueAutopayDebtSelectionExcludesFuturePaidThroughBillsAndManualDebts() {
    let calendar = OverdueBillsTestEnvironment.testCalendar
    let referenceDate = OverdueBillsTestEnvironment.date(day: 20, calendar: calendar)
    let overdueAutopayID = UUID()
    let futureAutopayID = UUID()
    let paidThroughBillsID = UUID()
    let manualID = UUID()
    let occurrences = [
        HomePaymentOccurrence.debt(
            DebtOccurrence(
                debtID: overdueAutopayID,
                name: "Auto loan",
                date: OverdueBillsTestEnvironment.date(day: 10, calendar: calendar),
                amount: 200,
                isPaidThroughBills: false
            )
        ),
        HomePaymentOccurrence.debt(
            DebtOccurrence(
                debtID: futureAutopayID,
                name: "Future loan",
                date: OverdueBillsTestEnvironment.date(day: 25, calendar: calendar),
                amount: 300,
                isPaidThroughBills: false
            )
        ),
        HomePaymentOccurrence.debt(
            DebtOccurrence(
                debtID: paidThroughBillsID,
                name: "Mortgage",
                date: OverdueBillsTestEnvironment.date(day: 5, calendar: calendar),
                amount: 1_850,
                isPaidThroughBills: true
            )
        ),
        HomePaymentOccurrence.debt(
            DebtOccurrence(
                debtID: manualID,
                name: "Manual loan",
                date: OverdueBillsTestEnvironment.date(day: 8, calendar: calendar),
                amount: 100,
                isPaidThroughBills: false
            )
        )
    ]

    let selected = OverdueAutopaySettlementAction.overdueAutopayOccurrences(
        from: occurrences,
        autoPayDebtIDs: [overdueAutopayID, futureAutopayID, paidThroughBillsID],
        relativeTo: referenceDate,
        calendar: calendar
    )

    #expect(selected.count == 1)
    #expect(selected.first?.debtOccurrence?.debtID == overdueAutopayID)
}

@Test
@MainActor
func automaticModePromptSelectionContainsOnlyOverdueNonAutopayPayments() {
    let calendar = OverdueBillsTestEnvironment.testCalendar
    let referenceDate = OverdueBillsTestEnvironment.date(day: 20, calendar: calendar)
    let manualDebtID = UUID()
    let autoDebtID = UUID()
    let manualBill = overdueBillsPlannedBill(name: "Manual bill")
    let autoBill = overdueBillsPlannedBill(name: "Auto bill", isAutoPay: true)
    let occurrences: [HomePaymentOccurrence] = [
        .bill(
            BillOccurrence(
                bill: manualBill,
                date: OverdueBillsTestEnvironment.date(day: 5, calendar: calendar)
            )
        ),
        .bill(
            BillOccurrence(
                bill: autoBill,
                date: OverdueBillsTestEnvironment.date(day: 6, calendar: calendar)
            )
        ),
        .debt(
            DebtOccurrence(
                debtID: manualDebtID,
                name: "Manual debt",
                date: OverdueBillsTestEnvironment.date(day: 7, calendar: calendar),
                amount: 100,
                isPaidThroughBills: false
            )
        ),
        .debt(
            DebtOccurrence(
                debtID: autoDebtID,
                name: "Auto debt",
                date: OverdueBillsTestEnvironment.date(day: 8, calendar: calendar),
                amount: 100,
                isPaidThroughBills: false
            )
        )
    ]

    let selected = OverdueAutopaySettlementAction.overdueNonAutopayOccurrences(
        from: occurrences,
        autoPayDebtIDs: [autoDebtID],
        relativeTo: referenceDate,
        calendar: calendar
    )

    #expect(selected.count == 2)
    #expect(selected.compactMap(\.billOccurrence).map(\.bill.id) == [manualBill.id])
    #expect(selected.compactMap(\.debtOccurrence).map(\.debtID) == [manualDebtID])
}

@Test
@MainActor
func markAllAsPaidSettlesOverdueAutopayDebtAndPreservesProjection() throws {
    let environment = try OverdueBillsTestEnvironment(startingBalance: 2_000)
    let debtID = try environment.addDebt(
        name: "Auto loan",
        balance: 1_200,
        payment: 200,
        dueDay: 10,
        isAutoPay: true
    )
    environment.projectionStore.refresh()

    let before = environment.projectionStore.projection
    let occurrences = UpcomingBillsSection.paymentOccurrences(
        bills: [],
        debts: before.debtOccurrences,
        relativeTo: environment.referenceDate,
        calendar: environment.calendar
    )
    let result = OverdueAutopaySettlementAction.markAllAsPaid(
        from: occurrences,
        autoPayDebtIDs: [debtID],
        relativeTo: environment.referenceDate,
        repository: environment.repository,
        projectionStore: environment.projectionStore,
        calendar: environment.calendar
    )

    let after = environment.projectionStore.projection
    let settlements = environment.repository.transactions(in: environment.month).filter {
        $0.settlesDebtID == debtID
    }

    #expect(result == nil)
    #expect(settlements.count == 1)
    #expect(settlements.first?.amount == 200)
    // A settlement carries the occurrence's due *day*, not a particular instant — debt
    // occurrences are built at the start of the day. Asserting an exact timestamp would pin an
    // arbitrary time-of-day instead of the behaviour that matters.
    #expect(
        environment.calendar.isDate(
            try #require(settlements.first?.date),
            inSameDayAs: environment.date(day: 10)
        )
    )
    #expect(after.currentAvailableBalance == before.currentAvailableBalance - 200)
    #expect(after.expensesPaid == before.expensesPaid + 200)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

@Test
@MainActor
func dismissedAutopayPromptStaysDismissedForSameOccurrencesAfterRefresh() throws {
    let environment = try OverdueBillsTestEnvironment()
    try environment.addBill(
        name: "Internet",
        amount: 100,
        dueDay: 10,
        isAutoPay: true
    )
    environment.projectionStore.refresh()

    let occurrences = environment.unsettledOccurrences()
    let overdueAutopayOccurrences = occurrences.filter {
        $0.bill.isAutoPay
            && BillOccurrenceStatus.status(
                for: $0.bill,
                occurrenceDate: $0.date,
                relativeTo: environment.referenceDate,
                calendar: environment.calendar
            ) == .overdue
    }
    let dismissalStore = OverdueAutopayPromptDismissalStore(
        userDefaults: environment.userDefaults
    )

    #expect(
        dismissalStore.undismissedOccurrences(
            in: overdueAutopayOccurrences,
            calendar: environment.calendar
        ).count == 1
    )

    dismissalStore.dismiss(overdueAutopayOccurrences, calendar: environment.calendar)
    environment.projectionStore.refresh()

    let refreshedStore = OverdueAutopayPromptDismissalStore(
        userDefaults: environment.userDefaults
    )
    let refreshedOverdueAutopayOccurrences = environment.unsettledOccurrences().filter {
        $0.bill.isAutoPay
            && BillOccurrenceStatus.status(
                for: $0.bill,
                occurrenceDate: $0.date,
                relativeTo: environment.referenceDate,
                calendar: environment.calendar
            ) == .overdue
    }

    #expect(
        refreshedStore.undismissedOccurrences(
            in: refreshedOverdueAutopayOccurrences,
            calendar: environment.calendar
        ).isEmpty
    )
}

private func overdueBillsPlannedBill(
    name: String,
    amountType: BillAmountType = .fixed,
    isAutoPay: Bool = false
) -> PlannedBill {
    PlannedBill(
        id: UUID(),
        name: name,
        amount: 100,
        amountType: amountType,
        category: "Bills",
        recurrence: RecurrenceRule(
            frequency: .monthly,
            anchorDate: .distantPast
        ),
        isAutoPay: isAutoPay,
        isActive: true
    )
}

@MainActor
private struct OverdueBillsTestEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let referenceDate: Date
    let calendar: Calendar
    let userDefaults: UserDefaults
    let container: ModelContainer
    let repository: FinanceRepository
    let projectionStore: ProjectionStore

    init(startingBalance: Decimal = .zero) throws {
        let calendar = Self.testCalendar
        self.calendar = calendar
        referenceDate = Self.date(day: 20, calendar: calendar)

        let suiteName = "FlowPlanTests.OverdueBills.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        self.userDefaults = userDefaults

        let container = try PersistenceController.inMemory()
        self.container = container
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
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
        appState.recordAutopayAutomatically = false
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
        isPaidThroughBills: Bool = false
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
                dueDay: dueDay,
                isAutoPay: isAutoPay,
                isPaidThroughBills: isPaidThroughBills
            )
        )
        return id
    }

    func unsettledOccurrences() -> [BillOccurrence] {
        UpcomingBillsSection.unsettledOccurrences(
            repository: repository,
            month: month,
            relativeTo: referenceDate,
            calendar: calendar
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
