import SwiftUI

struct EmptyStateView: View {
    enum Layout {
        case full
        case compact
    }

    let symbol: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let layout: Layout

    init(
        symbol: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        layout: Layout = .full,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.layout = layout
        self.action = action
    }

    var body: some View {
        VStack(alignment: layout == .compact ? .leading : .center, spacing: Spacing.sm) {
            Image(systemName: symbol)
                .iconTypography()
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)

            Text(title)
                .prominentLabelTypography()
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(layout == .compact ? .leading : .center)

            if let message {
                Text(message)
                    .rowDetailTypography()
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(layout == .compact ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .prominentLabelTypography()
                    .foregroundStyle(Palette.onAccentFill)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
            }
        }
        .frame(maxWidth: .infinity, alignment: layout == .compact ? .leading : .center)
        .padding(layout == .compact ? Spacing.md : Spacing.lg)
        .accessibilityElement(children: .contain)
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
