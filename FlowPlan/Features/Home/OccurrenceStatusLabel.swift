import SwiftUI

struct OccurrenceStatusLabel: View {
    let text: String
    let isOverdue: Bool

    @ViewBuilder
    var body: some View {
        if isOverdue {
            Label(text, systemImage: "exclamationmark.circle")
                .smallCapsTypography()
                .foregroundStyle(Palette.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.warning.opacity(0.12), in: Capsule())
                .accessibilityLabel(text.lowercased())
        } else {
            Text(text)
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)
        }
    }
}
