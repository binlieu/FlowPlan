import Foundation
import FlowPlanDomain

enum OrphanedDebtDetector {
    static let warningMessage = "Marked as paid through Monthly Bills, but no matching bill was found. This payment isn't counted in your plan."

    static func orphanedDebts(
        in debts: [Debt],
        bills: [PlannedBill],
        calendar: Calendar = .current
    ) -> [Debt] {
        debts.filter { isOrphaned($0, bills: bills, calendar: calendar) }
    }

    static func isOrphaned(
        _ debt: Debt,
        bills: [PlannedBill],
        calendar: Calendar = .current
    ) -> Bool {
        isOrphaned(
            name: debt.name,
            monthlyPayment: debt.monthlyPayment,
            dueDay: debt.dueDay,
            isActive: debt.isActive,
            isPaidThroughBills: debt.isPaidThroughBills,
            bills: bills,
            calendar: calendar
        )
    }

    static func isOrphaned(
        name: String,
        monthlyPayment: Decimal?,
        dueDay: Int,
        isActive: Bool,
        isPaidThroughBills: Bool,
        bills: [PlannedBill],
        calendar: Calendar = .current
    ) -> Bool {
        guard isActive, isPaidThroughBills else {
            return false
        }

        return !bills.contains { bill in
            guard bill.isActive else {
                return false
            }

            let namesMatch = bill.name == name
                || bill.name.caseInsensitiveCompare(name) == .orderedSame
            let amountAndDueDayMatch = monthlyPayment.map { payment in
                bill.amount == payment
                    && calendar.component(.day, from: bill.recurrence.anchorDate) == dueDay
            } ?? false

            return namesMatch || amountAndDueDayMatch
        }
    }
}
