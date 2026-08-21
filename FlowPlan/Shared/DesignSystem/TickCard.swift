import SwiftUI

/// The app's card container. Named for the corner crosshair ticks it originally drew; those were
/// removed at the owner's request, so it is now a plain `CardSurface` wrapper. Kept as the single
/// card type every screen uses, so the container stays centralized and cannot drift again.
struct TickCard<Content: View>: View {
    private let contentPadding: CGFloat
    private let content: Content

    init(
        contentPadding: CGFloat = Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        CardSurface(contentPadding: contentPadding) {
            content
        }
    }
}

#if DEBUG
#Preview("Tick Card — Light") {
    TickCard {
        Text("Signature card")
            .foregroundStyle(Palette.ink)
    }
    .padding(Spacing.xl)
    .background(Palette.background)
    .preferredColorScheme(.light)
}

#Preview("Tick Card — Dark") {
    TickCard {
        Text("Signature card")
            .foregroundStyle(Palette.ink)
    }
    .padding(Spacing.xl)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
#endif
