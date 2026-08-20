import Foundation

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
            formatStyle = formatStyle.precision(
                .fractionLength(hasFractionalPart(amount) ? 2 : 0)
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

    private static func hasFractionalPart(_ amount: Decimal) -> Bool {
        var source = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded != amount
    }
}
