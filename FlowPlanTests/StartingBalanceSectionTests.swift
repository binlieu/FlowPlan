import Foundation
import Testing
@testable import FlowPlan

@Test
func disabledCarryForwardOffersClearInsteadOfRolledOverAmount() {
    let action = StartingBalanceSection.availableAction(
        carryBalanceForward: false,
        source: .explicit
    )

    #expect(action == .clear)
    #expect(action != .useRolledOverAmount)
}

@Test
func enabledCarryForwardStillOffersRolledOverAmount() {
    let action = StartingBalanceSection.availableAction(
        carryBalanceForward: true,
        source: .explicit
    )

    #expect(action == .useRolledOverAmount)
}

@Test
func disabledCarryForwardExplanationDescribesStandaloneMonthsAndPromptsWhenUnset() {
    let explicitExplanation = StartingBalanceSection.standaloneExplanation(source: .explicit)
    let unsetExplanation = StartingBalanceSection.standaloneExplanation(source: .unset)

    #expect(
        explicitExplanation
            == "What you had available at the start of the month. Each month is entered "
                + "separately because Carry balance forward is off."
    )
    #expect(
        unsetExplanation
            == explicitExplanation
                + " Enter this month's starting balance so your projection is accurate."
    )
}

@Test
func unsetBalanceUsesPlaceholderWhileExplicitZeroRemainsVisible() {
    let locale = Locale(identifier: "en_US_POSIX")

    #expect(
        StartingBalanceSection.displayText(
            for: StartingBalanceResolution(amount: .zero, source: .unset),
            locale: locale
        ).isEmpty
    )
    #expect(
        StartingBalanceSection.displayText(
            for: StartingBalanceResolution(amount: .zero, source: .explicit),
            locale: locale
        ) == "0.00"
    )
}
