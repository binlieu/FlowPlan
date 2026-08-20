import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func debtEntityRoundTripsAndPreservesOriginalBalance() throws {
    let environment = try DebtRepositoryEnvironment()
    let debtID = UUID()

    try environment.repository.addDebt(
        DebtEntity(
            id: debtID,
            name: "Auto Loan",
            currentBalance: 18_500,
            annualInterestRate: 0.0649,
            monthlyPayment: 505,
            category: "Transportation",
            dueDay: 23,
            isPaidThroughBills: false
        )
    )

    let debt = try #require(environment.repository.debts().first)
    #expect(debt.id == debtID)
    #expect(debt.currentBalance == 18_500)
    #expect(debt.annualInterestRate == 0.0649)
    #expect(debt.monthlyPayment == 505)
    #expect(debt.dueDay == 23)
    #expect(!debt.isPaidThroughBills)
    #expect(environment.repository.debtOriginalBalances()[debtID] == 18_500)
}

@Test
@MainActor
func debtCanBeUpdatedAndDeletedWithoutDeletingItsPayment() throws {
    let environment = try DebtRepositoryEnvironment()
    let debtID = UUID()
    try environment.repository.addDebt(
        DebtEntity(
            id: debtID,
            name: "Auto Loan",
            currentBalance: 1_000,
            annualInterestRate: .zero,
            monthlyPayment: 100,
            category: "Transportation",
            isPaidThroughBills: false
        )
    )

    try environment.repository.updateDebt(
        DebtEntity(
            id: debtID,
            name: "Updated Auto Loan",
            currentBalance: 900,
            annualInterestRate: 0.05,
            monthlyPayment: 125,
            category: "Auto",
            isPaidThroughBills: true,
            isActive: false
        )
    )
    let updated = try #require(environment.repository.debts().first)
    #expect(updated.name == "Updated Auto Loan")
    #expect(updated.monthlyPayment == 125)
    #expect(updated.isPaidThroughBills)
    #expect(!updated.isActive)

    try environment.repository.markDebtPaymentMade(
        debtID: debtID,
        amount: 125,
        on: environment.date(day: 12)
    )
    try environment.repository.deleteDebt(id: debtID)

    #expect(environment.repository.debts().isEmpty)
    let preservedPayment = try #require(
        environment.repository.transactions(in: environment.month).first
    )
    #expect(preservedPayment.settlesDebtID == nil)
}

@Test
@MainActor
func markingDebtPaymentReducesPrincipalAndCannotDuplicateTheMonth() throws {
    let environment = try DebtRepositoryEnvironment()
    let debtID = UUID()
    try environment.repository.addDebt(
        DebtEntity(
            id: debtID,
            name: "Auto Loan",
            currentBalance: 1_200,
            annualInterestRate: 0.12,
            monthlyPayment: 200,
            category: "Transportation",
            isPaidThroughBills: false
        )
    )
    try environment.repository.setStartingBalance(2_000, for: environment.month)

    let engine = MonthlyProjectionEngine()
    let before = engine.project(environment.projectionInput())
    try environment.repository.markDebtPaymentMade(
        debtID: debtID,
        amount: 200,
        on: environment.date(day: 12)
    )
    let after = engine.project(environment.projectionInput())

    let storedDebt = try #require(environment.repository.debts().first)
    let linkedPayments = environment.repository.transactions(in: environment.month).filter {
        $0.settlesDebtID == debtID
    }
    #expect(storedDebt.currentBalance == 1_012)
    #expect(linkedPayments.count == 1)
    #expect(after.debtPaymentsMade == 200)
    #expect(after.remainingDebtPayments == .zero)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)

    #expect(throws: FinanceRepositoryError.settlementAlreadyRecorded) {
        try environment.repository.markDebtPaymentMade(
            debtID: debtID,
            amount: 200,
            on: environment.date(day: 20)
        )
    }
}

@Test
@MainActor
func finalDebtPaymentKeepsProjectionStableAfterBalanceReachesZero() throws {
    let environment = try DebtRepositoryEnvironment()
    let debtID = UUID()
    try environment.repository.addDebt(
        DebtEntity(
            id: debtID,
            name: "Small Loan",
            currentBalance: 85.42,
            annualInterestRate: .zero,
            monthlyPayment: 200,
            category: "Other",
            isPaidThroughBills: false
        )
    )
    try environment.repository.setStartingBalance(500, for: environment.month)

    let engine = MonthlyProjectionEngine()
    let before = engine.project(environment.projectionInput())
    try environment.repository.markDebtPaymentMade(
        debtID: debtID,
        amount: 85.42,
        on: environment.date(day: 12)
    )
    let after = engine.project(environment.projectionInput())

    #expect(environment.repository.debts().first?.currentBalance == .zero)
    #expect(after.debtPaymentsDue == 85.42)
    #expect(after.projectedEndOfMonthBalance == before.projectedEndOfMonthBalance)
}

@Test
@MainActor
func repositoryDebtPaidThroughBillsIsProjectionNeutral() throws {
    let environment = try DebtRepositoryEnvironment()
    try environment.repository.setStartingBalance(2_000, for: environment.month)
    let engine = MonthlyProjectionEngine()
    let before = engine.project(environment.projectionInput())

    try environment.repository.addDebt(
        DebtEntity(
            name: "Mortgage",
            currentBalance: 250_000,
            annualInterestRate: 0.0649,
            monthlyPayment: 1_850,
            category: "Housing",
            isPaidThroughBills: true
        )
    )
    let after = engine.project(environment.projectionInput())

    #expect(after == before)
}

@MainActor
private struct DebtRepositoryEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let calendar: Calendar
    let container: ModelContainer
    let repository: FinanceRepository

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar

        let container = try PersistenceController.inMemory()
        self.container = container
        repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
            now: { Self.date(day: 20, calendar: calendar) }
        )
    }

    func date(day: Int) -> Date {
        Self.date(day: day, calendar: calendar)
    }

    func projectionInput() -> ProjectionInput {
        repository.projectionInput(
            for: month,
            referenceDate: date(day: 20),
            configuration: .default
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
