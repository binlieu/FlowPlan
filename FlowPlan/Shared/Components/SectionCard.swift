import SwiftUI

/// The only view that draws a card or grouped-container background. Higher-level components such
/// as `TickCard` and `GroupedList` compose this surface instead of recreating fill and border
/// styling at their call sites.
struct CardSurface<Content: View>: View {
    private let fill: AnyShapeStyle
    private let radius: CGFloat
    private let contentInsets: EdgeInsets
    private let content: Content

    init(
        fill: AnyShapeStyle = AnyShapeStyle(Palette.surface),
        radius: CGFloat = Radius.card,
        contentPadding: CGFloat = Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.radius = radius
        self.contentInsets = EdgeInsets(
            top: contentPadding,
            leading: contentPadding,
            bottom: contentPadding,
            trailing: contentPadding
        )
        self.content = content()
    }

    init(
        fill: AnyShapeStyle = AnyShapeStyle(Palette.surface),
        radius: CGFloat = Radius.card,
        contentInsets: EdgeInsets,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.radius = radius
        self.contentInsets = contentInsets
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(contentInsets)
            .background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Palette.hairline, lineWidth: 1)
            }
    }
}

#if DEBUG
#Preview("Card Surface — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        CardSurface {
            Text("A reusable grouped surface.")
                .foregroundStyle(Palette.ink)
        }
        .padding(Spacing.lg)
    }
}

#Preview("Card Surface — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        CardSurface {
            Text("A reusable grouped surface.")
                .foregroundStyle(Palette.ink)
        }
        .padding(Spacing.lg)
    }
}
#endif
