import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func debtDefaultsAndRequiredFieldMessagesAreExplicit() throws {
    #expect(PlanEditorValidation.optionalDebtAPRPercentage("") == .zero)
    #expect(PlanEditorValidation.debtCategory("   ") == "Debt")
    #expect(
        PlanEditorValidation.requiredText("", message: "Enter a debt name.")
            == "Enter a debt name."
    )
    #expect(
        PlanEditorValidation.nonnegativeAmount(
            "-1",
            message: "Enter a balance of zero or more."
        ) == "Enter a balance of zero or more."
    )
    #expect(
        PlanEditorValidation.positiveAmount("0", message: "Enter a monthly payment.")
            == "Enter a monthly payment."
    )

    let environment = try DebtDueDateTestEnvironment()
    let aprPercentage = try #require(PlanEditorValidation.optionalDebtAPRPercentage(""))
    try environment.repository.addDebt(
        DebtEntity(
            name: "Family loan",
            currentBalance: 1_000,
            annualInterestRate: aprPercentage / 100,
            monthlyPayment: 100,
            category: PlanEditorValidation.debtCategory(""),
            dueDay: 1,
            isPaidThroughBills: false
        )
    )

    let savedDebt = try #require(environment.repository.debts().first)
    #expect(savedDebt.annualInterestRate == .zero)
    #expect(savedDebt.category == "Debt")
    #expect(savedDebt.dueDay == 1)
}

@Test
@MainActor
func overdueDebtAppearsWithDateAndSettlementPreservesProjection() throws {
    let environment = try DebtDueDateTestEnvironment(startingBalance: 2_000)
    let debtID = UUID()
    try environment.repository.addDebt(
        DebtEntity(
            id: debtID,
            name: "Auto loan",
            currentBalance: 1_200,
            annualInterestRate: 0.12,
            monthlyPayment: 200,
            category: "Transportation",
            dueDay: 15,
            isPaidThroughBills: false
        )
    )
    environment.projectionStore.refresh()

    let before = environment.projectionStore.projection
    let payments = UpcomingBillsSection.paymentOccurrences(
        bills: [],
        debts: before.debtOccurrences,
        relativeTo: environment.referenceDate,
        calendar: environment.calendar
    )
    let payment = try #require(payments.first)
    let debtOccurrence = try #require(payment.debtOccurrence)

    #expect(payments.count == 1)
    #expect(debtOccurrence.debtID == debtID)
    #expect(environment.calendar.component(.day, from: payment.date) == 15)
    #expect(
        payment.status(
            relativeTo: environment.referenceDate,
            calendar: environment.calendar
        ) == .overdue
    )

    let settlementError = HomePaymentSettlementAction.markAsPaid(
        payment,
        repository: environment.repository,
        projectionStore: environment.projectionStore
    )

    let after = environment.projectionStore.projection
    #expect(settlementError == nil)
    #expect(after.remainingDebtPayments == .zero)
    #expect(after.debtPaymentsMade == 200)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
    #expect(after.debtOccurrences.isEmpty)
}

@Test
@MainActor
func debtPaidThroughBillsNeverAppearsInHomePayments() throws {
    let environment = try DebtDueDateTestEnvironment()
    try environment.repository.addDebt(
        DebtEntity(
            name: "Mortgage",
            currentBalance: 250_000,
            annualInterestRate: 0.06,
            monthlyPayment: 1_850,
            category: "Housing",
            dueDay: 1,
            isPaidThroughBills: true
        )
    )
    environment.projectionStore.refresh()

    let projection = environment.projectionStore.projection
    let payments = UpcomingBillsSection.paymentOccurrences(
        bills: [],
        debts: projection.debtOccurrences,
        relativeTo: environment.referenceDate,
        calendar: environment.calendar
    )

    #expect(projection.debtOccurrences.isEmpty)
    #expect(payments.isEmpty)
    #expect(projection.debtPaymentsDue == .zero)
}

@MainActor
private struct DebtDueDateTestEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let referenceDate: Date
    let calendar: Calendar
    let container: ModelContainer
    let repository: FinanceRepository
    let projectionStore: ProjectionStore

    init(startingBalance: Decimal = .zero) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        referenceDate = Self.date(day: 20, calendar: calendar)

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

        let suiteName = "FlowPlanTests.DebtDueDate.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
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
