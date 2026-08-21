import SwiftUI

private struct DesignSystemNativeContainer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, Spacing.none, for: .scrollContent)
            .contentMargins(.top, Spacing.none, for: .scrollContent)
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accent)
    }
}

private struct DesignSystemRows: ViewModifier {
    func body(content: Content) -> some View {
        ForEach(sections: content) { section in
            Section {
                ForEach(positionedRows(in: section.content)) { row in
                    row.subview
                        .groupedRowSurface(position: row.position)
                        .listRowInsets(designSystemHorizontalInsets)
                        .listRowBackground(Palette.background)
                        .listRowSeparator(.hidden)
                }
            } header: {
                section.header
                    .listRowInsets(designSystemHorizontalInsets)
            } footer: {
                section.footer
                    .listRowInsets(designSystemHorizontalInsets)
            }
        }
    }

    private func positionedRows(in subviews: SubviewsCollection) -> [PositionedRow] {
        subviews.enumerated().map { index, subview in
            PositionedRow(
                subview: subview,
                position: GroupedRowPosition(index: index, count: subviews.count)
            )
        }
    }

    private var designSystemHorizontalInsets: EdgeInsets {
        EdgeInsets(
            top: Spacing.none,
            leading: Spacing.lg,
            bottom: Spacing.none,
            trailing: Spacing.lg
        )
    }
}

private struct PositionedRow: Identifiable {
    let subview: Subview
    let position: GroupedRowPosition

    var id: Subview.ID { subview.id }
}

private struct DesignSystemBottomBar: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Palette.surface)
    }
}

extension View {
    func designSystemForm() -> some View {
        modifier(DesignSystemNativeContainer())
    }

    func designSystemList() -> some View {
        modifier(DesignSystemNativeContainer())
    }

    func designSystemRows() -> some View {
        modifier(DesignSystemRows())
    }

    func designSystemBottomBar() -> some View {
        modifier(DesignSystemBottomBar())
    }

    func designSystemSectionHeader() -> some View {
        smallCapsTypography()
            .foregroundStyle(Palette.inkSecondary)
    }

    func designSystemSectionFooter() -> some View {
        foregroundStyle(Palette.inkSecondary)
            .textCase(nil)
    }
}
