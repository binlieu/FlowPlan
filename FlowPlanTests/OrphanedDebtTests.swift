import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
func paidThroughBillsDebtWithoutBillsIsOrphanedAndDoesNotChangeProjection() {
    let calendar = orphanTestCalendar
    let debt = orphanTestDebt()
    let input = ProjectionInput(
        month: MonthKey(year: 2026, month: 8),
        referenceDate: orphanTestDate(day: 20, calendar: calendar),
        startingBalance: 2_000,
        debts: [debt],
        calendar: calendar
    )
    let engine = MonthlyProjectionEngine()
    let before = engine.project(input)

    let isOrphaned = OrphanedDebtDetector.isOrphaned(
        debt,
        bills: [],
        calendar: calendar
    )

    let after = engine.project(input)
    #expect(isOrphaned)
    #expect(after == before)
}

@Test
func activeBillWithCaseInsensitiveDebtNamePreventsOrphan() {
    let calendar = orphanTestCalendar
    let debt = orphanTestDebt(name: "Tundra")
    let bill = orphanTestBill(
        name: "tUnDrA",
        amount: 1,
        dueDay: 28,
        calendar: calendar
    )

    #expect(!OrphanedDebtDetector.isOrphaned(debt, bills: [bill], calendar: calendar))
}

@Test
func activeBillWithMatchingAmountAndDueDayPreventsOrphan() {
    let calendar = orphanTestCalendar
    let debt = orphanTestDebt(name: "Tundra", monthlyPayment: 500, dueDay: 1)
    let bill = orphanTestBill(
        name: "Vehicle payment",
        amount: 500,
        dueDay: 1,
        calendar: calendar
    )

    #expect(!OrphanedDebtDetector.isOrphaned(debt, bills: [bill], calendar: calendar))
}

@Test
func inactiveOrSeparatelyPaidDebtIsNeverOrphaned() {
    let calendar = orphanTestCalendar
    let inactiveDebt = orphanTestDebt(isActive: false)
    let separatelyPaidDebt = orphanTestDebt(isPaidThroughBills: false)

    #expect(OrphanedDebtDetector.orphanedDebts(
        in: [inactiveDebt, separatelyPaidDebt],
        bills: [],
        calendar: calendar
    ).isEmpty)
}

@Test
func inactiveMatchingBillDoesNotPreventOrphan() {
    let calendar = orphanTestCalendar
    let debt = orphanTestDebt()
    let inactiveBill = orphanTestBill(
        name: debt.name,
        amount: debt.monthlyPayment,
        dueDay: debt.dueDay,
        isActive: false,
        calendar: calendar
    )

    #expect(OrphanedDebtDetector.isOrphaned(
        debt,
        bills: [inactiveBill],
        calendar: calendar
    ))
}

@Test
@MainActor
func countSeparatelyActionIncludesPaymentAndLowersProjection() throws {
    let calendar = orphanTestCalendar
    let month = MonthKey(year: 2026, month: 8)
    let container = try PersistenceController.inMemory()
    let repository = FinanceRepository(
        context: container.mainContext,
        calendar: calendar,
        userDefaults: try isolatedTestUserDefaults(),
        now: { orphanTestDate(day: 20, calendar: calendar) }
    )
    try repository.setStartingBalance(2_000, for: month)
    try repository.addDebt(
        DebtEntity(
            name: "Tundra",
            currentBalance: 32_081,
            annualInterestRate: 0.0399,
            monthlyPayment: 500,
            category: "Debt",
            dueDay: 1,
            isAutoPay: true,
            isPaidThroughBills: true
        )
    )

    let engine = MonthlyProjectionEngine()
    let before = engine.project(repository.projectionInput(
        for: month,
        referenceDate: orphanTestDate(day: 20, calendar: calendar),
        configuration: .default
    ))
    let debt = try #require(repository.debts().first)
    #expect(OrphanedDebtDetector.isOrphaned(debt, bills: [], calendar: calendar))
    #expect(before.remainingDebtPayments == .zero)

    try repository.setDebtPaidThroughBills(id: debt.id, isPaidThroughBills: false)

    let after = engine.project(repository.projectionInput(
        for: month,
        referenceDate: orphanTestDate(day: 20, calendar: calendar),
        configuration: .default
    ))
    #expect(after.remainingDebtPayments == 500)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance - 500)
}

private func orphanTestDebt(
    name: String = "Tundra",
    monthlyPayment: Decimal = 500,
    dueDay: Int = 1,
    isPaidThroughBills: Bool = true,
    isActive: Bool = true
) -> Debt {
    Debt(
        id: UUID(),
        name: name,
        currentBalance: 32_081,
        annualInterestRate: 0.0399,
        monthlyPayment: monthlyPayment,
        category: "Debt",
        dueDay: dueDay,
        isAutoPay: true,
        isPaidThroughBills: isPaidThroughBills,
        isActive: isActive
    )
}

private func orphanTestBill(
    name: String,
    amount: Decimal,
    dueDay: Int,
    isActive: Bool = true,
    calendar: Calendar
) -> PlannedBill {
    PlannedBill(
        id: UUID(),
        name: name,
        amount: amount,
        amountType: .fixed,
        category: "Debt",
        recurrence: RecurrenceRule(
            frequency: .monthly,
            anchorDate: orphanTestDate(day: dueDay, calendar: calendar)
        ),
        isAutoPay: true,
        isActive: isActive
    )
}

private var orphanTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func orphanTestDate(day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = 2026
    components.month = 8
    components.day = day
    components.hour = 12
    return calendar.date(from: components) ?? .distantPast
}
