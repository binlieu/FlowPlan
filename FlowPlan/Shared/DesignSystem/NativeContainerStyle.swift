import SwiftUI

private struct DesignSystemNativeContainer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accent)
    }
}

private struct DesignSystemRows: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Palette.surface)
            .listRowSeparatorTint(Palette.hairline)
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

    func designSystemSectionHeader() -> some View {
        smallCapsTypography()
            .foregroundStyle(Palette.inkSecondary)
    }

    func designSystemSectionFooter() -> some View {
        foregroundStyle(Palette.inkSecondary)
            .textCase(nil)
    }
}
