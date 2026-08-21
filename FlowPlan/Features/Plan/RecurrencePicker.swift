import SwiftUI
import FlowPlanDomain

struct RecurrencePicker: View {
    @Binding var frequency: RecurrenceFrequency
    @Binding var anchorDate: Date

    var body: some View {
        Picker("Repeats", selection: $frequency) {
            ForEach(RecurrenceFrequency.allCases, id: \.self) { option in
                Text(RecurrenceText.frequencyName(option))
                    .tag(option)
            }
        }

        DatePicker(
            "Starts",
            selection: $anchorDate,
            displayedComponents: .date
        )

        Text(RecurrenceText.preview(frequency: frequency, anchorDate: anchorDate))
            .rowDetailTypography()
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

enum RecurrenceText {
    static func frequencyName(_ frequency: RecurrenceFrequency) -> String {
        switch frequency {
        case .weekly:
            "Weekly"
        case .biweekly:
            "Every two weeks"
        case .monthly:
            "Monthly"
        case .quarterly:
            "Every three months"
        case .semiannually:
            "Every six months"
        case .annually:
            "Yearly"
        }
    }

    static func preview(frequency: RecurrenceFrequency, anchorDate: Date) -> String {
        "\(frequencyName(frequency)), from \(formattedDate(anchorDate))"
    }

    static func summary(_ recurrence: RecurrenceRule) -> String {
        switch recurrence.frequency {
        case .monthly:
            "Monthly · \(ordinalDay(recurrence.anchorDate)) of each month"
        default:
            "\(frequencyName(recurrence.frequency)) · from \(shortDate(recurrence.anchorDate))"
        }
    }

    static func dueDescription(_ recurrence: RecurrenceRule) -> String {
        switch recurrence.frequency {
        case .monthly:
            "Due \(ordinalDay(recurrence.anchorDate))"
        default:
            frequencyName(recurrence.frequency)
        }
    }

    private static func ordinalDay(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }

    private static func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}
