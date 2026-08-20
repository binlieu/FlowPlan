import Foundation
import Testing
@testable import FlowPlan

/// Master prompt §41: never assume a currency uses two decimal places. Compact formatting used
/// to hardcode 2, which silently truncated a Kuwaiti dinar by a digit and invented cents for yen.
@Test func fractionDigitsComeFromTheCurrencyNotAnAssumption() {
    #expect(MoneyFormatter.fractionDigits(for: "USD") == 2)
    #expect(MoneyFormatter.fractionDigits(for: "EUR") == 2)
    #expect(MoneyFormatter.fractionDigits(for: "JPY") == 0)
    #expect(MoneyFormatter.fractionDigits(for: "KWD") == 3)
    #expect(MoneyFormatter.fractionDigits(for: "BHD") == 3)
}

@Test func compactKeepsEveryDigitAThreeDecimalCurrencyUses() {
    let formatted = MoneyFormatter.string(
        Decimal(string: "1.234")!,
        currencyCode: "KWD",
        style: .compact
    )
    // The digits must survive; the grouping/symbol placement is the system's business.
    #expect(formatted.contains("1.234") || formatted.contains("1,234"))
    #expect(!formatted.contains("1.23 ") && !formatted.hasSuffix("1.23"))
}

@Test func compactNeverInventsCentsForAZeroDecimalCurrency() {
    let formatted = MoneyFormatter.string(Decimal(1_500), currencyCode: "JPY", style: .compact)
    #expect(!formatted.contains(".00"))
    #expect(formatted.contains("1,500"))
}

@Test func compactStillDropsTheFractionWhenThereIsNothingToDrop() {
    let formatted = MoneyFormatter.string(Decimal(8_500), currencyCode: "USD", style: .compact)
    #expect(formatted == "$8,500")
}

@Test func compactKeepsCentsWhenTheAmountHasThem() {
    let formatted = MoneyFormatter.string(
        Decimal(string: "5079.50")!,
        currencyCode: "USD",
        style: .compact
    )
    #expect(formatted == "$5,079.50")
}

@Test func standardStyleIsUntouchedByTheCompactRule() {
    let formatted = MoneyFormatter.string(Decimal(8_500), currencyCode: "USD")
    #expect(formatted == "$8,500.00")
}

@Test func accessibilityStringAlwaysSpeaksTheExactAmount() {
    // Compact display may abbreviate; the spoken form must not.
    let spoken = MoneyFormatter.accessibleString(
        Decimal(string: "5079.50")!,
        currencyCode: "USD"
    )
    #expect(spoken.contains("5,079.5"))
    #expect(spoken.localizedCaseInsensitiveContains("dollar"))
}
