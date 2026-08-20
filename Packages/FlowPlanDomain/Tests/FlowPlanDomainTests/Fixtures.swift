import Foundation
import FlowPlanDomain

enum Fixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static let month = MonthKey(year: 2026, month: 8)

    static func date(
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        date(2026, 8, day, hour: hour, minute: minute, second: second)
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid fixed test date")
        }

        return date
    }

    static func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    static func income(
        id: UUID = id(1),
        amount: Decimal,
        frequency: RecurrenceFrequency = .monthly,
        anchorDate: Date = date(5),
        endDate: Date? = nil,
        isActive: Bool = true
    ) -> PlannedIncome {
        PlannedIncome(
            id: id,
            name: "Salary",
            expectedAmount: amount,
            recurrence: RecurrenceRule(
                frequency: frequency,
                anchorDate: anchorDate,
                endDate: endDate
            ),
            isActive: isActive
        )
    }

    static func bill(
        id: UUID = id(2),
        amount: Decimal,
        category: String = "Housing",
        frequency: RecurrenceFrequency = .monthly,
        anchorDate: Date = date(10),
        endDate: Date? = nil,
        isActive: Bool = true
    ) -> PlannedBill {
        PlannedBill(
            id: id,
            name: "Bill",
            amount: amount,
            amountType: .fixed,
            category: category,
            recurrence: RecurrenceRule(
                frequency: frequency,
                anchorDate: anchorDate,
                endDate: endDate
            ),
            isAutoPay: false,
            isActive: isActive
        )
    }

    static func budget(
        id: UUID = id(3),
        category: String = "Food",
        limit: Decimal
    ) -> BudgetAllocation {
        BudgetAllocation(id: id, category: category, monthlyLimit: limit)
    }

    static func debt(
        id: UUID = id(7),
        balance: Decimal,
        annualInterestRate: Decimal = .zero,
        monthlyPayment: Decimal,
        dueDay: Int = 1,
        isPaidThroughBills: Bool = false,
        isActive: Bool = true
    ) -> Debt {
        Debt(
            id: id,
            name: "Car loan",
            currentBalance: balance,
            annualInterestRate: annualInterestRate,
            monthlyPayment: monthlyPayment,
            category: "Transportation",
            dueDay: dueDay,
            isPaidThroughBills: isPaidThroughBills,
            isActive: isActive
        )
    }

    static func savingsPlan(
        id: UUID = id(4),
        target: Decimal
    ) -> SavingsPlan {
        SavingsPlan(id: id, name: "Emergency fund", monthlyTarget: target)
    }

    static func transaction(
        id: UUID = id(5),
        date: Date = date(15),
        amount: Decimal,
        type: TransactionType,
        category: String = "",
        detail: String = "Test transaction",
        settlesBillID: UUID? = nil,
        settlesDebtID: UUID? = nil,
        settlesIncomeID: UUID? = nil
    ) -> TransactionSnapshot {
        TransactionSnapshot(
            id: id,
            date: date,
            amount: amount,
            type: type,
            category: category,
            detail: detail,
            settlesBillID: settlesBillID,
            settlesDebtID: settlesDebtID,
            settlesIncomeID: settlesIncomeID
        )
    }

    static func input(
        month: MonthKey = month,
        referenceDate: Date = date(17),
        startingBalance: Decimal = .zero,
        incomeSources: [PlannedIncome] = [],
        bills: [PlannedBill] = [],
        debts: [Debt] = [],
        budgets: [BudgetAllocation] = [],
        savingsPlans: [SavingsPlan] = [],
        transactions: [TransactionSnapshot] = [],
        configuration: ProjectionConfiguration = .default
    ) -> ProjectionInput {
        ProjectionInput(
            month: month,
            referenceDate: referenceDate,
            startingBalance: startingBalance,
            incomeSources: incomeSources,
            bills: bills,
            debts: debts,
            budgets: budgets,
            savingsPlans: savingsPlans,
            transactions: transactions,
            calendar: calendar,
            configuration: configuration
        )
    }

    static func breakdownSubtotal(_ projection: MonthlyProjection) -> Decimal {
        projection.breakdown
            .filter { $0.kind != .total }
            .map(\.amount)
            .reduce(.zero, +)
    }
}
