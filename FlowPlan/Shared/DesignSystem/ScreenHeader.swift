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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
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
                Spacer(minLength: 0)

                trailing
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
        .listRowBackground(Palette.background)
        .listRowSeparator(.hidden)
    }
}

#if DEBUG
private struct ScreenHeaderPreviewControls: View {
    var body: some View {
        HStack(spacing: 8) {
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
        .font(.headline)
        .foregroundStyle(Palette.accent)
    }
}

private struct ScreenHeaderVariantsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
            .padding(.bottom, 24)
        }
        .background(Palette.background)
    }
}

private struct AllTabScreenHeadersPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
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
            .padding(.bottom, 24)
        }
        .background(Palette.background)
    }
}

#Preview("Screen Header — Variants") {
    ScreenHeaderVariantsPreview()
}

#Preview("Screen Header — All Tabs") {
    AllTabScreenHeadersPreview()
}

#Preview("Screen Header — Largest Dynamic Type") {
    ScreenHeaderVariantsPreview()
        .dynamicTypeSize(.accessibility5)
}
#endif
