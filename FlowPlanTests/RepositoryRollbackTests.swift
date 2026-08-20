import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func rejectedWriteRollsBackBeforeAnUnrelatedValidWrite() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let repository = FinanceRepository(
        context: context,
        calendar: rollbackTestCalendar,
        userDefaults: try isolatedTestUserDefaults()
    )
    let transactionID = UUID()

    try repository.addTransaction(
        TransactionEntity(
            id: transactionID,
            date: rollbackTestDate(day: 10),
            amount: 100,
            type: .expense,
            category: "Other",
            detail: "Original"
        )
    )

    let storedTransaction = try #require(
        try context.fetch(FetchDescriptor<TransactionEntity>()).first
    )
    storedTransaction.amount = 900
    storedTransaction.settlesDebtID = UUID()

    #expect(throws: FinanceRepositoryError.settlementMustUseDedicatedMethod) {
        try repository.updateTransaction(storedTransaction)
    }

    let transactionAfterFailure = try #require(
        repository.transactions(in: MonthKey(year: 2026, month: 8)).first {
            $0.id == transactionID
        }
    )
    #expect(transactionAfterFailure.amount == 100)
    #expect(transactionAfterFailure.settlesDebtID == nil)

    try repository.addAccount(named: "Checking")

    #expect(repository.accounts().map(\.name) == ["Checking"])
    let transactionAfterValidWrite = try #require(
        repository.transactions(in: MonthKey(year: 2026, month: 8)).first {
            $0.id == transactionID
        }
    )
    #expect(transactionAfterValidWrite.amount == 100)
    #expect(transactionAfterValidWrite.settlesDebtID == nil)
}

@Test
func failedDeletePresentationNamesDeleteAndIncludesUnderlyingError() {
    let presentation = WriteErrorPresentation(
        operation: .delete,
        subject: "debt",
        error: RollbackPresentationTestError.storeUnavailable
    )

    #expect(presentation.title == "Couldn't delete this debt")
    #expect(!presentation.title.localizedCaseInsensitiveContains("save"))
    #expect(presentation.message.contains("The store is unavailable."))
}

private enum RollbackPresentationTestError: LocalizedError {
    case storeUnavailable

    var errorDescription: String? {
        "The store is unavailable."
    }
}

private var rollbackTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func rollbackTestDate(day: Int) -> Date {
    var components = DateComponents()
    components.calendar = rollbackTestCalendar
    components.timeZone = rollbackTestCalendar.timeZone
    components.year = 2026
    components.month = 8
    components.day = day
    components.hour = 12
    return rollbackTestCalendar.date(from: components) ?? .distantPast
}
