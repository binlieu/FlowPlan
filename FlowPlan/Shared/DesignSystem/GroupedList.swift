import SwiftUI

struct GroupedList: View {
    private let rows: [AnyView]
    private let emptyState: EmptyStateView?
    private let footer: AnyView?

    init(emptyState: EmptyStateView) {
        self.rows = []
        self.emptyState = emptyState
        self.footer = nil
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
    }

    var body: some View {
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
