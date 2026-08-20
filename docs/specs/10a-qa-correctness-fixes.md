# Codex task spec — 10a — QA correctness fixes (wrong numbers)

Fixes the QA findings that make FlowPlan display a **wrong financial number**. Presentation and
architecture findings are spec 10b. Findings not listed here are deferred deliberately.

Read `docs/QA_REPORT.md` for full reproduction steps. Each item below is confirmed.

## Scope — touch ONLY these
- `FlowPlan/Features/Transactions/AddTransactionView.swift`
- `FlowPlan/Features/Transactions/TransactionsViewModel.swift`
- `FlowPlan/Data/Repositories/FinanceRepository.swift`
- `FlowPlan/Features/Plan/PlanView.swift`
- `FlowPlan/Features/Plan/EditIncomeView.swift` (the shared `PlanAmountParser` lives here)
- `FlowPlan/Features/Plan/StartingBalanceSection.swift` (create)
- `FlowPlan/App/ProjectionStore.swift`
- `FlowPlanTests/` — add tests

Do NOT modify `Packages/FlowPlanDomain/**`. The engine is correct; these are app-layer defects.

## 1. QA 1.1 + 1.2 — a paycheck entered by hand is counted twice (CRITICAL)
`markIncomeReceived` has **zero call sites**. Add Transaction always calls `addTransaction`
without `settlesIncomeID`, so the engine treats an entered paycheck as *extra* income while the
planned occurrence stays outstanding. Enter $1,000 against a $1,000 planned salary and the
projection overstates by $1,000.

This is the exact double-count the architecture exists to prevent, leaking in at the UI layer
because the settle path was never wired.

- When the user adds an **income** transaction and an active `PlannedIncome` has an unsettled
  occurrence in that month, offer to link it: a picker listing unsettled occurrences plus a
  "Not one of these — extra income" option. Default to the nearest unsettled occurrence by date.
- Linking routes through `markIncomeReceived`, never `addTransaction`.
- Mirror this for expenses that match an unsettled bill occurrence, routing through
  `markBillPaid`, so the two settlement paths are symmetric.
- `markIncomeReceived` must reject a second settlement of the same occurrence with
  `settlementAlreadyRecorded`, exactly as `markBillPaid` already does (see the guard at
  `FinanceRepository.swift:339-351`).

**Tests:** entering a paycheck linked to a planned occurrence leaves `totalExpectedIncome`
unchanged and `remainingExpectedIncome` reduced; choosing "extra income" raises the total and
leaves remaining untouched; a duplicate settlement throws.

## 2. QA 1.3 — the user cannot enter a starting balance (CRITICAL)
`setStartingBalance` has **zero call sites** outside the repository, previews and import. On a
real install the starting balance is always `.zero`, so `currentAvailableBalance` and every
figure derived from it are understated by the user's actual opening cash. DECISIONS.md D-008
makes this value the foundation of the headline number.

Add a `StartingBalanceSection` at the **top of Plan**: a labelled amount field bound to
`repository.startingBalance(for:)` / `setStartingBalance(_:for:)` for the selected month, with a
one-line explainer ("What you had available at the start of the month."). Write on commit, then
`projectionStore.refresh()`.

Also surface it in the Home first-run empty state as part of what is missing.

**Tests:** setting a starting balance of 2,400 raises `currentAvailableBalance` and
`projectedEndOfMonthBalance` by exactly 2,400; it persists across a store reload; it is
per-month.

## 3. QA 1.4 — comma decimal locales misparse by 100× (CRITICAL)
`PlanAmountParser.decimal(from:)` strips **every** comma then parses as `en_US_POSIX`. In a
comma-decimal locale, `12,50` becomes `1250` — a 100× error silently written to the store.

Parse with the **user's locale** first (`Decimal(string:locale: .current)`), falling back to
POSIX only when the string contains no locale decimal separator. Strip grouping separators for
the active locale, never all commas unconditionally. `PlanAmountParser.text(_:)` must round-trip
its own output in every locale it accepts.

**Tests:** parametrised over `en_US`, `de_DE` and `fr_FR` — `12,50` / `12.50` / `1,234.56` /
`1.234,56` each parse to the intended `Decimal`, and `text(parse(x)) == x` round-trips.

## 4. QA 1.7 — category identity is case-sensitive in the engine, case-insensitive in the UI
The engine keys budgets and spending by exact `String`, so `Groceries` and `groceries` are two
categories and a budget silently fails to match its spending — a wrong remaining-budget figure.
The UI treats them as the same when listing categories.

Normalise category identity **once**, in the repository, on the way in: trim whitespace and
case-fold to a canonical stored form, preserving the user's chosen display casing in a separate
field if needed. Do not normalise inside the engine — it must keep taking values as given.

**Tests:** a budget on `Groceries` matches spending entered as `groceries`; the category list
shows one entry, not two.

## 5. QA 1.9 — failed reads become valid-looking zeros
Every repository fetch failure is logged and returned as `[]`, and a failed starting-balance
fetch returns `.zero`. `ProjectionStore` publishes the result as though it were real, so a broken
store renders a confident `$0` projection with no error shown — the worst failure mode for a
product whose value is a trusted number.

Make fetch failures **explicit**: have the repository signal failure (throwing or a `Result`),
and have `ProjectionStore.refresh()` retain the last known projection and expose an
`isStale`/error state instead of publishing zeros. Home must show a factual banner
("Your data couldn't be loaded. The figures below may be out of date.") rather than a wrong number.

**Tests:** with a failing fetch, `refresh()` does not overwrite a previously good projection and
sets the error state.

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` still passes (87 tests, unchanged)
- [ ] app builds for the iPhone 17 simulator with no new warnings
- [ ] all existing app tests pass, plus the new ones
- [ ] `grep -rn "markIncomeReceived" FlowPlan/Features/` shows a real call site
- [ ] `grep -rn "setStartingBalance" FlowPlan/Features/` shows a real call site
