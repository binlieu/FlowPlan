# Codex task spec — 03 — Shared design system + Home dashboard

## Goal
Build the reusable SwiftUI components and the Home screen, with **Projected End of Month** as
the unmistakable visual hero.

## Scope — touch ONLY these (create them)
- `FlowPlan/Shared/Components/MonthNavigationBar.swift`
- `FlowPlan/Shared/Components/AmountText.swift`
- `FlowPlan/Shared/Components/SectionCard.swift`
- `FlowPlan/Shared/Components/StatTile.swift`
- `FlowPlan/Shared/Components/EmptyStateView.swift`
- `FlowPlan/Shared/Components/ProjectionStatusBadge.swift`
- `FlowPlan/Features/Home/HomeView.swift`
- `FlowPlan/Features/Home/ProjectionHeroCard.swift`
- `FlowPlan/Features/Home/UpcomingBillsSection.swift`
- `FlowPlan/Features/Home/RecentTransactionsSection.swift`
- `FlowPlan/Features/Home/SafeToSpendCard.swift`
- `FlowPlan/App/RootView.swift` (replace the placeholder with the real `TabView`)

Do NOT modify `Packages/FlowPlanDomain/**`, `FlowPlan/Data/**`, `FlowPlan/App/AppState.swift`,
`FlowPlan/App/ProjectionStore.swift`, the Xcode project, or `docs/`.
Read those files to learn the API; do not change them.

## Ground rules
- Views **render state and dispatch intent**. Zero arithmetic in a `body`. Every number comes
  from `ProjectionStore.projection` (a `MonthlyProjection`) or from the repository. If a number
  you need is not on `MonthlyProjection`, derive it in a small `private` helper on the view model
  — never re-implement projection maths.
- Semantic colours only (`.primary`, `.secondary`, `Color.accentColor`, `.red`, `.green`,
  `Color(.systemGroupedBackground)`, materials). **No hard-coded hex.** Every screen must look
  right in light and dark mode.
- Dynamic Type must work: no fixed frame heights on text, no `.lineLimit(1)` on money values
  without `.minimumScaleFactor`.
- State is never communicated by colour alone — always pair colour with an SF Symbol and words.
- Native components: `NavigationStack`, `TabView`, `List`, `.sheet`, `.swipeActions`, SF Symbols.
- No third-party dependencies. No custom gradients beyond a single subtle one on the hero card.

## What to do

### `RootView.swift`
Native `TabView` with five tabs and SF Symbols:
Home `house.fill` · Transactions `list.bullet.rectangle` · Plan `calendar` ·
Insights `chart.line.uptrend.xyaxis` · Settings `gearshape`.
Each tab wraps its root in a `NavigationStack`. Tabs other than Home may show a temporary
`EmptyStateView` placeholder — later specs fill them in. Inject `AppState`, `FinanceRepository`
and `ProjectionStore` through `@Environment`.

### `MonthNavigationBar.swift`
Reusable month selector bound to `AppState`: `chevron.left`, the month title
("August 2026"), `chevron.right`. Forward chevron disabled when `appState.canGoForward` is false.
Tapping the title offers "Go to current month". Accessibility: the label reads the full month and
year; the chevrons are labelled "Previous month" / "Next month". This is the **only** month
control in the app — no screen implements its own.

### `AmountText.swift`
Renders a `Decimal` through `MoneyFormatter` with the currency from `AppState`.
Parameters: `amount`, `style` (`.hero`, `.primary`, `.secondary`), `signed: Bool`,
`emphasiseNegative: Bool`. `.hero` uses a large rounded-design font with
`.contentTransition(.numericText())` so the number animates when the projection changes.
Supplies a spoken accessibility label via `MoneyFormatter.accessibleString` — VoiceOver must
never read a bare glyph.

### `ProjectionHeroCard.swift`
The centrepiece. It communicates three things, in this order:

1. **Result** — the caption "PROJECTED MONTH END" and the projected balance in `.hero` style.
2. **Interpretation** — one factual sentence built from `projection.status`:
   - `.healthy` → "You're projected to finish August with $1,420 remaining."
   - `.tight` → "You're projected to finish August with only $180 remaining."
   - `.negative` → "You're projected to be $420 short this month."
   - `.aheadOfPlan` → "You're currently $620 ahead of your monthly plan."
   Factual, never judgemental. Never "you overspent", never an emoji.
3. **Direction** — `varianceVsPlan` as "+$220 vs your original plan" with an
   `arrow.up.right` / `arrow.down.right` / `equal` symbol.

Plus a `ProjectionStatusBadge` (symbol + word: Healthy / Tight / Short / Ahead of plan) so the
state is never carried by colour alone, and a `chevron.right` affordance — **tapping the card
navigates to the projection breakdown** (route to a `ProjectionDetailView` that a later spec
implements; for now push a placeholder `Text("Breakdown")` behind
`// TODO(spec-04): ProjectionDetailView`).

If `projection.completeness.isComplete` is false, show a compact inline note listing
`completeness.missing` — "Projection may be incomplete: no income planned for this month."
Never hide the fact that the inputs are thin.

Accessibility: the whole card is one element whose label states the projected amount and the
interpretation sentence, with `.isButton` and a hint of "Shows how this was calculated".

### `HomeView.swift`
Scrolling layout, in this order:

1. Greeting — "Good morning, Alex" / afternoon / evening from the current hour and
   `appState.userName`, then `MonthNavigationBar`.
2. `ProjectionHeroCard`.
3. A four-up `StatTile` grid: Income (`totalExpectedIncome`), Spent (`expensesPaid`),
   Bills Remaining (`remainingBills`), Savings (`savingsCompleted` of `savingsTarget`).
   Use a `LazyVGrid` with adaptive columns so it reflows on small phones and at large Dynamic
   Type sizes.
4. `SafeToSpendCard` — `dailySafeToSpend` as "$82 / day" with a secondary line
   "for the 15 days left in August". If `daysRemaining == 0`, show "The month is complete"
   instead of a per-day figure.
5. `UpcomingBillsSection` — the next unpaid bill occurrences this month from the repository,
   name, due date and amount, each with a "Mark as paid" swipe action calling
   `repository.markBillPaid(...)` then `projectionStore.refresh()`. Cap at five with a
   "See all" link to Plan.
6. `RecentTransactionsSection` — the five most recent transactions, with a "See all" link to
   Transactions.

`.refreshable` calls `projectionStore.refresh()`. Empty states use `EmptyStateView` with the
exact copy from the brief:
- no transactions → "No transactions yet." / "Add your first income or expense to start tracking your month."
- no income plan → "Add your expected income to improve your month-end projection."

A `+` toolbar button opens the add-transaction sheet — for now
`// TODO(spec-05): AddTransactionView`, presenting a placeholder sheet.

### `StatTile`, `SectionCard`, `EmptyStateView`, `ProjectionStatusBadge`
Small, generic, previewable. `SectionCard` is the standard grouped container (title row with an
optional trailing action, rounded background). `EmptyStateView` takes a symbol, title, message
and optional action; use `ContentUnavailableView` underneath where it fits.

## Previews
Every file gets a `#Preview` driven by an in-memory container with sample data, covering light
and dark. Include a preview of the hero card in all four `ProjectionStatus` states.

## Done when
- [ ] `xcodebuild -scheme FlowPlan -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeds
- [ ] existing tests still pass
- [ ] zero new warnings
- [ ] `grep -rn "Color(red:\|#colorLiteral\|Color(hex" FlowPlan/` finds nothing
- [ ] no arithmetic on money inside any `body`
