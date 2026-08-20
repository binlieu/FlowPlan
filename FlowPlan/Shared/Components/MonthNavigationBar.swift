import SwiftUI

struct MonthNavigationBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            Button(action: appState.goToPreviousMonth) {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer(minLength: 8)

            Menu {
                Button("Go to current month", action: appState.goToCurrentMonth)
            } label: {
                Text(monthTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .accessibilityLabel(monthTitle)
            .accessibilityHint("Offers an option to go to the current month")

            Spacer(minLength: 8)

            Button(action: appState.goToNextMonth) {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!appState.canGoForward)
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.plain)
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
