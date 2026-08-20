import Foundation

public struct MonthlyProjectionEngine: Sendable {
    public init() {}

    public func project(_ input: ProjectionInput) -> MonthlyProjection {
        // Only in-month transactions participate, and transfers are projection-neutral.
        let transactions = input.transactions.filter {
            input.month.contains($0.date, calendar: input.calendar) && $0.type != .transfer
        }

        let incomeTransactions = transactions.filter { $0.type == .income }
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let savingsTransactions = transactions.filter { $0.type == .savings }

        let activeIncome = input.incomeSources.filter(\.isActive)
        let activeBills = input.bills.filter(\.isActive)
        let separatelyPaidDebts = input.debts.filter {
            $0.isActive && !$0.isPaidThroughBills
        }

        let incomeOccurrences = activeIncome.map { source in
            (source, source.recurrence.occurrences(in: input.month, calendar: input.calendar))
        }
        let billOccurrences = activeBills.map { bill in
            (bill, bill.recurrence.occurrences(in: input.month, calendar: input.calendar))
        }

        // Rule 1: received income is every in-month income transaction.
        let incomeReceived = sum(incomeTransactions.map(\.amount))

        // Rule 2: each linked income transaction settles one occurrence, earliest first.
        let remainingExpectedIncome = incomeOccurrences.reduce(Decimal.zero) { total, entry in
            let linkedTransactionCount = incomeTransactions.filter {
                $0.settlesIncomeID == entry.0.id
            }.count
            let remainingOccurrenceCount = max(0, entry.1.count - linkedTransactionCount)
            return total + (entry.0.expectedAmount * Decimal(remainingOccurrenceCount))
        }

        // Rule 3: unlinked income is extra and does not retire an expectation.
        let totalExpectedIncome = incomeReceived + remainingExpectedIncome

        // Rule 4: linked bill payments are paid actuals; each retires one occurrence in date order.
        let billsPaid = sum(
            expenseTransactions
                .filter { $0.settlesBillID != nil }
                .map(\.amount)
        )
        let remainingBills = billOccurrences.reduce(Decimal.zero) { total, entry in
            let linkedTransactionCount = expenseTransactions.filter {
                $0.settlesBillID == entry.0.id
            }.count
            let remainingOccurrenceCount = max(0, entry.1.count - linkedTransactionCount)
            return total + (entry.0.amount * Decimal(remainingOccurrenceCount))
        }

        // Rule 19: active debts outside Monthly Bills contribute one scheduled payment while a
        // balance remains. One linked expense settles that month's due. Debts paid through bills
        // contribute nothing here because their cash is already represented by remainingBills.
        let referenceMonth = MonthKey(date: input.referenceDate, calendar: input.calendar)
        let firstDebtPaymentMonth = min(input.month, referenceMonth)
        let debtSchedule = DebtSchedule(startingIn: firstDebtPaymentMonth)
        let debtPaymentTransactions = expenseTransactions.filter {
            $0.settlesBillID == nil && $0.settlesDebtID != nil
        }
        let settledDebtIDs = Set(debtPaymentTransactions.compactMap(\.settlesDebtID))
        let debtPaymentsMade = sum(debtPaymentTransactions.map(\.amount))
        let debtPaymentsDue = separatelyPaidDebts.reduce(Decimal.zero) { total, debt in
            total + debtSchedule.paymentDue(for: debt, in: input.month)
        }
        let remainingDebtPayments = separatelyPaidDebts.reduce(Decimal.zero) { total, debt in
            guard !settledDebtIDs.contains(debt.id) else {
                return total
            }
            return total + debtSchedule.paymentDue(for: debt, in: input.month)
        }

        // Rule 5: expenses not linked to bills or debts are discretionary spending.
        let discretionaryExpenses = expenseTransactions.filter {
            $0.settlesBillID == nil && $0.settlesDebtID == nil
        }
        let actualVariableSpending = sum(discretionaryExpenses.map(\.amount))

        // Rule 6: each category contributes only its unspent budget, never a negative remainder.
        let limitsByCategory = input.budgets.reduce(into: [String: Decimal]()) { limits, budget in
            limits[budget.category, default: .zero] += budget.monthlyLimit
        }
        let spentByCategory = discretionaryExpenses.reduce(into: [String: Decimal]()) { spent, transaction in
            spent[transaction.category, default: .zero] += transaction.amount
        }
        let remainingVariableSpending = limitsByCategory.reduce(Decimal.zero) { total, entry in
            total + max(.zero, entry.value - spentByCategory[entry.key, default: .zero])
        }
        let projectedVariableSpending = actualVariableSpending + remainingVariableSpending

        // Rule 7: paid expenses combine linked bills, linked debts, and discretionary actuals.
        let expensesPaid = billsPaid + debtPaymentsMade + actualVariableSpending

        // Rule 8: savings actuals retire the aggregate monthly savings target.
        let savingsCompleted = sum(savingsTransactions.map(\.amount))
        let savingsTarget = sum(input.savingsPlans.map(\.monthlyTarget))
        let remainingSavingsGoal = max(.zero, savingsTarget - savingsCompleted)

        // Rule 9: current cash counts each actual event exactly once.
        let currentAvailableBalance = input.startingBalance
            + incomeReceived
            - expensesPaid
            - savingsCompleted

        // Rule 10: projection applies only outstanding expectations and obligations to current cash.
        let projectedEndOfMonthBalance = currentAvailableBalance
            + remainingExpectedIncome
            - remainingBills
            - remainingDebtPayments
            - remainingVariableSpending
            - remainingSavingsGoal

        let plannedIncome = incomeOccurrences.reduce(Decimal.zero) { total, entry in
            total + (entry.0.expectedAmount * Decimal(entry.1.count))
        }
        let plannedBills = billOccurrences.reduce(Decimal.zero) { total, entry in
            total + (entry.0.amount * Decimal(entry.1.count))
        }
        let plannedBudgets = sum(input.budgets.map(\.monthlyLimit))

        // Rule 11: the plan ignores actuals; variance compares the live projection with that plan.
        let plannedEndOfMonthBalance = input.startingBalance
            + plannedIncome
            - plannedBills
            - debtPaymentsDue
            - plannedBudgets
            - savingsTarget
        let varianceVsPlan = projectedEndOfMonthBalance - plannedEndOfMonthBalance

        // Rule 12: spendable cash ignores the planned variable budget.
        let spendableRemaining = currentAvailableBalance
            + remainingExpectedIncome
            - remainingBills
            - remainingDebtPayments
            - remainingSavingsGoal

        // Rule 13: days remaining are inclusive for an in-month reference day.
        let daysInMonth = input.month.dayCount(calendar: input.calendar)
        let daysRemaining = calculateDaysRemaining(input: input, daysInMonth: daysInMonth)

        // Rule 14: safe-to-spend never divides by zero and rounds down to avoid over-promising.
        let dailySafeToSpend = calculateDailySafeToSpend(
            spendableRemaining: spendableRemaining,
            daysRemaining: daysRemaining
        )

        // Rule 15: the savings rate is zero when no income is expected.
        let savingsRate = totalExpectedIncome > .zero
            ? (savingsCompleted + remainingSavingsGoal) / totalExpectedIncome
            : .zero

        // Rule 16: status thresholds are evaluated in the required priority order.
        let status: ProjectionStatus
        if projectedEndOfMonthBalance < .zero {
            status = .negative
        } else if projectedEndOfMonthBalance < input.configuration.tightThreshold {
            status = .tight
        } else if varianceVsPlan > input.configuration.aheadOfPlanThreshold {
            status = .aheadOfPlan
        } else {
            status = .healthy
        }

        let completeness = ProjectionCompleteness(
            hasStartingBalance: input.startingBalance != .zero,
            hasPlannedIncome: !activeIncome.isEmpty,
            hasBills: !activeBills.isEmpty,
            hasSpendingBudget: !input.budgets.isEmpty,
            hasSavingsGoal: !input.savingsPlans.isEmpty
        )

        // Rule 17: projectedEndOfMonthBalance is deliberately not clamped.

        // Rule 18: breakdown order and signs are authoritative for the UI.
        let breakdown = [
            ProjectionLineItem(
                id: "currentAvailable",
                label: "Current available",
                amount: currentAvailableBalance,
                kind: .opening
            ),
            ProjectionLineItem(
                id: "remainingIncome",
                label: "Remaining income",
                amount: remainingExpectedIncome,
                kind: .addition
            ),
            ProjectionLineItem(
                id: "remainingBills",
                label: "Remaining bills",
                amount: -remainingBills,
                kind: .deduction
            ),
            ProjectionLineItem(
                id: "remainingDebt",
                label: "Debt payments",
                amount: -remainingDebtPayments,
                kind: .deduction
            ),
            ProjectionLineItem(
                id: "remainingSpending",
                label: "Remaining spending",
                amount: -remainingVariableSpending,
                kind: .deduction
            ),
            ProjectionLineItem(
                id: "remainingSavings",
                label: "Remaining savings",
                amount: -remainingSavingsGoal,
                kind: .deduction
            ),
            ProjectionLineItem(
                id: "projectedBalance",
                label: "Projected balance",
                amount: projectedEndOfMonthBalance,
                kind: .total
            )
        ]

        return MonthlyProjection(
            month: input.month,
            totalExpectedIncome: totalExpectedIncome,
            incomeReceived: incomeReceived,
            remainingExpectedIncome: remainingExpectedIncome,
            plannedIncomeTotal: plannedIncome,
            plannedBillsTotal: plannedBills,
            plannedSpendingTotal: plannedBudgets,
            expensesPaid: expensesPaid,
            remainingBills: remainingBills,
            billsPaid: billsPaid,
            debtPaymentsDue: debtPaymentsDue,
            debtPaymentsMade: debtPaymentsMade,
            remainingDebtPayments: remainingDebtPayments,
            projectedVariableSpending: projectedVariableSpending,
            actualVariableSpending: actualVariableSpending,
            remainingVariableSpending: remainingVariableSpending,
            savingsCompleted: savingsCompleted,
            remainingSavingsGoal: remainingSavingsGoal,
            savingsTarget: savingsTarget,
            startingBalance: input.startingBalance,
            currentAvailableBalance: currentAvailableBalance,
            projectedEndOfMonthBalance: projectedEndOfMonthBalance,
            plannedEndOfMonthBalance: plannedEndOfMonthBalance,
            varianceVsPlan: varianceVsPlan,
            spendableRemaining: spendableRemaining,
            dailySafeToSpend: dailySafeToSpend,
            daysRemaining: daysRemaining,
            daysInMonth: daysInMonth,
            savingsRate: savingsRate,
            status: status,
            completeness: completeness,
            breakdown: breakdown
        )
    }

