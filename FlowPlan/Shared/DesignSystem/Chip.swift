import SwiftUI

struct Chip: View {
    enum Style {
        case outlinedAccent
        case filledNeutral
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .fontWidth(.condensed)
            .tracking(0.6)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            }
            .accessibilityLabel(text.lowercased())
    }

    private var foregroundColor: Color {
        switch style {
        case .outlinedAccent:
            Palette.accent
        case .filledNeutral:
            Palette.inkSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .outlinedAccent:
            .clear
        case .filledNeutral:
            Palette.background
        }
    }

    private var borderColor: Color {
        switch style {
        case .outlinedAccent:
            Palette.accent
        case .filledNeutral:
            Palette.hairline
        }
    }
}

#if DEBUG
#Preview("Chips") {
    HStack {
        Chip(text: "FIXED", style: .outlinedAccent)
        Chip(text: "AUTO PAY", style: .filledNeutral)
    }
    .padding()
    .background(Palette.surface)
}
#endif
