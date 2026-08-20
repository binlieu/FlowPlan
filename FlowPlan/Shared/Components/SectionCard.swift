import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.headline)

                Spacer(minLength: 8)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                }
            }

            content
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        SectionCard(title: "Overview", actionTitle: "See all") {
            Text("A reusable grouped section.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        SectionCard(title: "Overview", actionTitle: "See all") {
            Text("A reusable grouped section.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
#endif
