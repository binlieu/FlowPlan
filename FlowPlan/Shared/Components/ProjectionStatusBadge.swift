import SwiftUI
import FlowPlanDomain

struct ProjectionStatusBadge: View {
    let status: ProjectionStatus

    var body: some View {
        Chip(
            text: presentation.title,
            style: .tinted(presentation.color),
            systemImage: presentation.symbol
        )
    }

    private var presentation: Presentation {
        switch status {
        case .healthy:
            Presentation(title: "Healthy", symbol: "checkmark.circle.fill", color: Palette.positive)
        case .tight:
            Presentation(title: "Tight", symbol: "exclamationmark.triangle.fill", color: Palette.warning)
        case .negative:
            Presentation(title: "Short", symbol: "arrow.down.circle.fill", color: Palette.negative)
        case .aheadOfPlan:
            Presentation(title: "Ahead of plan", symbol: "arrow.up.circle.fill", color: Palette.positive)
        }
    }

    private struct Presentation {
        let title: String
        let symbol: String
        let color: Color
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ProjectionStatusBadge(status: .healthy)
            ProjectionStatusBadge(status: .tight)
            ProjectionStatusBadge(status: .negative)
            ProjectionStatusBadge(status: .aheadOfPlan)
        }
        .padding(Spacing.md)
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ProjectionStatusBadge(status: .healthy)
            ProjectionStatusBadge(status: .tight)
            ProjectionStatusBadge(status: .negative)
            ProjectionStatusBadge(status: .aheadOfPlan)
        }
        .padding(Spacing.md)
    }
}
#endif
