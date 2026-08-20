import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test(arguments: RepositoryWriteOperation.allCases)
@MainActor
func everySuccessfulRepositoryWriteBumpsDataVersion(
    _ operation: RepositoryWriteOperation
) throws {
    let environment = try RepositoryDataVersionEnvironment()
    let versionChange = try operation.perform(in: environment)

    #expect(versionChange.after == versionChange.before + 1)
}

@Test
@MainActor
func failedRepositoryWriteDoesNotBumpDataVersionAndRollsBack() throws {
    let environment = try RepositoryDataVersionEnvironment()
    let transactionID = UUID()

    try environment.repository.addTransaction(
        environment.transaction(id: transactionID, detail: "Original")
    )

    let storedTransaction = try #require(
        try environment.container.mainContext.fetch(FetchDescriptor<TransactionEntity>()).first
    )
    storedTransaction.amount = 900
    storedTransaction.settlesDebtID = UUID()
    let versionBeforeFailure = environment.projectionStore.dataVersion

    #expect(throws: FinanceRepositoryError.settlementMustUseDedicatedMethod) {
        try environment.repository.updateTransaction(storedTransaction)
    }

    #expect(environment.projectionStore.dataVersion == versionBeforeFailure)
    let transactionAfterFailure = try #require(
        environment.repository.transactions(in: environment.month).first {
            $0.id == transactionID
        }
    )
    #expect(transactionAfterFailure.amount == 100)
    #expect(transactionAfterFailure.settlesDebtID == nil)
}

@Test
@MainActor
func paidThroughBillsDebtKeepsProjectionBalanceAndBumpsDataVersion() throws {
    let environment = try RepositoryDataVersionEnvironment()
    let balanceBeforeWrite = environment.projectionStore.projection.projectedEndOfMonthBalance
    let versionBeforeWrite = environment.projectionStore.dataVersion

    try environment.repository.addDebt(
        environment.debt(isPaidThroughBills: true)
    )
    environment.projectionStore.refresh()

    #expect(
        environment.projectionStore.projection.projectedEndOfMonthBalance
            == balanceBeforeWrite
    )
    #expect(environment.projectionStore.dataVersion == versionBeforeWrite + 1)
}

@Test
@MainActor
func deactivatingDebtBumpsDataVersion() throws {
    let environment = try RepositoryDataVersionEnvironment()
    let debtID = UUID()
    try environment.repository.addDebt(environment.debt(id: debtID))
    let versionBeforeWrite = environment.projectionStore.dataVersion

    try environment.repository.updateDebt(
        environment.debt(id: debtID, name: "Inactive debt", isActive: false)
    )

    #expect(environment.projectionStore.dataVersion == versionBeforeWrite + 1)
    #expect(environment.repository.debts().first?.isActive == false)
}

enum RepositoryWriteOperation: String, CaseIterable, CustomStringConvertible {
    case addAccount
    case deleteAccount
    case addTransaction
    case updateTransaction
    case deleteTransaction
    case addIncomeSource
    case updateIncomeSource
    case deleteIncomeSource
    case addBill
    case updateBill
    case deleteBill
    case addDebt
    case updateDebt
    case deleteDebt
    case addBudget
    case updateBudget
    case deleteBudget
    case addSavingsGoal
    case updateSavingsGoal
    case deleteSavingsGoal
    case addStartingBalance
    case updateStartingBalance
    case deleteStartingBalance
    case settleBill
    case settleDebt
    case settleIncome
    case settleSpecificIncomeOccurrence

    var description: String { rawValue }

