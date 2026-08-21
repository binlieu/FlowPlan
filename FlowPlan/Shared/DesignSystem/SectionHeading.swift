import SwiftUI

struct SectionHeading: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var trailing: AnyView? = nil

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize, hasTrailingContent {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    titleView
                    trailingContent
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    titleView

                    Spacer(minLength: Spacing.xs)

                    trailingContent
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var titleView: some View {
        Text(title)
            .sectionHeadingTypography()
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var trailingContent: some View {
        if let actionTitle, let action {
            Button(actionTitle, action: action)
                .rowDetailEmphasisTypography()
                .foregroundStyle(Palette.accent)
                .textCase(nil)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        } else if let trailing {
            trailing
        }
    }

    private var hasTrailingContent: Bool {
        (actionTitle != nil && action != nil) || trailing != nil
    }
}

#if DEBUG
#Preview("Section Heading") {
    VStack(spacing: Spacing.lg) {
        SectionHeading(title: "Expected Income", actionTitle: "Add") {}
        SectionHeading(title: "Bills", actionTitle: "View All") {}
        SectionHeading(title: "Smart insights")
    }
    .padding(Spacing.lg)
    .background(Palette.background)
}
#endif
