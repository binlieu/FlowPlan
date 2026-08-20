import Foundation

public struct ProjectionConfiguration: Hashable, Codable, Sendable {
    public var tightThreshold: Decimal
    public var aheadOfPlanThreshold: Decimal

    public init(tightThreshold: Decimal = 200, aheadOfPlanThreshold: Decimal = 100) {
        self.tightThreshold = tightThreshold
        self.aheadOfPlanThreshold = aheadOfPlanThreshold
    }

    public static let `default` = ProjectionConfiguration()
}

public struct ProjectionInput: Sendable {
    public let month: MonthKey
    public let referenceDate: Date
    public let startingBalance: Decimal
    public let incomeSources: [PlannedIncome]
    public let bills: [PlannedBill]
    public let budgets: [BudgetAllocation]
    public let savingsPlans: [SavingsPlan]
    public let transactions: [TransactionSnapshot]
    public let calendar: Calendar
    public let configuration: ProjectionConfiguration

    public init(
        month: MonthKey,
        referenceDate: Date,
        startingBalance: Decimal,
        incomeSources: [PlannedIncome] = [],
        bills: [PlannedBill] = [],
        budgets: [BudgetAllocation] = [],
        savingsPlans: [SavingsPlan] = [],
        transactions: [TransactionSnapshot] = [],
        calendar: Calendar = Calendar(identifier: .gregorian),
        configuration: ProjectionConfiguration = .default
    ) {
        self.month = month
        self.referenceDate = referenceDate
        self.startingBalance = startingBalance
        self.incomeSources = incomeSources
        self.bills = bills
        self.budgets = budgets
        self.savingsPlans = savingsPlans
        self.transactions = transactions
        self.calendar = calendar
        self.configuration = configuration
    }
}

public enum ProjectionStatus: String, Codable, Sendable {
    case aheadOfPlan
    case healthy
    case tight
    case negative
}

public struct ProjectionCompleteness: Hashable, Codable, Sendable {
    public let hasStartingBalance: Bool
    public let hasPlannedIncome: Bool
    public let hasBills: Bool
    public let hasSpendingBudget: Bool
    public let hasSavingsGoal: Bool

    public init(
        hasStartingBalance: Bool,
        hasPlannedIncome: Bool,
        hasBills: Bool,
        hasSpendingBudget: Bool,
        hasSavingsGoal: Bool
    ) {
        self.hasStartingBalance = hasStartingBalance
        self.hasPlannedIncome = hasPlannedIncome
        self.hasBills = hasBills
        self.hasSpendingBudget = hasSpendingBudget
        self.hasSavingsGoal = hasSavingsGoal
    }

    public var isComplete: Bool {
        hasStartingBalance
            && hasPlannedIncome
            && hasBills
            && hasSpendingBudget
            && hasSavingsGoal
    }

    public var missing: [String] {
        var missingItems: [String] = []

        if !hasStartingBalance {
            missingItems.append("Starting balance")
        }
        if !hasPlannedIncome {
            missingItems.append("Planned income")
        }
        if !hasBills {
            missingItems.append("Bills")
        }
        if !hasSpendingBudget {
            missingItems.append("Spending budget")
        }
        if !hasSavingsGoal {
            missingItems.append("Savings goal")
        }

        return missingItems
    }
}

public struct ProjectionLineItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case opening
        case addition
        case deduction
        case total
    }

    public let id: String
    public let label: String
    public let amount: Decimal
    public let kind: Kind

    public init(id: String, label: String, amount: Decimal, kind: Kind) {
        self.id = id
        self.label = label
        self.amount = amount
        self.kind = kind
    }
}

public struct MonthlyProjection: Hashable, Sendable {
    public let month: MonthKey

    public let totalExpectedIncome: Decimal
    public let incomeReceived: Decimal
    public let remainingExpectedIncome: Decimal

    /// Plan-only totals: what the plan says should happen this month, ignoring what actually has.
    /// These are the inputs to `plannedEndOfMonthBalance`, surfaced so a view can show the plan
    /// breakdown without recomputing it. Do not confuse them with the live remaining-obligation
    /// figures — `remainingBills` is what is still owed, `plannedBillsTotal` is what was planned.
    public let plannedIncomeTotal: Decimal
    public let plannedBillsTotal: Decimal
    public let plannedSpendingTotal: Decimal

