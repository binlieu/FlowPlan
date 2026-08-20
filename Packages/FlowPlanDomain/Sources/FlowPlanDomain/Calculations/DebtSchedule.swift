import Foundation

public enum DebtScheduleResult<Value: Hashable & Sendable>: Hashable, Sendable {
    case value(Value)
    case neverAmortises
    case exceedsMaximumTerm
}

public struct DebtSchedule: Sendable {
    public static let maximumMonths = 600

    private let startingMonth: MonthKey?

    public init(startingIn startingMonth: MonthKey? = nil) {
        self.startingMonth = startingMonth
    }

    public func remainingPayments(for debt: Debt) -> DebtScheduleResult<Int> {
        var balance = roundedMoney(debt.currentBalance)
        guard balance > .zero else {
            return .value(0)
        }

        for paymentNumber in 1...Self.maximumMonths {
            switch applyingScheduledPayment(to: balance, for: debt) {
            case .payment(_, let remainingBalance):
                balance = remainingBalance
                if balance <= .zero {
                    return .value(paymentNumber)
                }
            case .neverAmortises:
                return .neverAmortises
            }
        }

        return .exceedsMaximumTerm
    }

    public func payoffMonth(
        for debt: Debt,
        startingIn month: MonthKey
    ) -> DebtScheduleResult<MonthKey> {
        switch remainingPayments(for: debt) {
        case .value(let count):
            guard count > 0 else {
                return .value(month.previous)
            }
            return .value(month.adding(months: count - 1))
        case .neverAmortises:
            return .neverAmortises
        case .exceedsMaximumTerm:
            return .exceedsMaximumTerm
        }
    }

    /// Returns the scheduled payment in `month`. When no starting month was supplied to the
    /// schedule, `month` is treated as the first payment month.
    public func paymentDue(for debt: Debt, in month: MonthKey) -> Decimal {
        let firstPaymentMonth = startingMonth ?? month
        return paymentDue(for: debt, in: month, startingIn: firstPaymentMonth)
    }

    public func paymentDue(
        for debt: Debt,
        in month: MonthKey,
        startingIn firstPaymentMonth: MonthKey
    ) -> Decimal {
        guard month >= firstPaymentMonth else {
            return .zero
        }

        let offset = monthOffset(from: firstPaymentMonth, to: month)
        guard offset < Self.maximumMonths else {
            return .zero
        }

        var balance = roundedMoney(debt.currentBalance)
        guard balance > .zero else {
            return .zero
        }

        for paymentIndex in 0...offset {
            switch applyingScheduledPayment(to: balance, for: debt) {
            case .payment(let amount, let remainingBalance):
                if paymentIndex == offset {
                    return amount
                }
                balance = remainingBalance
                if balance <= .zero {
                    return .zero
                }
            case .neverAmortises:
                return roundedMoney(debt.monthlyPayment)
            }
        }

        return .zero
    }

    /// Applies an actual payment to principal after the month's rounded interest charge.
    public func remainingBalance(
        afterPaymentOf amount: Decimal,
        for debt: Debt
    ) -> Decimal {
        let balance = roundedMoney(debt.currentBalance)
        guard balance > .zero else {
            return .zero
        }

        let interest = monthlyInterest(on: balance, annualRate: debt.annualInterestRate)
        let payment = roundedMoney(max(.zero, amount))
        let principal = roundedMoney(max(.zero, payment - interest))
        return roundedMoney(max(.zero, balance - principal))
    }

    /// Reconstructs the balance immediately before an actual payment. Persistence uses this to
    /// project the settlement month from its opening debt balance after storing the new balance.
    public func balanceBeforePayment(
        of amount: Decimal,
        remainingBalance: Decimal,
        annualInterestRate: Decimal
    ) -> Decimal {
        let remainingBalance = roundedMoney(max(.zero, remainingBalance))
        let payment = roundedMoney(max(.zero, amount))
        let interestOnRemainingBalance = monthlyInterest(
            on: remainingBalance,
            annualRate: annualInterestRate
        )

        guard payment > interestOnRemainingBalance else {
            return remainingBalance
        }

        let monthlyRate = annualInterestRate / 12
        return roundedMoney((remainingBalance + payment) / (1 + monthlyRate))
    }

    private func applyingScheduledPayment(
        to balance: Decimal,
        for debt: Debt
    ) -> PaymentStep {
        let interest = monthlyInterest(on: balance, annualRate: debt.annualInterestRate)
        let normalPayment = roundedMoney(debt.monthlyPayment)

        guard normalPayment > interest else {
            return .neverAmortises
        }

        let amountDue = roundedMoney(min(normalPayment, balance + interest))
        let principal = roundedMoney(amountDue - interest)
        let remainingBalance = roundedMoney(max(.zero, balance - principal))
        return .payment(amount: amountDue, remainingBalance: remainingBalance)
    }

    private func monthlyInterest(on balance: Decimal, annualRate: Decimal) -> Decimal {
        roundedMoney(balance * (annualRate / 12))
    }

    private func roundedMoney(_ value: Decimal) -> Decimal {
        var source = value
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    private func monthOffset(from start: MonthKey, to end: MonthKey) -> Int {
        ((end.year - start.year) * 12) + end.month - start.month
    }

    private enum PaymentStep {
        case payment(amount: Decimal, remainingBalance: Decimal)
        case neverAmortises
    }
}
