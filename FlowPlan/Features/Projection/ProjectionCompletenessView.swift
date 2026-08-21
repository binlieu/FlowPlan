import SwiftUI
import FlowPlanDomain

struct ProjectionCompletenessView: View {
    let completeness: ProjectionCompleteness

    var body: some View {
        CardSurface(contentPadding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Projection based on:")
                    .prominentLabelTypography()

                ForEach(checklistItems) { item in
                    Label {
                        Text(item.title)
                            .foregroundStyle(Palette.ink)
                    } icon: {
                        Image(systemName: item.isPresent
                              ? "checkmark.circle.fill"
                              : "exclamationmark.triangle")
                            .foregroundStyle(item.isPresent ? Palette.positive : Palette.warning)
                    }
                    .accessibilityLabel(
                        "\(item.title), \(item.isPresent ? "present" : "missing")"
                    )
                }

                if !missingReasons.isEmpty {
                    Text(incompleteMessage)
                        .footnoteTypography()
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xxs)
                }
            }
        }
    }

    private var checklistItems: [ChecklistItem] {
        [
            ChecklistItem(
                id: "income",
                title: "Income planned",
                missingReason: "income is not planned",
                isPresent: completeness.hasPlannedIncome
            ),
            ChecklistItem(
                id: "bills",
                title: "Bills entered",
                missingReason: "bills have not been entered",
                isPresent: completeness.hasBills
            ),
            ChecklistItem(
                id: "savings",
                title: "Savings goal entered",
                missingReason: "a savings goal has not been entered",
                isPresent: completeness.hasSavingsGoal
            ),
            ChecklistItem(
                id: "spending",
                title: "Spending budget entered",
                missingReason: "a spending budget has not been entered",
                isPresent: completeness.hasSpendingBudget
            ),
            ChecklistItem(
                id: "balance",
                title: "Starting balance entered",
                missingReason: "a starting balance has not been entered",
                isPresent: completeness.hasStartingBalance
            )
        ]
    }

    private var missingReasons: [String] {
        checklistItems.filter { !$0.isPresent }.map(\.missingReason)
    }

    private var incompleteMessage: String {
        let reasons = ListFormatter.localizedString(byJoining: missingReasons)
        return "Your projection may be incomplete because \(reasons)."
    }

    private struct ChecklistItem: Identifiable {
        let id: String
        let title: String
        let missingReason: String
        let isPresent: Bool
    }
}
