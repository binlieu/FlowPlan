import Foundation

enum MoneyFormatter {
    static func string(
        _ amount: Decimal,
        currencyCode: String,
        signed: Bool = false
    ) -> String {
        let style = Decimal.FormatStyle.Currency(code: currencyCode)
            .sign(strategy: signed ? .always(showZero: false) : .automatic)
        return amount.formatted(style)
    }

    static func accessibleString(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(
            Decimal.FormatStyle.Currency(code: currencyCode)
                .presentation(.fullName)
        )
    }
}
