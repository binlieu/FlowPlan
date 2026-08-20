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
        projectionStore = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: container.mainContext
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