    public func simulate(_ scenario: WhatIfScenario, on input: ProjectionInput) -> WhatIfResult {
        let base = project(input)
        let simulatedInput = ProjectionInput(
            month: input.month,
            referenceDate: input.referenceDate,
            startingBalance: input.startingBalance,
            incomeSources: input.incomeSources,
            bills: input.bills,
            debts: input.debts,
            budgets: input.budgets,
            savingsPlans: overriddenSavingsPlans(
                input.savingsPlans,
                target: scenario.savingsTargetOverride
            ),
            transactions: input.transactions + scenario.additionalTransactions,
            calendar: input.calendar,
            configuration: input.configuration
        )
        let simulated = project(simulatedInput)
        return WhatIfResult(base: base, simulated: simulated)
    }

    private func sum(_ values: [Decimal]) -> Decimal {
        values.reduce(.zero, +)
    }

    private func calculateDaysRemaining(input: ProjectionInput, daysInMonth: Int) -> Int {
        let monthStart = input.month.startDate(calendar: input.calendar)
        let nextMonthStart = input.month.next.startDate(calendar: input.calendar)

        if input.referenceDate < monthStart {
            return daysInMonth
        }
        if input.referenceDate >= nextMonthStart {
            return 0
        }

        let referenceDay = input.calendar.startOfDay(for: input.referenceDate)
        return input.calendar.dateComponents(
            [.day],
            from: referenceDay,
            to: nextMonthStart
        ).day ?? 0
    }

    private func calculateDailySafeToSpend(
        spendableRemaining: Decimal,
        daysRemaining: Int
    ) -> Decimal {
        guard daysRemaining > 0 else {
            return .zero
        }

        var amount = max(.zero, spendableRemaining) / Decimal(daysRemaining)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &amount, 2, .down)
        return rounded
    }

    private func overriddenSavingsPlans(
        _ plans: [SavingsPlan],
        target: Decimal?
    ) -> [SavingsPlan] {
        guard let target else {
            return plans
        }

        let scenarioPlanID = plans.first?.id ?? UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        )
        let scenarioPlanName = plans.first?.name ?? "What-If Savings Target"
        return [SavingsPlan(id: scenarioPlanID, name: scenarioPlanName, monthlyTarget: target)]
    }
}
