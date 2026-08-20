# Codex task spec — 09 — Design system + Home redesign to match the handoff

## Goal
Rebuild Home to match the approved design handoff exactly, and introduce the design system
(palette, typography, card style) that every later screen will use.

**The owner has decided the design ships as drawn.** `AVAILABLE THIS MONTH` is the Home hero;
the full projection breakdown moves off Home. Do not argue with this in code or comments.

## Scope — touch ONLY these
Create:
- `FlowPlan/Shared/DesignSystem/Palette.swift`
- `FlowPlan/Shared/DesignSystem/Typography.swift`
- `FlowPlan/Shared/DesignSystem/TickCard.swift`
- `FlowPlan/Features/Home/CashFlowBar.swift`
- `FlowPlan/Features/Home/EstimatedSavingsCard.swift`
- `FlowPlan/Features/Home/MonthSpendingCard.swift`
- `FlowPlan/Features/Home/QuickAddRow.swift`
- `FlowPlan/Features/Home/AvailableThisMonthCard.swift`
- `FlowPlan/Resources/Assets.xcassets/Colors/…` (colour sets, light + dark)

Replace the bodies of:
- `FlowPlan/Features/Home/HomeView.swift`
- `FlowPlan/Features/Home/UpcomingBillsSection.swift`
- `FlowPlan/App/RootView.swift`
- `FlowPlan/Shared/Components/MonthNavigationBar.swift`
- `FlowPlan/Shared/Components/StatTile.swift`

Delete `FlowPlan/Features/Home/ProjectionHeroCard.swift` and
`FlowPlan/Features/Home/SafeToSpendCard.swift` — both are superseded.

Do NOT modify `Packages/FlowPlanDomain/**`, `FlowPlan/Data/**`, `AppState`, `ProjectionStore`,
`FlowPlan/Features/Projection/**`, `FlowPlan/Features/Transactions/**`, or the Xcode project.

## Palette — sampled from the handoff, exact values

| Token | Light | Dark |
|---|---|---|
| `background` | `#F2F2F3` | `#121A22` |
| `surface` (card fill) | `#FFFFFF` | `#1A232C` |
| `ink` (primary text) | `#1D1F20` | `#EEF3F8` |
| `inkSecondary` | `#6B6E70` | `#9AA4AE` |
| `accent` | `#416180` | `#B5D9FD` |
| `accentMuted` | `#5980A6` | `#94BCE3` |
| `accentLight` (chart fill) | `#94BCE3` | `#5980A6` |
| `hairline` | `#D0D0D1` | `#424A51` |

Define each as a **colour set in the asset catalog with a light and a dark variant**, exposed
through `Palette`. That keeps automatic light/dark behaviour — the app must still respond to the
system appearance — while matching the brand exactly. Do not hard-code hex in a view.

## Typography
- Section headings ("August Spending", "Upcoming"): bold, ~22pt, tight tracking.
- Hero amount: bold ~44pt, `.rounded` off — the design uses a condensed grotesque; use the system
  font with `.bold` weight and slight negative tracking.
