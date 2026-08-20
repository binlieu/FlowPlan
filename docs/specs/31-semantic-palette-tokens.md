# Codex task spec — 31 — System colours still leak into Activity and Home

## The defect
After spec 30, Activity still looks off-template:

- `TransactionRow.iconColor` returns raw `.green`, `.orange`, `.blue`, `.purple` — four system
  colours, none from the palette. Expense rows show **orange** circles.
- Transaction amounts render in **system red** for every expense. The design shows expenses in
  ink — Home's `EXPENSES -$4,069.99` is not red — so colouring every ordinary expense red is both
  off-template and alarmist.
- `foregroundStyle(.red)` and `.orange` remain in `AvailableThisMonthCard`, `ExpectedIncomeSection`,
  `OccurrenceStatusLabel`, `UpcomingBillsSection`, `AddTransactionView`.
- The Activity screen renders its title **below** the toolbar and search field, so the header
  reads out of order compared with Plan and Settings.

Previous greps missed these because they checked `.tint(` and hard-coded hex; a function returning
a system colour passes both.

## Fix

### 1. Semantic palette tokens
The palette has brand and fill colours but no semantic ones, so system colours got used instead.
Add colour sets and expose on `Palette`:

| Token | Light | Dark | Meaning |
|---|---|---|---|
| `positive` | `#2F6B4F` | `#7FBF9B` | income, money in |
| `negative` | `#B3261E` | `#E39A95` | a genuine shortfall or error — **not** ordinary spending |
| `warning` | `#8A5A00` | `#E0B050` | overdue, needs attention |
| `info` | `#416180` | `#B5D9FD` | savings, transfers, neutral emphasis |

### 2. Apply them
- `TransactionRow.iconColor`: income → `positive`, expense → `Palette.inkSecondary`, savings →
  `info`, transfer → `info`. **Ordinary spending is not a warning state** and must not be orange
  or red.
- Transaction **amounts**: `Palette.ink` for expenses, `positive` for income. Reserve `negative`
  for a projected shortfall, which already has its own treatment on Home.
- Replace every remaining `foregroundStyle(.red)` / `.orange` with the matching semantic token.
  Validation errors and destructive confirmations use `negative`; overdue markers use `warning`.
- Keep `.red` **only** where iOS convention demands a destructive system control (a delete role
  button in a confirmation dialog). List anything you keep.

### 3. Activity header order
Put the large bold `Activity` title above the toolbar and search, matching Plan and Settings.
The month bar stays where it is.

## Scope
Anything under `FlowPlan/`. Do NOT touch `Packages/FlowPlanDomain/**` or any displayed value —
presentation only. All 106 domain and 135 app tests must pass unchanged.

## Constraints
- Never communicate state by colour alone — every `warning` and `negative` use keeps its symbol
  and text, per the accessibility rule already in force.
- Contrast at least 4.5:1 for each token against its background, in both appearances. State the
  computed ratios in your final message.

## Tests
Previews only, since colour is not unit-testable:
- a transaction row per type, light and dark
- Activity and Home in both appearances

## Done when
- [ ] `grep -rnE "foregroundStyle\(\.(red|orange|green|blue|purple)\)|return \.(red|orange|green|blue|purple)$" FlowPlan/` returns only deliberately-kept destructive controls
- [ ] no ordinary expense renders orange or red
- [ ] Activity's title sits above its toolbar and search
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
