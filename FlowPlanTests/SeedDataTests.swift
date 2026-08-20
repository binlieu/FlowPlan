import Foundation
import SwiftData
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
@MainActor
func sampleSeedIsIdempotentAndMatchesTheAugustBrief() throws {
    let container = try PersistenceController.inMemory()
    let context = container.mainContext
    let calendar = seedTestCalendar
    let month = MonthKey(year: 2026, month: 8)

    #expect(!SampleData.isSeeded(context))
    try SampleData.seed(into: context, calendar: calendar)
    try SampleData.seed(into: context, calendar: calendar)
    #expect(SampleData.isSeeded(context))

    #expect(try context.fetchCount(FetchDescriptor<IncomeSourceEntity>()) == 3)
    #expect(try context.fetchCount(FetchDescriptor<RecurringBillEntity>()) == 6)
    #expect(try context.fetchCount(FetchDescriptor<BudgetEntity>()) == 6)
    #expect(try context.fetchCount(FetchDescriptor<SavingsGoalEntity>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MonthSettingsEntity>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<TransactionEntity>()) == 15)

    let repository = FinanceRepository(context: context, calendar: calendar)
    let incomes = repository.incomeSources()
    let bills = repository.bills()
    let budgets = repository.budgets(for: month)
    let savingsPlans = repository.savingsPlans()
    let transactions = repository.transactions(in: month)

    #expect(Dictionary(uniqueKeysWithValues: incomes.map { ($0.name, $0.expectedAmount) }) == [
        "Salary": 6_500,
        "Side Income": 1_200,
        "Rental Income": 800
    ])
    #expect(bills.map(\.amount).reduce(.zero, +) == seedDecimal("2392.98"))
    #expect(Dictionary(uniqueKeysWithValues: budgets.map { ($0.category, $0.monthlyLimit) }) == [
        "Groceries": 800,
        "Dining": 300,
        "Gas": 250,
        "Shopping": 300,
        "Entertainment": 150,
        "Miscellaneous": 250
    ])
    #expect(savingsPlans.map(\.monthlyTarget).reduce(.zero, +) == 2_000)
    #expect(repository.startingBalance(for: month) == 2_400)

    let discretionary = transactions.filter {
        $0.type == .expense && $0.settlesBillID == nil
    }
    let spendingByCategory = Dictionary(grouping: discretionary, by: \.category)
        .mapValues { transactions in
            transactions.map(\.amount).reduce(.zero, +)
        }

    #expect(spendingByCategory == [
        "Groceries": 720,
        "Dining": 260,
        "Gas": 190,
        "Shopping": 490,
        "Entertainment": 140,
        "Other": 210
    ])
    #expect(transactions.count { $0.settlesIncomeID != nil } == 1)
    #expect(transactions.count { $0.settlesBillID != nil } == 1)
}

private var seedTestCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func seedDecimal(_ value: String) -> Decimal {
    Decimal(string: value) ?? .zero
}
