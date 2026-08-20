import SwiftUI

struct MonthNavigationBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            Button(action: appState.goToPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Rectangle().stroke(Palette.hairline, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")

            Spacer(minLength: 8)

            Menu {
                Button("Go to current month", action: appState.goToCurrentMonth)
            } label: {
                Text(monthTitle.uppercased())
                    .smallCapsTypography()
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityLabel(monthTitle)
            .accessibilityHint("Offers an option to go to the current month")

            Spacer(minLength: 8)

            Button(action: appState.goToNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Rectangle().stroke(Palette.hairline, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .disabled(!appState.canGoForward)
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var monthTitle: String {
        appState.selectedMonth
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide).year())
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        MonthNavigationBar()
            .padding()
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        MonthNavigationBar()
            .padding()
    }
}
#endif