    public let expensesPaid: Decimal
    public let remainingBills: Decimal
    public let billsPaid: Decimal
    public let projectedVariableSpending: Decimal
    public let actualVariableSpending: Decimal
    public let remainingVariableSpending: Decimal

    public let savingsCompleted: Decimal
    public let remainingSavingsGoal: Decimal
    public let savingsTarget: Decimal

    public let startingBalance: Decimal
    public let currentAvailableBalance: Decimal
    public let projectedEndOfMonthBalance: Decimal
    public let plannedEndOfMonthBalance: Decimal
    public let varianceVsPlan: Decimal

    public let spendableRemaining: Decimal
    public let dailySafeToSpend: Decimal

    public let daysRemaining: Int
    public let daysInMonth: Int
    public let savingsRate: Decimal

    public let status: ProjectionStatus
    public let completeness: ProjectionCompleteness
    public let breakdown: [ProjectionLineItem]

    public init(
        month: MonthKey,
        totalExpectedIncome: Decimal,
        incomeReceived: Decimal,
        remainingExpectedIncome: Decimal,
        plannedIncomeTotal: Decimal,
        plannedBillsTotal: Decimal,
        plannedSpendingTotal: Decimal,
        expensesPaid: Decimal,
        remainingBills: Decimal,
        billsPaid: Decimal,
        projectedVariableSpending: Decimal,
        actualVariableSpending: Decimal,
        remainingVariableSpending: Decimal,
        savingsCompleted: Decimal,
        remainingSavingsGoal: Decimal,
        savingsTarget: Decimal,
        startingBalance: Decimal,
        currentAvailableBalance: Decimal,
        projectedEndOfMonthBalance: Decimal,
        plannedEndOfMonthBalance: Decimal,
        varianceVsPlan: Decimal,
        spendableRemaining: Decimal,
        dailySafeToSpend: Decimal,
        daysRemaining: Int,
        daysInMonth: Int,
        savingsRate: Decimal,
        status: ProjectionStatus,
        completeness: ProjectionCompleteness,
        breakdown: [ProjectionLineItem]
    ) {
        self.month = month
        self.totalExpectedIncome = totalExpectedIncome
        self.incomeReceived = incomeReceived
        self.remainingExpectedIncome = remainingExpectedIncome
        self.plannedIncomeTotal = plannedIncomeTotal
        self.plannedBillsTotal = plannedBillsTotal
        self.plannedSpendingTotal = plannedSpendingTotal
        self.expensesPaid = expensesPaid
        self.remainingBills = remainingBills
        self.billsPaid = billsPaid
        self.projectedVariableSpending = projectedVariableSpending
        self.actualVariableSpending = actualVariableSpending
        self.remainingVariableSpending = remainingVariableSpending
        self.savingsCompleted = savingsCompleted
        self.remainingSavingsGoal = remainingSavingsGoal
        self.savingsTarget = savingsTarget
        self.startingBalance = startingBalance
        self.currentAvailableBalance = currentAvailableBalance
        self.projectedEndOfMonthBalance = projectedEndOfMonthBalance
        self.plannedEndOfMonthBalance = plannedEndOfMonthBalance
        self.varianceVsPlan = varianceVsPlan
        self.spendableRemaining = spendableRemaining
        self.dailySafeToSpend = dailySafeToSpend
        self.daysRemaining = daysRemaining
        self.daysInMonth = daysInMonth
        self.savingsRate = savingsRate
        self.status = status
        self.completeness = completeness
        self.breakdown = breakdown
    }
}

public struct WhatIfScenario: Hashable, Sendable {
    public let additionalTransactions: [TransactionSnapshot]
    public let savingsTargetOverride: Decimal?

    public init(
        additionalTransactions: [TransactionSnapshot] = [],
        savingsTargetOverride: Decimal? = nil
    ) {
        self.additionalTransactions = additionalTransactions
        self.savingsTargetOverride = savingsTargetOverride
    }
}

public struct WhatIfResult: Hashable, Sendable {
    public let base: MonthlyProjection
    public let simulated: MonthlyProjection

    public init(base: MonthlyProjection, simulated: MonthlyProjection) {
        self.base = base
        self.simulated = simulated
    }

    public var impact: Decimal {
        simulated.projectedEndOfMonthBalance - base.projectedEndOfMonthBalance
    }
}
