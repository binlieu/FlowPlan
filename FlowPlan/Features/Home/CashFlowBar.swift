import SwiftUI
import FlowPlanDomain

struct CashFlowBar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let projection: MonthlyProjection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CASH FLOW")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            ProportionalSegmentsLayout(weights: segmentWeights) {
                Rectangle()
                    .fill(Palette.accent)
                    .overlay {
                        Rectangle().stroke(Palette.hairline, lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                Rectangle()
                    .fill(Palette.accentLight)
                    .overlay {
                        Rectangle().stroke(Palette.hairline, lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                HatchedSegment(
                    accessibilityValue: accessibleEstimatedSavings
                )
            }
            .frame(height: 26)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Cash flow")
            .accessibilityValue(accessibilitySummary)

            legend
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var legend: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                legendItem(expensesLegend)
                legendItem(savingsLegend)
                legendItem(estimatedSavingsLegend)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                legendItem(expensesLegend)
                legendItem(savingsLegend)
                legendItem(estimatedSavingsLegend)
            }
        }
    }

    private func legendItem(_ item: LegendItemModel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                legendSwatch(item)

                Text(item.label)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Text(item.value)
                .font(.subheadline.weight(.semibold))
                .fontWidth(.condensed)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 23)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func legendSwatch(_ item: LegendItemModel) -> some View {
        switch item.kind {
        case .solid(let color):
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 16)
        case .hatched:
            HatchedSegment(accessibilityValue: "")
                .frame(width: 16, height: 16)
        }
    }

    private var segmentWeights: [CGFloat] {
        [
            chartWeight(projection.expensesPaid),
            chartWeight(projection.savingsCompleted),
            chartWeight(projection.projectedEndOfMonthBalance)
        ]
    }

    private var accessibilitySummary: String {
        "Expenses \(accessibleMoney(projection.expensesPaid)); savings \(accessibleMoney(projection.savingsCompleted)); estimated savings \(accessibleEstimatedSavings)."
    }

    private var accessibleEstimatedSavings: String {
        accessibleMoney(projection.projectedEndOfMonthBalance)
    }

    private var expensesLegend: LegendItemModel {
        LegendItemModel(
            label: "Expenses",
            value: money(projection.expensesPaid),
            kind: .solid(Palette.accent)
        )
    }

    private var savingsLegend: LegendItemModel {
        LegendItemModel(
            label: "Savings",
            value: money(projection.savingsCompleted),
            kind: .solid(Palette.accentLight)
        )
    }

    private var estimatedSavingsLegend: LegendItemModel {
        LegendItemModel(
            label: "Estimated savings",
            value: money(projection.projectedEndOfMonthBalance),
            kind: .hatched
        )
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func chartWeight(_ amount: Decimal) -> CGFloat {
        max(0, CGFloat(NSDecimalNumber(decimal: amount).doubleValue))
    }

    private struct LegendItemModel {
        let label: String
        let value: String
        let kind: SwatchKind
    }

    private enum SwatchKind {
        case solid(Color)
        case hatched
    }
}

struct ProportionalSegmentsLayout: Layout {
    let weights: [CGFloat]

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let fallbackWidth = subviews.reduce(CGFloat.zero) { partialResult, subview in
            partialResult + subview.sizeThatFits(.unspecified).width
        }
        let fallbackHeight = subviews.reduce(CGFloat.zero) { currentHeight, subview in
            max(currentHeight, subview.sizeThatFits(.unspecified).height)
        }

        return CGSize(
            width: proposal.width ?? fallbackWidth,
            height: proposal.height ?? fallbackHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let resolvedWeights = subviews.indices.map { index in
            index < weights.count ? max(0, weights[index]) : 0
        }
        let totalWeight = resolvedWeights.reduce(CGFloat.zero, +)
        var nextX = bounds.minX

        for index in subviews.indices {
            let segmentWidth: CGFloat
            if index == subviews.indices.last {
                segmentWidth = bounds.maxX - nextX
            } else if totalWeight > 0 {
                segmentWidth = bounds.width * resolvedWeights[index] / totalWeight
            } else {
                segmentWidth = 0
            }

            subviews[index].place(
                at: CGPoint(x: nextX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: segmentWidth, height: bounds.height)
            )
            nextX += segmentWidth
        }
    }
}

private struct HatchedSegment: View {
    let accessibilityValue: String

    var body: some View {
        ZStack {
            Palette.surface

            DiagonalHatchShape()
                .stroke(Palette.accentMuted, lineWidth: 1)
        }
        .clipped()
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated savings hatched segment")
        .accessibilityValue(accessibilityValue)
    }
}

private struct DiagonalHatchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let spacing: CGFloat = 8
        var path = Path()
        var x = rect.minX - rect.height

        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }

        return path
    }
}

#if DEBUG
#Preview("Cash Flow — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        CashFlowBar(projection: FlowPlanPreviewData.projection())
            .padding()
            .background(Palette.background)
    }
}

#Preview("Cash Flow — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        CashFlowBar(projection: FlowPlanPreviewData.projection())
            .padding()
            .background(Palette.background)
    }
}
#endif