- Small caps labels ("AVAILABLE THIS MONTH", "INCOME", "CASH FLOW", "QUICK ADD", "12 DAYS
  REMAINING"): ~11–12pt, semibold, **uppercase, +0.08em tracking**, `inkSecondary` or `accent`.
- Every size must scale with Dynamic Type. Use relative text styles, not fixed points, wherever
  a `Font.TextStyle` can carry the design.

## `TickCard`
The signature container: a card with a hairline border and **four small crosshair tick marks that
straddle the corners** (visible in every screen of the handoff). Build it as a reusable
`ViewModifier`/container taking any content. Ticks are decorative — mark them
`.accessibilityHidden(true)`.

## Home layout — top to bottom, exactly as drawn

1. Greeting `Good morning, {name}` (bold ~28pt) with the tagline `KNOW WHERE YOUR MONEY GOES`
   in small caps beneath. Empty name → just `Good morning` (see spec 07 addendum).
2. `MonthNavigationBar`, restyled: square bordered chevron buttons left and right, centred
   `AUGUST 2026` in small caps. Same `AppState` binding — do not add month logic.
3. **`AvailableThisMonthCard`** (TickCard): label `AVAILABLE THIS MONTH`, hero amount from
   `projection.currentAvailableBalance`, then a three-column strip divided by hairlines:
   `INCOME +{totalExpectedIncome}` · `EXPENSES -{expensesPaid}` · `SAVINGS +{savingsCompleted}`.
   Income and savings values in `accent`; expenses in `ink`.
4. **`CashFlowBar`**: `CASH FLOW` label, then a horizontal stacked bar in three segments —
   expenses (`accent`), savings (`accentLight`), and the remainder drawn as a **diagonally hatched
   pattern** with a hairline outline. Legend beneath with a swatch and value per segment.
   Label the third segment **"Estimated savings"**, not "Remaining" — it is the same number as
   the card below it, and "Remaining" collides with Plan's "Projected remaining".
   The bar needs an `.accessibilityElement` summarising all three values.
5. **`EstimatedSavingsCard`** (TickCard): label `ESTIMATED SAVINGS`, amount from
   `projection.projectedEndOfMonthBalance`, supporting line "Based on your current income,
   recurring bills, and planned spending.", and a **ring/donut progress indicator** on the right
   showing progress toward the savings target. Footer row: `GOAL` … `{projected} / {savingsTarget}`.
   **Tapping this card opens the existing `ProjectionDetailView`** — it is the projection number,
   so the breakdown must stay reachable from Home until Plan ships its own entry point.
6. **`MonthSpendingCard`** (TickCard): heading `{Month} Spending` with
   `{daysRemaining} DAYS REMAINING` on the trailing side. Three columns —
   `SPENT {actualVariableSpending}` · `BUDGET {actual + remaining}` · `REMAINING
   {remainingVariableSpending}` (remaining in `accent`). Then a slim progress bar of spent
   against budget, then a row with a small dollar glyph: `Safe to spend: {dailySafeToSpend}/day`.
   If `daysRemaining == 0`, show "The month is complete" in place of the per-day figure.
7. **`UpcomingBillsSection`**, restyled: heading `Upcoming` with a `View All` link. Each row is a
   bordered **monogram square** (first two letters of the bill name, uppercase, `accent`), the
   name, the due date beneath, the amount on the right, and a small-caps status label under the
   amount: `AUTO PAY` when the bill is autopay, `ESTIMATED` when its amount type is estimated,
   otherwise `UPCOMING`. Keep the existing "Mark as paid" swipe action and the
   `repository.markBillPaid` → `projectionStore.refresh()` flow.
8. **`QuickAddRow`**: `QUICK ADD` label over four equal bordered buttons —
   `INCOME` (`arrow.up`), `EXPENSE` (`arrow.down`), `BILL` (`doc.text`), `TRANSFER`
   (`arrow.left.arrow.right`). Each presents the existing `AddTransactionView` with the
   corresponding type preselected. `BILL` opens it in bill mode if that already exists; if not,
   preselect `.expense` and leave a `// TODO(spec-06)` for the bill path.

## Navigation
`RootView` tab bar: `HOME` · `ACTIVITY` · `PLAN` · `INSIGHTS` · `SETTINGS`, labels in small caps,
outline SF Symbols (`house`, `arrow.left.arrow.right`, `list.clipboard`, `chart.line.uptrend.xyaxis`,
`slider.horizontal.3`), active tab tinted `accent`. **Rename the Transactions tab to "Activity"**
— the tab's content view keeps its existing type name; only the label changes.

## Constraints
- Views render state and dispatch intent. **No arithmetic in any `body`.** Every figure listed
  above already exists on `MonthlyProjection`; read it. If you believe a value is missing, stop
  and say so rather than computing it in the view.
- The empty first-run state from spec 03b must survive: when `projection.completeness` has no
  income, bills, budget, savings goal or starting balance, the hero card shows the
  "No plan for {month} yet" state with **no amount and no status**, and the cards below it are
  hidden rather than showing zeros.
- Light and dark must both be correct. No hard-coded hex outside the asset catalog.
- Dynamic Type through the largest accessibility sizes without truncation or overlap.
- Money values keep spoken accessibility labels; the ring, bar and hatched segment each need a
  text alternative.

## Done when
- [ ] builds for the iPhone 17 simulator with no new warnings
- [ ] all 86 existing tests still pass
- [ ] `grep -rnE "Color\(red:|#colorLiteral|Color\(hex|\.init\(hex" FlowPlan/` finds nothing
- [ ] `grep -rn "ProjectionHeroCard\|SafeToSpendCard" FlowPlan/` finds nothing
- [ ] previews cover light, dark, the empty first-run state, and the largest Dynamic Type size
