import SwiftUI
import FlowPlanDomain

struct SafeToSpendCard: View {
    let projection: MonthlyProjection

    var body: some View {
        SectionCard(title: "Safe to Spend") {
            if projection.daysRemaining == 0 {
                Label("The month is complete", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        AmountText(amount: projection.dailySafeToSpend, style: .primary)
                        Text("/ day")
                            .font(.headline)
                    }

                    Text(daysRemainingDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var daysRemainingDescription: String {
        let dayWord = projection.daysRemaining == 1 ? "day" : "days"
        return "for the \(projection.daysRemaining) \(dayWord) left in \(monthName)"
    }

    private var monthName: String {
        projection.month
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        SafeToSpendCard(projection: FlowPlanPreviewData.projection())
            .padding()
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        SafeToSpendCard(projection: FlowPlanPreviewData.projection())
            .padding()
    }
}
#endif
