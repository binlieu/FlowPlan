import SwiftUI

#if DEBUG
private struct DesignSystemGallery: View {
    private let rows = [
        GalleryRow(id: "rent", monogram: "RE", title: "Rent", subtitle: "Due Aug 1", amount: "$1,850"),
        GalleryRow(id: "power", monogram: "PO", title: "Power", subtitle: "Due Aug 14", amount: "$96")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ScreenHeader(
                    title: "Design system",
                    subtitle: "Shared component gallery"
                )

                VStack(alignment: .leading, spacing: Spacing.lg) {
                    SectionHeading(title: "Expected Income", actionTitle: "Add") {}

                    ListRow(
                        leading: .icon(systemName: "cart", color: Palette.info),
                        title: "Groceries",
                        subtitle: "Food · Checking",
                        trailingAmount: "-$82.40",
                        amountStyle: .secondary,
                        statuses: [ListRowStatus(text: "AUTO", style: .filledNeutral)],
                        statusPlacement: .detail
                    )

                    GroupedList(rows) { row in
                        ListRow(
                            leading: .monogram(row.monogram),
                            title: row.title,
                            subtitle: row.subtitle,
                            trailingAmount: row.amount,
                            statuses: [
                                ListRowStatus(text: "AUTO PAY", style: .outlinedAccent)
                            ]
                        )
                    }

                    PlanTotalRow(label: "TOTAL MONTHLY BILLS", amount: 1_946, signed: false)

                    TickCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Signature card")
                                .prominentLabelTypography()
                            Text("Every card uses the same surface, border and radius.")
                                .rowDetailTypography()
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }

                    HStack(spacing: Spacing.xs) {
                        Chip(text: "FIXED", style: .outlinedAccent)
                        Chip(text: "AUTO PAY", style: .filledNeutral)
                        Chip(
                            text: "OVERDUE",
                            style: .warning,
                            systemImage: "exclamationmark.circle"
                        )
                    }

                    EmptyStateView(
                        symbol: "tray",
                        title: "Nothing here yet",
                        message: "Empty states use one shared layout and typography."
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
    }

    private struct GalleryRow: Identifiable {
        let id: String
        let monogram: String
        let title: String
        let subtitle: String
        let amount: String
    }
}

#Preview("Design System Gallery — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        DesignSystemGallery()
    }
}

#Preview("Design System Gallery — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        DesignSystemGallery()
    }
}

#Preview("Design System Gallery — Largest Type") {
    FlowPlanPreviewHost {
        DesignSystemGallery()
            .dynamicTypeSize(.accessibility5)
    }
}
#endif
