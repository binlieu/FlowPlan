import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .foregroundStyle(Palette.onAccentFill)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        EmptyStateView(
            symbol: "tray",
            title: "No transactions yet.",
            message: "Add your first income or expense to start tracking your month.",
            actionTitle: "Add transaction"
        ) {}
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        EmptyStateView(
            symbol: "tray",
            title: "No transactions yet.",
            message: "Add your first income or expense to start tracking your month.",
            actionTitle: "Add transaction"
        ) {}
    }
}
#endif
