import SwiftUI
import FlowPlanDomain

struct SmartInsightsSection: View {
    let insights: [Insight]

    var body: some View {
        SectionCard(title: "Smart insights") {
            if insights.isEmpty {
                Text("There is not enough month-over-month data for an insight yet.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: insight.symbolName)
                                .font(.headline)
                                .foregroundStyle(Palette.accent)
                                .frame(width: 28)
                                .accessibilityHidden(true)

                            Text(insight.message)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)

                        if index < insights.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
