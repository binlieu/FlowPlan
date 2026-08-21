import SwiftUI

private struct GroupedListOwnsHorizontalRowPaddingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var groupedListOwnsHorizontalRowPadding: Bool {
        get { self[GroupedListOwnsHorizontalRowPaddingKey.self] }
        set { self[GroupedListOwnsHorizontalRowPaddingKey.self] = newValue }
    }
}

struct GroupedList: View {
    private enum Presentation {
        case card
        case swipeEnabledListRows
    }

    private let rows: [AnyView]
    private let emptyState: EmptyStateView?
    private let footer: AnyView?
    private let sectionHeader: AnyView?
    private let presentation: Presentation

    init(emptyState: EmptyStateView) {
        self.rows = []
        self.emptyState = emptyState
        self.footer = nil
        self.sectionHeader = nil
        self.presentation = .card
    }

    init<Data: RandomAccessCollection, RowContent: View>(
        _ data: Data,
        emptyState: EmptyStateView? = nil,
        footer: AnyView? = nil,
        @ViewBuilder rowContent: (Data.Element) -> RowContent
    ) {
        self.rows = data.map { AnyView(rowContent($0)) }
        self.emptyState = emptyState
        self.footer = footer
        self.sectionHeader = nil
        self.presentation = .card
    }

    init<
        Data: RandomAccessCollection,
        RowContent: View,
        LeadingActions: View,
        TrailingActions: View
    >(
        _ data: Data,
        header: AnyView,
        leadingSwipeAllowsFullSwipe: Bool = false,
        trailingSwipeAllowsFullSwipe: Bool = false,
        @ViewBuilder rowContent: (Data.Element) -> RowContent,
        @ViewBuilder leadingSwipeActions: (Data.Element) -> LeadingActions,
        @ViewBuilder trailingSwipeActions: (Data.Element) -> TrailingActions
    ) {
        // SwiftUI discovers swipe actions at native List row boundaries, so this presentation
        // keeps each item as a row while drawing those rows as one connected grouped surface.
        let elements = Array(data)

        self.rows = elements.enumerated().map { index, element in
            AnyView(
                SwipeEnabledGroupedListRow(
                    position: GroupedRowPosition(index: index, count: elements.count),
                    leadingSwipeAllowsFullSwipe: leadingSwipeAllowsFullSwipe,
                    trailingSwipeAllowsFullSwipe: trailingSwipeAllowsFullSwipe,
                    content: rowContent(element),
                    leadingActions: leadingSwipeActions(element),
                    trailingActions: trailingSwipeActions(element)
                )
            )
        }
        self.emptyState = nil
        self.footer = nil
        self.sectionHeader = header
        self.presentation = .swipeEnabledListRows
    }

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .card:
            card
        case .swipeEnabledListRows:
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    row
                }
            } header: {
                sectionHeader
                    .listRowInsets(
                        EdgeInsets(
                            top: Spacing.none,
                            leading: Spacing.lg,
                            bottom: Spacing.none,
                            trailing: Spacing.lg
                        )
                    )
            }
        }
    }

    private var card: some View {
        CardSurface(contentPadding: Spacing.none) {
            VStack(spacing: Spacing.none) {
                if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        row

                        if index < rows.count - 1 {
                            separator
                        }
                    }
                }

                if let footer {
                    if !rows.isEmpty || emptyState != nil {
                        separator
                    }

                    footer
                }
            }
        }
    }

    private var separator: some View {
        Divider()
            .overlay(Palette.hairline)
            .accessibilityHidden(true)
    }
}

private struct SwipeEnabledGroupedListRow<
    Content: View,
    LeadingActions: View,
    TrailingActions: View
>: View {
    let position: GroupedRowPosition
    let leadingSwipeAllowsFullSwipe: Bool
    let trailingSwipeAllowsFullSwipe: Bool
    let content: Content
    let leadingActions: LeadingActions
    let trailingActions: TrailingActions

    var body: some View {
        content
            .environment(\.groupedListOwnsHorizontalRowPadding, true)
            .groupedRowSurface(position: position)
            .listRowInsets(
                EdgeInsets(
                    top: Spacing.none,
                    leading: Spacing.lg,
                    bottom: Spacing.none,
                    trailing: Spacing.lg
                )
            )
            .listRowBackground(Palette.background)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .leading, allowsFullSwipe: leadingSwipeAllowsFullSwipe) {
                leadingActions
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: trailingSwipeAllowsFullSwipe) {
                trailingActions
            }
    }
}

struct GroupedRowPosition {
    let isFirst: Bool
    let isLast: Bool

    init(index: Int, count: Int) {
        isFirst = index == 0
        isLast = index == count - 1
    }
}

private struct GroupedRowSurface: ViewModifier {
    let position: GroupedRowPosition

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Palette.surface)
            .clipShape(rowShape)
            .overlay {
                rowShape
                    .stroke(Palette.hairline, lineWidth: 1)
                    .accessibilityHidden(true)
            }
    }

    private var rowShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: position.isFirst ? Radius.card : Spacing.none,
            bottomLeadingRadius: position.isLast ? Radius.card : Spacing.none,
            bottomTrailingRadius: position.isLast ? Radius.card : Spacing.none,
            topTrailingRadius: position.isFirst ? Radius.card : Spacing.none
        )
    }
}

extension View {
    func groupedRowSurface(position: GroupedRowPosition) -> some View {
        modifier(GroupedRowSurface(position: position))
    }
}

#if DEBUG
private struct GroupedListPaddingPreview: View {
    private let rows = [
        PreviewRow(title: "Miscellaneous expense", subtitle: "Other", amount: "-$210.00"),
        PreviewRow(
            title: "Annual vehicle registration",
            subtitle: "Transport · Everyday",
            amount: "-$186.00"
        )
    ]

    var body: some View {
        List {
            GroupedList(
                rows,
                header: AnyView(
                    Text("GROUPED LIST")
                        .designSystemSectionHeader()
                ),
                rowContent: previewRow,
                leadingSwipeActions: { _ in EmptyView() },
                trailingSwipeActions: { _ in EmptyView() }
            )

            Section {
                ForEach(rows) { row in
                    previewRow(row)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Palette.surface)
                }
            } header: {
                Text("STANDALONE LIST ROWS")
                    .designSystemSectionHeader()
            }
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(Spacing.none)
        .designSystemList()
    }

    private func previewRow(_ row: PreviewRow) -> some View {
        ListRow(
            leading: .icon(systemName: "cart", color: Palette.info),
            title: row.title,
            subtitle: row.subtitle,
            trailingAmount: row.amount,
            amountStyle: .secondary
        )
    }

    private struct PreviewRow: Identifiable {
        let title: String
        let subtitle: String
        let amount: String

        var id: String { title }
    }
}

#Preview("Grouped and Standalone Rows — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        GroupedListPaddingPreview()
    }
}

#Preview("Grouped and Standalone Rows — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        GroupedListPaddingPreview()
    }
}

#Preview("Grouped and Standalone Rows — Largest Type") {
    FlowPlanPreviewHost {
        GroupedListPaddingPreview()
            .dynamicTypeSize(.accessibility5)
    }
}
#endif