    @MainActor
    func perform(
        in environment: RepositoryDataVersionEnvironment
    ) throws -> (before: Int, after: Int) {
        let repository = environment.repository
        let id = UUID()
        let write: () throws -> Void

        switch self {
        case .addAccount:
            write = { try repository.addAccount(named: "Checking") }
        case .deleteAccount:
            try repository.addAccount(named: "Checking")
            let account = try #require(repository.accounts().first)
            write = { try repository.deleteAccount(account) }
        case .addTransaction:
            write = {
                try repository.addTransaction(environment.transaction(id: id))
            }
        case .updateTransaction:
            try repository.addTransaction(environment.transaction(id: id))
            write = {
                try repository.updateTransaction(
                    environment.transaction(id: id, detail: "Updated transaction")
                )
            }
        case .deleteTransaction:
            try repository.addTransaction(environment.transaction(id: id))
            write = { try repository.deleteTransaction(id: id) }
        case .addIncomeSource:
            write = {
                try repository.addIncomeSource(environment.incomeSource(id: id))
            }
        case .updateIncomeSource:
            try repository.addIncomeSource(environment.incomeSource(id: id))
            write = {
                try repository.updateIncomeSource(
                    environment.incomeSource(id: id, name: "Updated income")
                )
            }
        case .deleteIncomeSource:
            try repository.addIncomeSource(environment.incomeSource(id: id))
            write = { try repository.deleteIncomeSource(id: id) }
        case .addBill:
            write = { try repository.addBill(environment.bill(id: id)) }
        case .updateBill:
            try repository.addBill(environment.bill(id: id))
            write = {
                try repository.updateBill(environment.bill(id: id, name: "Updated bill"))
            }
        case .deleteBill:
            try repository.addBill(environment.bill(id: id))
            write = { try repository.deleteBill(id: id) }
        case .addDebt:
            write = { try repository.addDebt(environment.debt(id: id)) }
        case .updateDebt:
            try repository.addDebt(environment.debt(id: id))
            write = {
                try repository.updateDebt(environment.debt(id: id, name: "Updated debt"))
            }
        case .deleteDebt:
            try repository.addDebt(environment.debt(id: id))
            write = { try repository.deleteDebt(id: id) }
        case .addBudget:
            write = { try repository.addBudget(environment.budget(id: id)) }
        case .updateBudget:
            try repository.addBudget(environment.budget(id: id))
            write = {
                try repository.updateBudget(
                    environment.budget(id: id, category: "Updated budget")
                )
            }
        case .deleteBudget:
            try repository.addBudget(environment.budget(id: id))
            write = { try repository.deleteBudget(id: id) }
        case .addSavingsGoal:
            write = {
                try repository.addSavingsGoal(environment.savingsGoal(id: id))
            }
        case .updateSavingsGoal:
            try repository.addSavingsGoal(environment.savingsGoal(id: id))
            write = {
                try repository.updateSavingsGoal(
                    environment.savingsGoal(id: id, name: "Updated savings goal")
                )
            }
        case .deleteSavingsGoal:
            try repository.addSavingsGoal(environment.savingsGoal(id: id))
            write = { try repository.deleteSavingsGoal(id: id) }
        case .addStartingBalance:
            write = {
                try repository.setStartingBalance(1_000, for: environment.month)
            }
        case .updateStartingBalance:
            try repository.setStartingBalance(1_000, for: environment.month)
            write = {
                try repository.setStartingBalance(1_200, for: environment.month)
            }
        case .deleteStartingBalance:
            try repository.setStartingBalance(1_000, for: environment.month)
            write = {
                try repository.deleteStartingBalance(for: environment.month)
            }
        case .settleBill:
            try repository.addBill(environment.bill(id: id))
            write = {
                try repository.markBillPaid(
                    billID: id,
                    occurrence: environment.date,
                    amount: 100,
                    on: environment.date
                )
            }
        case .settleDebt:
            try repository.addDebt(environment.debt(id: id))
            write = {
                try repository.markDebtPaymentMade(
                    debtID: id,
                    amount: 100,
                    on: environment.date
                )
            }
        case .settleIncome:
            try repository.addIncomeSource(environment.incomeSource(id: id))
            write = {
                try repository.markIncomeReceived(
                    incomeID: id,
                    amount: 100,
                    on: environment.date
                )
            }
        case .settleSpecificIncomeOccurrence:
            try repository.addIncomeSource(environment.incomeSource(id: id))
            write = {
                try repository.markIncomeReceived(
                    incomeID: id,
                    occurrence: environment.date,
                    amount: 100,
                    on: environment.date
                )
            }
        }

        let versionBeforeWrite = environment.projectionStore.dataVersion
        try write()
        return (versionBeforeWrite, environment.projectionStore.dataVersion)
    }
}

@MainActor
struct RepositoryDataVersionEnvironment {
    let month = MonthKey(year: 2026, month: 8)
    let calendar: Calendar
    let date: Date
    let container: ModelContainer
    let repository: FinanceRepository
    let projectionStore: ProjectionStore

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = month.year
        components.month = month.month
        components.day = 5
        components.hour = 12
        let referenceDate = try #require(calendar.date(from: components))
        date = referenceDate

        let container = try PersistenceController.inMemory()
        self.container = container
        let defaults = try Self.makeDefaults()
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: calendar,
            userDefaults: defaults,
            now: { referenceDate }
        )
        let appState = AppState(
            selectedMonth: month,
            calendar: calendar,
            userDefaults: defaults,
            now: { referenceDate }
        )
        self.repository = repository
        projectionStore = ProjectionStore(
            repository: repository,
            appState: appState,
            modelContext: container.mainContext
        )
    }

    func transaction(id: UUID, detail: String = "Transaction") -> TransactionEntity {
        TransactionEntity(
            id: id,
            date: date,
            amount: 100,
            type: .expense,
            category: "Other",
            detail: detail
        )
    }

    func incomeSource(id: UUID, name: String = "Income") -> IncomeSourceEntity {
        IncomeSourceEntity(
            id: id,
            name: name,
            expectedAmount: 1_000,
            frequency: .monthly,
            anchorDate: date
        )
    }

    func bill(id: UUID, name: String = "Bill") -> RecurringBillEntity {
        RecurringBillEntity(
            id: id,
            name: name,
            amount: 100,
            amountType: .fixed,
            category: "Utilities",
            frequency: .monthly,
            anchorDate: date
        )
    }

    func debt(
        id: UUID = UUID(),
        name: String = "Debt",
        isPaidThroughBills: Bool = false,
        isActive: Bool = true
    ) -> DebtEntity {
        DebtEntity(
            id: id,
            name: name,
            currentBalance: 2_000,
            annualInterestRate: 10,
            monthlyPayment: 100,
            category: "Debt",
            dueDay: 5,
            isPaidThroughBills: isPaidThroughBills,
            isActive: isActive
        )
    }

    func budget(id: UUID, category: String = "Groceries") -> BudgetEntity {
        BudgetEntity(id: id, category: category, monthlyLimit: 500)
    }

    func savingsGoal(id: UUID, name: String = "Emergency fund") -> SavingsGoalEntity {
        SavingsGoalEntity(
            id: id,
            name: name,
            targetAmount: 10_000,
            monthlyTarget: 500
        )
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "FlowPlanTests.RepositoryDataVersion.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
