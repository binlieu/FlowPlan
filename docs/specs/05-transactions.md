# Codex task spec — 05 — Transactions list, entry, editing and filters

## Goal
Fast one-handed transaction entry and a clean month-scoped list, with every write flowing back
into the projection immediately.

## Scope — touch ONLY these
- `FlowPlan/Features/Transactions/TransactionsView.swift` (create)
- `FlowPlan/Features/Transactions/TransactionRow.swift` (create)
- `FlowPlan/Features/Transactions/AddTransactionView.swift` (create)
- `FlowPlan/Features/Transactions/TransactionFilter.swift` (create)
- `FlowPlan/Features/Transactions/TransactionsViewModel.swift` (create)
- `FlowPlan/App/RootView.swift` (edit: wire the Transactions tab to `TransactionsView`)
- `FlowPlan/Features/Home/HomeView.swift` (edit: the `+` toolbar button and the "See all" link
  now present `AddTransactionView` / route to `TransactionsView`)
- `FlowPlanTests/TransactionsViewModelTests.swift` (create)

Do NOT modify `Packages/FlowPlanDomain/**`, `FlowPlan/Data/**`, `AppState`, `ProjectionStore`,
`ProjectionHeroCard`, the Xcode project, or `docs/`.

## What to do

### `TransactionsView`
- `MonthNavigationBar` at the top — the list always shows `appState.selectedMonth`.
- Transactions **grouped by day**, newest first, with a section header of "Today" /
  "Yesterday" / a formatted date, and the day's net total on the trailing side.
- `.searchable` over description and category.
- A toolbar `Menu` filter: transaction type (all/income/expense/savings/transfer) and category
  (multi-select). Filter state lives in `TransactionFilter` (a `Hashable` value type) held by the
  view model. Show an active-filter chip row with a "Clear" affordance when a filter is on.
- `.swipeActions`: trailing Delete (destructive, with confirmation) and Edit; leading Duplicate.
  Duplicate copies the transaction to today's date and opens the edit sheet pre-filled.
- Tapping a row opens `AddTransactionView` in edit mode.
- Empty state (`EmptyStateView`): "No transactions yet." / "Add your first income or expense to
  start tracking your month." When a filter or search is active and matches nothing, show a
  different, accurate message — "No transactions match this filter."
- Every write calls the repository and then `projectionStore.refresh()`.

### `AddTransactionView`
Native sheet, optimised for **fast one-handed entry**:
- Segmented `Picker` at the top: Income | Expense (Savings and Transfer available under a
  "More" menu so the common path stays two taps).
- A large amount field, focused on appear, `.decimalPad`, formatted live. Parse to `Decimal`
  through `Decimal(string:)`/`FormatStyle` — **never** via `Double`.
- Fields: category (menu of existing categories plus "New category…"), description, date
  (defaults to today, clamped into the selected month when the sheet is opened from a past
  month), account, a recurring toggle that creates a `RecurringBill`/`IncomeSource` instead of a
  one-off when enabled, and an optional note.
- Primary action "Save Transaction" pinned above the keyboard, disabled while the amount is zero
  or the category is empty. Validation messages are inline and factual.
- Edit mode reuses the same view with a pre-filled model and a "Save Changes" title.
- On save: repository write, `projectionStore.refresh()`, dismiss, and a light haptic when
  `appState.isHapticsEnabled`.

### `TransactionsViewModel`
`@Observable @MainActor`. Owns the filter, the search text, and the derived grouped sections.
Grouping and filtering happen here, not in a `body`. It reads from `FinanceRepository`; it never
touches SwiftData directly and never calls the engine.

### Tests
- filtering by type and by category returns the expected subset
- search matches description and category, case-insensitively
- grouping produces one section per day, ordered newest first, with correct day totals
- deleting a transaction moves `projection.projectedEndOfMonthBalance` by the expected amount
- adding a 600 unbudgeted expense moves the projection by exactly −600 (the brief's acceptance
  test, driven through the view model rather than the repository)

## Done when
- [ ] build succeeds, all tests pass, zero new warnings
- [ ] `grep -rn "Double(" FlowPlan/Features/Transactions/` finds nothing in a money path
- [ ] adding, editing and deleting all update the Home projection without a manual refresh
