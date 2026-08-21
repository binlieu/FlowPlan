import SwiftUI

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
            .overlay(alignment: .topLeading) {
                CrosshairTick()
                    .offset(x: -Spacing.sm, y: -Spacing.sm)
            }
            .overlay(alignment: .topTrailing) {
                CrosshairTick()
                    .offset(x: Spacing.sm, y: -Spacing.sm)
            }
            .overlay(alignment: .bottomLeading) {
                CrosshairTick()
                    .offset(x: -Spacing.sm, y: Spacing.sm)
            }
            .overlay(alignment: .bottomTrailing) {
                CrosshairTick()
                    .offset(x: Spacing.sm, y: Spacing.sm)
            }
    }
}

private struct CrosshairTick: View {
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: 20, height: 1)
            Rectangle()
                .frame(width: 1, height: 20)
        }
        .foregroundStyle(Palette.inkSecondary)
        .frame(width: 20, height: 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
