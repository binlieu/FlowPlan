import SwiftUI
import FlowPlanDomain

struct QuickAddRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedAction: QuickAddAction?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("QUICK ADD")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: accessibilityColumns, spacing: Spacing.sm) {
                    quickAddButtons
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    quickAddButtons
                }
            }
        }
        .sheet(item: $selectedAction) { action in
            AddTransactionView(duplicateOf: action.seedTransaction)
        }
    }

    @ViewBuilder
    private var quickAddButtons: some View {
        ForEach(QuickAddAction.allCases) { action in
            Button {
                selectedAction = action
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: action.symbol)
                        .iconTypography()

                    Text(action.title)
                        .smallCapsTypography()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 72)
                .padding(.horizontal, Spacing.xxs)
                .overlay {
                    Rectangle().stroke(Palette.hairline, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(action.accessibilityName)")
        }
    }

    private var accessibilityColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm)
        ]
    }

    private enum QuickAddAction: String, CaseIterable, Identifiable {
        case income
        case expense
        case bill
        case transfer

        var id: String { rawValue }

        var title: String {
            rawValue.uppercased()
        }

        var accessibilityName: String {
            rawValue
        }

        var symbol: String {
            switch self {
            case .income: return "arrow.up"
            case .expense: return "arrow.down"
            case .bill: return "doc.text"
            case .transfer: return "arrow.left.arrow.right"
            }
        }

        var transactionType: TransactionType {
            switch self {
            case .income: return .income
            case .expense, .bill: return .expense
            case .transfer: return .transfer
            }
        }

        var seedTransaction: TransactionSnapshot {
            // TODO(spec-06): Present AddTransactionView directly in bill mode once it exposes that route.
            TransactionSnapshot(
                id: UUID(),
                date: Date(),
                amount: .zero,
                type: transactionType,
                category: "",
                detail: ""
            )
        }
    }
}

#if DEBUG
#Preview("Quick Add — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        QuickAddRow()
            .padding(Spacing.md)
            .background(Palette.background)
    }
}

#Preview("Quick Add — Accessibility") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        QuickAddRow()
            .padding(Spacing.md)
            .background(Palette.background)
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
