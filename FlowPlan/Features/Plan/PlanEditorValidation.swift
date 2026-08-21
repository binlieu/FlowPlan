import SwiftUI

enum PlanEditorValidation {
    static func requiredText(_ value: String, message: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? message : nil
    }

    static func positiveAmount(_ value: String, message: String) -> String? {
        guard let amount = PlanAmountParser.decimal(from: value), amount > .zero else {
            return message
        }
        return nil
    }

    static func nonnegativeAmount(_ value: String, message: String) -> String? {
        guard let amount = PlanAmountParser.decimal(from: value), amount >= .zero else {
            return message
        }
        return nil
    }

    static func optionalNonnegativeAmount(_ value: String, message: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }
        return nonnegativeAmount(trimmedValue, message: message)
    }

    static func optionalDebtAPRPercentage(_ value: String) -> Decimal? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? .zero : PlanAmountParser.decimal(from: trimmedValue)
    }

    static func debtCategory(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? "Debt" : trimmedValue
    }
}

struct PlanValidationMessage: View {
    let message: String?

    @ViewBuilder
    var body: some View {
        if let message {
            Text(message)
                .footnoteTypography()
                .foregroundStyle(Palette.negative)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Validation error. \(message)")
        }
    }
}

enum DebtDueDayText {
    static func ordinal(_ day: Int) -> String {
        let normalizedDay = min(31, max(1, day))
        let suffix: String

        if (11...13).contains(normalizedDay % 100) {
            suffix = "th"
        } else {
            switch normalizedDay % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }

        return "\(normalizedDay)\(suffix)"
    }
}
