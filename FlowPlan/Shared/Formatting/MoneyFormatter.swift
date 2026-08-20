import Foundation
import os

enum MoneyFormatter {
    enum Style {
        case standard
        case compact
    }

    static func string(
        _ amount: Decimal,
        currencyCode: String,
        signed: Bool = false,
        style: Style = .standard
    ) -> String {
        var formatStyle = Decimal.FormatStyle.Currency(code: currencyCode)
            .sign(strategy: signed ? .always(showZero: false) : .automatic)

        if style == .compact {
            // Compact drops the fraction only when there is nothing to drop. The number of
            // digits kept is the currency's own, never a hardcoded 2 — JPY has none and KWD
            // has three, so assuming 2 would round a Kuwaiti dinar amount down by a digit.
            formatStyle = formatStyle.precision(
                .fractionLength(hasFractionalPart(amount) ? fractionDigits(for: currencyCode) : 0)
            )
        }

        return amount.formatted(formatStyle)
    }

    static func accessibleString(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(
            Decimal.FormatStyle.Currency(code: currencyCode)
                .presentation(.fullName)
        )
    }

    /// The number of fraction digits the given currency actually uses, asked of the system
    /// rather than assumed. Cached because compact formatting runs on every row of every list.
    static func fractionDigits(for currencyCode: String) -> Int {
        if let cached = cachedFractionDigits.withLock({ $0[currencyCode] }) {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let digits = formatter.maximumFractionDigits

        cachedFractionDigits.withLock { $0[currencyCode] = digits }
        return digits
    }

    private static let cachedFractionDigits = OSAllocatedUnfairLock(initialState: [String: Int]())

    private static func hasFractionalPart(_ amount: Decimal) -> Bool {
        var source = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded != amount
    }
}
