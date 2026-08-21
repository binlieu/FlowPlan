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
            // A Section wrapped by ViewModifier.Content arrives here as one proxy. Resolve that
            // proxy's rows before assigning first and last positions.
            Group(subviews: section.content) { rows in
                Section {
                    ForEach(positionedRows(in: rows)) { row in
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

#if DEBUG
private struct DesignSystemRowsPreview: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("First row", value: "Top corners")
                LabeledContent("Second row", value: "Square corners")
                LabeledContent("Third row", value: "Bottom corners")
            } header: {
                Text("Three-row section")
                    .designSystemSectionHeader()
            }
            .designSystemRows()

            Section {
                LabeledContent("Only row", value: "All corners")
            } header: {
                Text("Single-row section")
                    .designSystemSectionHeader()
            }
            .designSystemRows()
        }
        .designSystemForm()
    }
}

#Preview("Grouped Form Sections — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        DesignSystemRowsPreview()
    }
}

#Preview("Grouped Form Sections — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        DesignSystemRowsPreview()
    }
}
#endif

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
