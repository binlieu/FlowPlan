import SwiftUI

struct Chip: View {
    enum Style {
        case outlinedAccent
        case filledAccent
        case filledNeutral
        case warning
        case plainAccent
        case tinted(Color)
    }

    let text: String
    let style: Style
    var systemImage: String? = nil

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
            .chipTypography()
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: Radius.chip)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.chip)
                    .stroke(borderColor, lineWidth: 1)
            }
            .accessibilityLabel(text.lowercased())
    }

    private var foregroundColor: Color {
        switch style {
        case .outlinedAccent:
            Palette.accent
        case .filledAccent:
            Palette.accent
        case .filledNeutral:
            Palette.inkSecondary
        case .warning:
            Palette.warning
        case .plainAccent:
            Palette.accent
        case .tinted(let color):
            color
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .outlinedAccent:
            Palette.clear
        case .filledAccent:
            Palette.accentLight
        case .filledNeutral:
            Palette.background
        case .warning:
            Palette.warning.opacity(0.12)
        case .plainAccent:
            Palette.surface
        case .tinted(let color):
            color.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch style {
        case .outlinedAccent:
            Palette.accent
        case .filledAccent:
            Palette.accentMuted
        case .filledNeutral:
            Palette.hairline
        case .warning:
            Palette.warning
        case .plainAccent:
            Palette.surface
        case .tinted:
            Palette.clear
        }
    }
}

#if DEBUG
#Preview("Chips") {
    HStack {
        Chip(text: "FIXED", style: .outlinedAccent)
        Chip(text: "AUTO PAY", style: .filledNeutral)
    }
    .padding(Spacing.md)
    .background(Palette.surface)
}
#endif
