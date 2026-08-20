import SwiftUI

enum Typography {
    static let body = Font.system(.body, design: .default)
    static let supporting = Font.system(.subheadline, design: .default)

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
}
