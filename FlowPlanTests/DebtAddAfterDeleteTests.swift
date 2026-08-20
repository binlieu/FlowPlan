import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

/// Reported from a device: after deleting a debt, adding another one "doesn't add".
/// Reproduces the exact reported sequence — add, delete, add again.
@Test
@MainActor
func addingADebtAfterDeletingOneSucceeds() throws {
    let container = try PersistenceController.inMemory()
    let repository = FinanceRepository(context: container.mainContext)

    let first = DebtEntity(
        name: "BoF Loan",
        currentBalance: 728,
        annualInterestRate: 0,
        monthlyPayment: 672,
        category: "Loan",
        dueDay: 1,
        isPaidThroughBills: false,
        isActive: true
    )
    try repository.addDebt(first)
    #expect(repository.debts().count == 1)

    try repository.deleteDebt(id: first.id)
    #expect(repository.debts().isEmpty)

    let second = DebtEntity(
        name: "Auto Loan",
        currentBalance: 12_000,
        annualInterestRate: 0,
        monthlyPayment: 450,
        category: "Loan",
        dueDay: 1,
        isPaidThroughBills: false,
        isActive: true
    )
    try repository.addDebt(second)

    #expect(repository.debts().count == 1)
    #expect(repository.debts().first?.name == "Auto Loan")
}

/// The reported record reused the same category as the deleted one, which routes through
/// canonicalCategory and fetches across four entity types.
@Test
@MainActor
func addingTwoDebtsInARowSucceeds() throws {
    let container = try PersistenceController.inMemory()
    let repository = FinanceRepository(context: container.mainContext)

    try repository.addDebt(
        DebtEntity(
            name: "First",
            currentBalance: 728,
            annualInterestRate: 0,
            monthlyPayment: 672,
            category: "Loan",
            dueDay: 1,
            isPaidThroughBills: false,
            isActive: true
        )
    )
    try repository.addDebt(
        DebtEntity(
            name: "Second",
            currentBalance: 5_000,
            annualInterestRate: 0.05,
            monthlyPayment: 200,
            category: "Loan",
            dueDay: 15,
            isPaidThroughBills: false,
            isActive: true
        )
    )

    #expect(repository.debts().count == 2)
}
