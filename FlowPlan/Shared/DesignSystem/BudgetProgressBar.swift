import SwiftUI

struct BudgetProgressBar: View {
    let spent: Decimal
    let limit: Decimal

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Palette.background)

                if isOverBudget {
                    BudgetHatch()
                        .frame(width: proxy.size.width)
                } else {
                    Rectangle()
                        .fill(Palette.accent)
                        .frame(width: proxy.size.width * fillFraction)
                }
            }
            .clipShape(Rectangle())
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget progress")
        .accessibilityValue(accessibilityValue)
    }

    private var isOverBudget: Bool {
        spent > limit
    }

    private var fillFraction: CGFloat {
        guard limit > .zero else {
            return .zero
        }

        let ratio = spent / limit
        let value = NSDecimalNumber(decimal: ratio).doubleValue
        return CGFloat(min(1, max(0, value)))
    }

    private var accessibilityValue: String {
        if isOverBudget {
            return "Over budget"
        }

        return "\(Int(fillFraction * 100)) percent used"
    }
}

private struct BudgetHatch: View {
    var body: some View {
        ZStack {
            Palette.surface

            BudgetDiagonalHatchShape()
                .stroke(Palette.accentMuted, lineWidth: 1)
        }
        .clipped()
    }
}

private struct BudgetDiagonalHatchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let spacing: CGFloat = Spacing.xs
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
#Preview("Budget Progress") {
    VStack(spacing: Spacing.lg) {
        BudgetProgressBar(spent: 350, limit: 800)
        BudgetProgressBar(spent: 900, limit: 800)
    }
    .padding(Spacing.md)
    .background(Palette.background)
}
#endif
