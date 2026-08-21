import SwiftUI

enum ListRowLeading {
    case none
    case monogram(String)
    case icon(systemName: String, color: Color)
}

struct ListRowStatus {
    let text: String
    let style: Chip.Style
    var systemImage: String? = nil
}

struct ListRow<Supplementary: View>: View {
    enum AmountStyle {
        case primary
        case secondary
    }

    enum StatusPlacement {
        case detail
        case trailing
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 32

    let leading: ListRowLeading
    let title: String
    let subtitle: String?
    let trailingAmount: String?
    let trailingSubtitle: String?
    let amountStyle: AmountStyle
    let amountColor: Color
    let amountAccessibilityLabel: String?
    let statuses: [ListRowStatus]
    let statusPlacement: StatusPlacement
    let trailingAccessory: AnyView?
    let contentInsets: EdgeInsets
    let isDimmed: Bool
    let combinesAccessibilityChildren: Bool
    private let supplementary: Supplementary

    init(
        leading: ListRowLeading = .none,
        title: String,
        subtitle: String? = nil,
        trailingAmount: String? = nil,
        trailingSubtitle: String? = nil,
        amountStyle: AmountStyle = .primary,
        amountColor: Color = Palette.ink,
        amountAccessibilityLabel: String? = nil,
        statuses: [ListRowStatus] = [],
        statusPlacement: StatusPlacement = .trailing,
        trailingAccessory: AnyView? = nil,
        contentInsets: EdgeInsets = EdgeInsets(
            top: Spacing.md,
            leading: Spacing.md,
            bottom: Spacing.md,
            trailing: Spacing.md
        ),
        isDimmed: Bool = false,
        combinesAccessibilityChildren: Bool = true,
        @ViewBuilder supplementary: () -> Supplementary
    ) {
        self.leading = leading
        self.title = title
        self.subtitle = subtitle
        self.trailingAmount = trailingAmount
        self.trailingSubtitle = trailingSubtitle
        self.amountStyle = amountStyle
        self.amountColor = amountColor
        self.amountAccessibilityLabel = amountAccessibilityLabel
        self.statuses = statuses
        self.statusPlacement = statusPlacement
        self.trailingAccessory = trailingAccessory
        self.contentInsets = contentInsets
        self.isDimmed = isDimmed
        self.combinesAccessibilityChildren = combinesAccessibilityChildren
        self.supplementary = supplementary()
    }

    @ViewBuilder
    var body: some View {
        if combinesAccessibilityChildren {
            rowContent
                .accessibilityElement(children: .combine)
        } else {
            rowContent
                .accessibilityElement(children: .contain)
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }

            supplementary
        }
        .padding(contentInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(isDimmed ? 0.55 : 1)
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            leadingContent
            identityContent

            Spacer(minLength: Spacing.sm)

            trailingContent
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.md) {
                leadingContent
                identityContent
            }

            if hasTrailingContent {
                trailingContent
            }
        }
    }

    @ViewBuilder
    private var leadingContent: some View {
        switch leading {
        case .none:
            EmptyView()
        case .monogram(let text):
            Text(text)
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)
                .frame(width: 54, height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control)
                        .stroke(Palette.hairline, lineWidth: 1)
                }
                .accessibilityHidden(true)
        case .icon(let systemName, let color):
            Image(systemName: systemName)
                .iconTypography()
                .foregroundStyle(color)
                .frame(width: iconSize, height: iconSize)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var identityContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .rowTitleTypography()
                .foregroundStyle(Palette.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .rowDetailTypography()
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if statusPlacement == .detail {
                statusContent
            }
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private var trailingContent: some View {
        if hasTrailingContent {
            VStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                spacing: Spacing.xxs
            ) {
                if let trailingAmount {
                    amountText(trailingAmount)
                }

                if let trailingSubtitle {
                    Text(trailingSubtitle)
                        .rowDetailTypography()
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if statusPlacement == .trailing {
                    statusContent
                }

                if let trailingAccessory {
                    trailingAccessory
                }
            }
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
        }
    }

    @ViewBuilder
    private func amountText(_ amount: String) -> some View {
        switch amountStyle {
        case .primary:
            Text(amount)
                .rowAmountTypography()
                .monospacedDigit()
                .foregroundStyle(amountColor)
                .accessibilityLabel(amountAccessibilityLabel ?? amount)
        case .secondary:
            Text(amount)
                .rowDetailEmphasisTypography()
                .monospacedDigit()
                .foregroundStyle(amountColor)
                .accessibilityLabel(amountAccessibilityLabel ?? amount)
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        if !statuses.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) {
                    statusChips
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    statusChips
                }
            }
        }
    }

    @ViewBuilder
    private var statusChips: some View {
        ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
            Chip(text: status.text, style: status.style, systemImage: status.systemImage)
        }
    }

    private var hasTrailingContent: Bool {
        trailingAmount != nil
            || trailingSubtitle != nil
            || (statusPlacement == .trailing && !statuses.isEmpty)
            || trailingAccessory != nil
    }
}

extension ListRow where Supplementary == EmptyView {
    init(
        leading: ListRowLeading = .none,
        title: String,
        subtitle: String? = nil,
        trailingAmount: String? = nil,
        trailingSubtitle: String? = nil,
        amountStyle: AmountStyle = .primary,
        amountColor: Color = Palette.ink,
        amountAccessibilityLabel: String? = nil,
        statuses: [ListRowStatus] = [],
        statusPlacement: StatusPlacement = .trailing,
        trailingAccessory: AnyView? = nil,
        contentInsets: EdgeInsets = EdgeInsets(
            top: Spacing.md,
            leading: Spacing.md,
            bottom: Spacing.md,
            trailing: Spacing.md
        ),
        isDimmed: Bool = false,
        combinesAccessibilityChildren: Bool = true
    ) {
        self.init(
            leading: leading,
            title: title,
            subtitle: subtitle,
            trailingAmount: trailingAmount,
            trailingSubtitle: trailingSubtitle,
            amountStyle: amountStyle,
            amountColor: amountColor,
            amountAccessibilityLabel: amountAccessibilityLabel,
            statuses: statuses,
            statusPlacement: statusPlacement,
            trailingAccessory: trailingAccessory,
            contentInsets: contentInsets,
            isDimmed: isDimmed,
            combinesAccessibilityChildren: combinesAccessibilityChildren,
            supplementary: EmptyView.init
        )
    }
}

#if DEBUG
#Preview("List Rows") {
    VStack(spacing: Spacing.none) {
        ListRow(
            leading: .monogram("RE"),
            title: "Rent",
            subtitle: "Aug 1",
            trailingAmount: "$1,850",
            statuses: [ListRowStatus(text: "AUTO PAY", style: .filledNeutral)]
        )

        Divider()

        ListRow(
            leading: .icon(systemName: "cart", color: Palette.info),
            title: "Groceries",
            subtitle: "Food · Checking",
            trailingAmount: "-$82.40",
            amountStyle: .secondary
        )
    }
    .background(Palette.surface)
}
#endif
