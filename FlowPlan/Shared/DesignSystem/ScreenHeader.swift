import SwiftUI

/// The title block at the top of every tab. Owns the title, optional small-caps subtitle and
/// the top padding, so headers cannot drift apart between screens again.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        // Aligned on the title's first baseline, not centred. Trailing controls are taller than
        // the title text, so centring pushed the title down on screens that have them — making
        // Activity's header sit lower than Home's and Settings'.
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
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
            .layoutPriority(1)

            if let trailing {
                Spacer(minLength: Spacing.none)

                trailing
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .listRowInsets(EdgeInsets(top: Spacing.none, leading: Spacing.none, bottom: Spacing.sm, trailing: Spacing.none))
        .listRowBackground(Palette.background)
        .listRowSeparator(.hidden)
    }
}

#if DEBUG
private struct ScreenHeaderPreviewControls: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Filter transactions")

            Button(action: {}) {
                Image(systemName: "plus")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Add transaction")
        }
        .prominentLabelTypography()
        .foregroundStyle(Palette.accent)
    }
}

private struct ScreenHeaderVariantsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ScreenHeader(title: "Insights")
                ScreenHeader(
                    title: "Plan",
                    subtitle: "August 2026"
                )
                ScreenHeader(
                    title: "Activity",
                    trailing: AnyView(ScreenHeaderPreviewControls())
                )
                ScreenHeader(
                    title: "Settings",
                    subtitle: "Profile, preferences & data",
                    trailing: AnyView(ScreenHeaderPreviewControls())
                )
            }
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.background)
    }
}

private struct AllTabScreenHeadersPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.none) {
                ScreenHeader(
                    title: "Good morning, Taylor",
                    subtitle: "Know where your money goes"
                )
                Divider()
                ScreenHeader(
                    title: "Activity",
                    trailing: AnyView(ScreenHeaderPreviewControls())
                )
                Divider()
                ScreenHeader(title: "Plan", subtitle: "August 2026")
                Divider()
                ScreenHeader(title: "Insights")
                Divider()
                ScreenHeader(
                    title: "Settings",
                    subtitle: "Profile, preferences & data"
                )
            }
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.background)
    }
}

#Preview("Screen Header — Variants") {
    ScreenHeaderVariantsPreview()
}

#Preview("Screen Header — All Tabs — Light") {
    AllTabScreenHeadersPreview()
        .preferredColorScheme(.light)
}

#Preview("Screen Header — All Tabs — Dark") {
    AllTabScreenHeadersPreview()
        .preferredColorScheme(.dark)
}

#Preview("Screen Header — Largest Dynamic Type") {
    ScreenHeaderVariantsPreview()
        .dynamicTypeSize(.accessibility5)
}
#endif
