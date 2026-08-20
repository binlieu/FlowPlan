# Codex task spec — 30 — Activity and Settings do not follow the design system

## The defect
Home, Plan and Insights use the design system — `Palette` colours, `TickCard`, small-caps section
labels, condensed bold headings. Activity and Settings do not, so the app looks like two different
products.

Measured: `SettingsView` contains **zero** `Palette` references and renders a stock `Form` with
system colours. `TransactionsView` has only partial adoption. Both also use a centred inline
navigation title, where Plan uses a large left-aligned bold title with a small-caps subtitle.

## Approach — restyle, do not rebuild
Keep `Form` and `List`. They provide keyboard avoidance, picker presentation, swipe actions and
accessibility behaviour that a hand-rolled `ScrollView` would lose. Restyle them instead:

- `.scrollContentBackground(.hidden)` with `Palette.background` behind
- `.listRowBackground(Palette.surface)` on rows
- section headers using the existing small-caps typography in `Palette.inkSecondary`, matching
  `ACCOUNTS` / `PREFERENCES` styling already used elsewhere
- text in `Palette.ink` / `Palette.inkSecondary`, never `.primary` / `.secondary`
- separators and borders in `Palette.hairline`
- interactive tint `Palette.accent`; fills use the `accentFill` family from spec 23

Do **not** convert either screen to a custom container, and do not restyle individual controls
into non-native lookalikes.

## Screen titles
Give Activity and Settings the same header treatment as Plan: a large left-aligned bold title in
`Palette.ink`, with a small-caps subtitle where one is meaningful (Activity shows the month —
it already has a `MonthNavigationBar`, so avoid duplicating the month; use the title alone).
Replace the centred inline navigation titles.

## Scope
- `FlowPlan/Features/Settings/SettingsView.swift`
- `FlowPlan/Features/Settings/AccountsSettingsView.swift`
- `FlowPlan/Features/Settings/CategoriesSettingsView.swift`
- `FlowPlan/Features/Settings/DataSettingsView.swift`
- `FlowPlan/Features/Transactions/TransactionsView.swift`
- `FlowPlan/Features/Transactions/TransactionRow.swift`
- `FlowPlan/Features/Transactions/AddTransactionView.swift`
- `FlowPlan/Shared/DesignSystem/` — add shared modifiers if it avoids repeating the same
  restyling five times; a `designSystemForm()` / `designSystemList()` modifier is preferable to
  copy-paste, for the same reason `PlanTotalRow` was extracted

Do NOT touch `Packages/FlowPlanDomain/**`, the projection engine, or any displayed value. This is
presentation only — all 106 domain and 135 app tests must pass unchanged.

## Constraints
- Light and dark must both be correct; check every screen in both.
- Dynamic Type through the largest accessibility size without truncation or overlap.
- Do not regress the swipe actions, filters, search, or the add/edit sheets.
- No hard-coded hex: `grep -rnE "Color\(red:|#colorLiteral|Color\(hex" FlowPlan/` stays empty.
- Keep every system semantic colour that is genuinely correct — a destructive `.red` on an
  "Erase all data" confirmation should stay. List what you deliberately left alone.

## Tests
Styling is not unit-testable; add previews:
- Activity and Settings in light and dark
- each Settings subscreen (Accounts, Categories, Data) in both appearances
- Activity at the largest Dynamic Type size

## Done when
- [ ] `grep -c "Palette\." FlowPlan/Features/Settings/SettingsView.swift` is greater than zero
- [ ] no screen uses `.primary` / `.secondary` / `systemGroupedBackground` where a Palette token exists
- [ ] Activity and Settings use the same title treatment as Plan
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
