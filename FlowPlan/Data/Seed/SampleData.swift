import Foundation
import SwiftData
import FlowPlanDomain

enum SampleData {
    private static let salaryID = id(1)
    private static let sideIncomeID = id(2)
    private static let rentalIncomeID = id(3)
    private static let mortgageID = id(11)

    static func seed(into context: ModelContext, calendar: Calendar) throws {
        guard !isSeeded(context) else {
            return
        }

        let timestamp = try date(day: 1, calendar: calendar)
        let salaryDate = try date(day: 1, calendar: calendar)
        let mortgageDate = try date(day: 3, calendar: calendar)

        let incomeSources = [
            IncomeSourceEntity(
                id: salaryID,
                name: "Salary",
                expectedAmount: 6_500,
                frequency: .monthly,
                anchorDate: salaryDate,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            IncomeSourceEntity(
                id: sideIncomeID,
                name: "Side Income",
                expectedAmount: 1_200,
                frequency: .monthly,
                anchorDate: try date(day: 15, calendar: calendar),
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            IncomeSourceEntity(
                id: rentalIncomeID,
                name: "Rental Income",
                expectedAmount: 800,
                frequency: .monthly,
                anchorDate: try date(day: 5, calendar: calendar),
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]

        let bills = [
            RecurringBillEntity(
                id: mortgageID,
                name: "Mortgage",
                amount: 1_850,
                amountType: .fixed,
                category: "Housing",
                frequency: .monthly,
                anchorDate: mortgageDate,
                isAutoPay: true,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            RecurringBillEntity(
                id: id(12),
                name: "Electric",
                amount: 145,
                amountType: .estimated,
                category: "Utilities",
                frequency: .monthly,
                anchorDate: try date(day: 10, calendar: calendar),
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            RecurringBillEntity(
                id: id(13),
                name: "Internet",
                amount: 89.99,
                amountType: .fixed,
                category: "Utilities",
                frequency: .monthly,
                anchorDate: try date(day: 12, calendar: calendar),
                isAutoPay: true,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            RecurringBillEntity(
                id: id(14),
                name: "Phone",
                amount: 120,
                amountType: .fixed,
                category: "Utilities",
                frequency: .monthly,
                anchorDate: try date(day: 18, calendar: calendar),
                isAutoPay: true,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            RecurringBillEntity(
                id: id(15),
                name: "Insurance",
                amount: 165,
                amountType: .fixed,
                category: "Insurance",
                frequency: .monthly,
                anchorDate: try date(day: 20, calendar: calendar),
                isAutoPay: true,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            RecurringBillEntity(
                id: id(16),
                name: "Netflix",
                amount: 22.99,
                amountType: .fixed,
                category: "Entertainment",
                frequency: .monthly,
                anchorDate: try date(day: 23, calendar: calendar),
                isAutoPay: true,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]

        let budgets = [
            BudgetEntity(id: id(21), category: "Groceries", monthlyLimit: 800, createdAt: timestamp, updatedAt: timestamp),
            BudgetEntity(id: id(22), category: "Dining", monthlyLimit: 300, createdAt: timestamp, updatedAt: timestamp),
            BudgetEntity(id: id(23), category: "Gas", monthlyLimit: 250, createdAt: timestamp, updatedAt: timestamp),
            BudgetEntity(id: id(24), category: "Shopping", monthlyLimit: 300, createdAt: timestamp, updatedAt: timestamp),
            BudgetEntity(id: id(25), category: "Entertainment", monthlyLimit: 150, createdAt: timestamp, updatedAt: timestamp),
            BudgetEntity(id: id(26), category: "Miscellaneous", monthlyLimit: 250, createdAt: timestamp, updatedAt: timestamp)
        ]

        let savingsGoal = SavingsGoalEntity(
            id: id(31),
            name: "Monthly Savings",
            targetAmount: 24_000,
            monthlyTarget: 2_000,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let monthSettings = MonthSettingsEntity(
            id: id(32),
            year: 2026,
            month: 8,
            startingBalance: 2_400,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let transactions = [
            TransactionEntity(
                id: id(41),
                date: salaryDate,
                amount: 6_500,
                type: .income,
                category: "Income",
                detail: "Salary",
                settlesIncomeID: salaryID,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            TransactionEntity(
                id: id(42),
                date: mortgageDate,
                amount: 1_850,
                type: .expense,
                category: "Housing",
                detail: "Mortgage",
                settlesBillID: mortgageID,
                createdAt: timestamp,
                updatedAt: timestamp
            ),
            try expense(id: 43, day: 2, amount: 180, category: "Groceries", detail: "Grocery store", timestamp: timestamp, calendar: calendar),
            try expense(id: 44, day: 9, amount: 160, category: "Groceries", detail: "Weekly groceries", timestamp: timestamp, calendar: calendar),
            try expense(id: 45, day: 16, amount: 210, category: "Groceries", detail: "Grocery store", timestamp: timestamp, calendar: calendar),
            try expense(id: 46, day: 24, amount: 170, category: "Groceries", detail: "Weekly groceries", timestamp: timestamp, calendar: calendar),
            try expense(id: 47, day: 4, amount: 80, category: "Dining", detail: "Dinner", timestamp: timestamp, calendar: calendar),
            try expense(id: 48, day: 13, amount: 95, category: "Dining", detail: "Lunches", timestamp: timestamp, calendar: calendar),
            try expense(id: 49, day: 27, amount: 85, category: "Dining", detail: "Dinner", timestamp: timestamp, calendar: calendar),
            try expense(id: 50, day: 7, amount: 90, category: "Gas", detail: "Fuel", timestamp: timestamp, calendar: calendar),
            try expense(id: 51, day: 21, amount: 100, category: "Gas", detail: "Fuel", timestamp: timestamp, calendar: calendar),
            try expense(id: 52, day: 11, amount: 240, category: "Shopping", detail: "Household items", timestamp: timestamp, calendar: calendar),
            try expense(id: 53, day: 25, amount: 250, category: "Shopping", detail: "Clothing", timestamp: timestamp, calendar: calendar),
            try expense(id: 54, day: 19, amount: 140, category: "Entertainment", detail: "Event tickets", timestamp: timestamp, calendar: calendar),
            try expense(id: 55, day: 29, amount: 210, category: "Other", detail: "Miscellaneous expense", timestamp: timestamp, calendar: calendar)
        ]

        incomeSources.forEach(context.insert)
        bills.forEach(context.insert)
        budgets.forEach(context.insert)
        context.insert(savingsGoal)
        context.insert(monthSettings)
        transactions.forEach(context.insert)
        try context.save()
    }

    static func isSeeded(_ context: ModelContext) -> Bool {
        let seededID = salaryID
        let predicate = #Predicate<IncomeSourceEntity> { source in
            source.id == seededID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetchCount(descriptor)) == 1
    }

    private static func expense(
        id idValue: UInt8,
        day: Int,
        amount: Decimal,
        category: String,
        detail: String,
        timestamp: Date,
        calendar: Calendar
    ) throws -> TransactionEntity {
        TransactionEntity(
            id: id(idValue),
            date: try date(day: day, calendar: calendar),
            amount: amount,
            type: .expense,
            category: category,
            detail: detail,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func date(day: Int, calendar: Calendar) throws -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = 12

        guard let value = calendar.date(from: components) else {
            throw SeedError.invalidDate
        }
        return value
    }

    private static func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, value))
    }
}

private enum SeedError: Error {
    case invalidDate
}
