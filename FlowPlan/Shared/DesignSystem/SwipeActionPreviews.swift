#if DEBUG
import SwiftUI
import FlowPlanDomain

private struct SwipeActionPreviewModel: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let fill: Color

    init(title: String, systemImage: String, fill: Color) {
        id = title
        self.title = title
        self.systemImage = systemImage
        self.fill = fill
    }
}

private struct RevealedSwipeRow<Content: View>: View {
    let edge: HorizontalEdge
    let actions: [SwipeActionPreviewModel]
    let content: Content

    init(
        edge: HorizontalEdge,
        actions: [SwipeActionPreviewModel],
        @ViewBuilder content: () -> Content
    ) {
        self.edge = edge
        self.actions = actions
        self.content = content()
    }

    var body: some View {
        HStack(spacing: Spacing.none) {
            if edge == .leading {
                actionStrip
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .background(Palette.surface)

            if edge == .trailing {
                actionStrip
            }
        }
        .frame(height: 82)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
        .clipped()
    }

    private var actionStrip: some View {
        HStack(spacing: Spacing.none) {
            ForEach(actions) { action in
                VStack(spacing: Spacing.xs) {
                    Image(systemName: action.systemImage)
                        .rowTitleTypography()

                    Text(action.title)
                        .chipTypography()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .foregroundStyle(Palette.onAccentFill)
                .frame(width: 92)
                .frame(maxHeight: .infinity)
                .background(action.fill)
            }
        }
    }
}

private struct SwipeActionGalleryPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                previewRow(
                    title: "Expected income",
                    subtitle: "Mark as received",
                    edge: .leading,
                    actions: [.markAsReceived]
                )
                previewRow(
                    title: "Upcoming bill",
                    subtitle: "Mark as paid",
                    edge: .trailing,
                    actions: [.markAsPaid]
                )
                previewRow(
                    title: "Transaction",
                    subtitle: "Duplicate",
                    edge: .leading,
                    actions: [.duplicate]
                )
                previewRow(
                    title: "Editable row",
                    subtitle: "Edit and delete",
                    edge: .trailing,
                    actions: [.edit, .delete]
                )
            }
            .padding(Spacing.lg)
        }
        .background(Palette.background)
    }

    private func previewRow(
        title: String,
        subtitle: String,
        edge: HorizontalEdge,
        actions: [SwipeActionPreviewModel]
    ) -> some View {
        RevealedSwipeRow(edge: edge, actions: actions) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .rowTitleTypography()
                    .foregroundStyle(Palette.ink)

                Text(subtitle)
                    .rowDetailTypography()
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

private struct TransactionSwipeSetPreview: View {
    private let transaction = TransactionSnapshot(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        date: FlowPlanPreviewData.referenceDate,
        amount: 84.20,
        type: .expense,
        category: "Groceries",
        detail: "Neighbourhood market"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("LEADING ACTION")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            RevealedSwipeRow(edge: .leading, actions: [.duplicate]) {
                TransactionRow(transaction: transaction, account: "Everyday")
            }

            Text("TRAILING ACTIONS")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            RevealedSwipeRow(edge: .trailing, actions: [.edit, .delete]) {
                TransactionRow(transaction: transaction, account: "Everyday")
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(Palette.background)
    }
}

private extension SwipeActionPreviewModel {
    static let markAsReceived = SwipeActionPreviewModel(
        title: "Mark as received",
        systemImage: "checkmark.circle",
        fill: Palette.accentFill
    )
    static let markAsPaid = SwipeActionPreviewModel(
        title: "Mark as paid",
        systemImage: "checkmark.circle",
        fill: Palette.accentFill
    )
    static let edit = SwipeActionPreviewModel(
        title: "Edit",
        systemImage: "pencil",
        fill: Palette.neutralFill
    )
    static let duplicate = SwipeActionPreviewModel(
        title: "Duplicate",
        systemImage: "plus.square.on.square",
        fill: Palette.neutralFill
    )
    static let delete = SwipeActionPreviewModel(
        title: "Delete",
        systemImage: "trash",
        fill: Palette.destructiveFill
    )
}

#Preview("Swipe Actions — Revealed Light") {
    SwipeActionGalleryPreview()
        .preferredColorScheme(.light)
}

#Preview("Swipe Actions — Revealed Dark") {
    SwipeActionGalleryPreview()
        .preferredColorScheme(.dark)
}

#Preview("Transaction Swipe Set — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        TransactionSwipeSetPreview()
    }
}

#Preview("Transaction Swipe Set — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        TransactionSwipeSetPreview()
    }
}
#endif
