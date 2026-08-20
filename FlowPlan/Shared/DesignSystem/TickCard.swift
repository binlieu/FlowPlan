import SwiftUI

struct TickCard<Content: View>: View {
    private let contentPadding: CGFloat
    private let content: Content

    init(
        contentPadding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(contentPadding)
            .background(Palette.surface)
            .overlay {
                Rectangle()
                    .stroke(Palette.hairline, lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                CrosshairTick()
                    .offset(x: -10, y: -10)
            }
            .overlay(alignment: .topTrailing) {
                CrosshairTick()
                    .offset(x: 10, y: -10)
            }
            .overlay(alignment: .bottomLeading) {
                CrosshairTick()
                    .offset(x: -10, y: 10)
            }
            .overlay(alignment: .bottomTrailing) {
                CrosshairTick()
                    .offset(x: 10, y: 10)
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
    .padding(30)
    .background(Palette.background)
    .preferredColorScheme(.light)
}

#Preview("Tick Card — Dark") {
    TickCard {
        Text("Signature card")
            .foregroundStyle(Palette.ink)
    }
    .padding(30)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
#endif
