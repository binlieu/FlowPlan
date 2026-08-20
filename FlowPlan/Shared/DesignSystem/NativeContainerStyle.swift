import SwiftUI

struct DesignSystemScreenHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .greetingTypography()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .smallCapsTypography()
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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

private struct DesignSystemScreenHeaderRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(
                EdgeInsets(top: 24, leading: 20, bottom: 12, trailing: 20)
            )
            .listRowBackground(Palette.background)
            .listRowSeparator(.hidden)
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

    func designSystemScreenHeaderRow() -> some View {
        modifier(DesignSystemScreenHeaderRow())
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
