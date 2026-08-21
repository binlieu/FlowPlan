import SwiftUI

enum Typography {
    struct Greeting: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.title, design: .default, weight: .bold))
                .fontWidth(.condensed)
                .tracking(-0.4)
        }
    }

    struct SectionHeading: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.title2, design: .default, weight: .bold))
                .fontWidth(.condensed)
                .tracking(-0.25)
        }
    }

    struct HeroAmount: ViewModifier {
        @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44
        @ScaledMetric(relativeTo: .largeTitle) private var tracking: CGFloat = -0.7

        func body(content: Content) -> some View {
            content
                .font(.system(size: size, weight: .bold, design: .default))
                .fontWidth(.condensed)
                .tracking(tracking)
        }
    }

    struct LargeAmount: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.title, design: .default, weight: .bold))
                .fontWidth(.condensed)
                .tracking(-0.4)
        }
    }

    struct Value: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.title2, design: .default, weight: .bold))
                .fontWidth(.condensed)
                .tracking(-0.2)
        }
    }

    struct SmallCaps: ViewModifier {
        @ScaledMetric(relativeTo: .caption) private var tracking: CGFloat = 0.96

        func body(content: Content) -> some View {
            content
                .font(.system(.caption, design: .default, weight: .semibold))
                .fontWidth(.condensed)
                .textCase(.uppercase)
                .tracking(tracking)
        }
    }

    struct Body: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.body, design: .default))
        }
    }

    struct RowTitle: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.body, design: .default, weight: .semibold))
        }
    }

    struct RowDetail: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.subheadline, design: .default))
        }
    }

    struct RowDetailEmphasis: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .fontWidth(.condensed)
        }
    }

    struct ProminentLabel: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.headline, design: .default))
        }
    }

    struct RowAmount: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.headline, design: .default, weight: .bold))
                .fontWidth(.condensed)
        }
    }

    struct FormAmount: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fontWidth(.condensed)
        }
    }

    struct Footnote: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.footnote, design: .default))
        }
    }

    struct Caption: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.caption, design: .default))
                .fontWidth(.condensed)
        }
    }

    struct CaptionEmphasis: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.caption, design: .default, weight: .semibold))
                .fontWidth(.condensed)
        }
    }

    struct Chip: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.caption2, design: .default, weight: .bold))
                .fontWidth(.condensed)
                .tracking(0.6)
        }
    }

    struct Icon: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.title3, design: .default, weight: .semibold))
        }
    }

    struct LockTitle: ViewModifier {
        func body(content: Content) -> some View {
            content.font(.system(.title, design: .default, weight: .bold))
        }
    }

    struct AppIcon: ViewModifier {
        @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 72

        func body(content: Content) -> some View {
            content.font(.system(size: size))
        }
    }

    struct BreakdownTitle: ViewModifier {
        let isTotal: Bool

        func body(content: Content) -> some View {
            content.font(
                isTotal
                    ? .system(.headline, design: .default)
                    : .system(.body, design: .default, weight: .semibold)
            )
        }
    }
}

extension View {
    func greetingTypography() -> some View {
        modifier(Typography.Greeting())
    }

    func sectionHeadingTypography() -> some View {
        modifier(Typography.SectionHeading())
    }

    func heroAmountTypography() -> some View {
        modifier(Typography.HeroAmount())
    }

    func largeAmountTypography() -> some View {
        modifier(Typography.LargeAmount())
    }

    func valueTypography() -> some View {
        modifier(Typography.Value())
    }

    func smallCapsTypography() -> some View {
        modifier(Typography.SmallCaps())
    }

    func bodyTypography() -> some View {
        modifier(Typography.Body())
    }

    func rowTitleTypography() -> some View {
        modifier(Typography.RowTitle())
    }

    func rowDetailTypography() -> some View {
        modifier(Typography.RowDetail())
    }

    func rowDetailEmphasisTypography() -> some View {
        modifier(Typography.RowDetailEmphasis())
    }

    func prominentLabelTypography() -> some View {
        modifier(Typography.ProminentLabel())
    }

    func rowAmountTypography() -> some View {
        modifier(Typography.RowAmount())
    }

    func formAmountTypography() -> some View {
        modifier(Typography.FormAmount())
    }

    func footnoteTypography() -> some View {
        modifier(Typography.Footnote())
    }

    func captionTypography() -> some View {
        modifier(Typography.Caption())
    }

    func captionEmphasisTypography() -> some View {
        modifier(Typography.CaptionEmphasis())
    }

    func chipTypography() -> some View {
        modifier(Typography.Chip())
    }

    func iconTypography() -> some View {
        modifier(Typography.Icon())
    }

    func lockTitleTypography() -> some View {
        modifier(Typography.LockTitle())
    }

    func appIconTypography() -> some View {
        modifier(Typography.AppIcon())
    }

    func breakdownTitleTypography(isTotal: Bool) -> some View {
        modifier(Typography.BreakdownTitle(isTotal: isTotal))
    }
}
