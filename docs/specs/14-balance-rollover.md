# Codex task spec — 14 — Carry leftover cash into the next month

## The gap
`startingBalance(for:)` returns the stored `MonthSettingsEntity` value or `.zero`. Nothing
carries forward, so a month the user has not explicitly filled in projects from zero — as if
their bank account emptied on the 1st. For a monthly planner over a real account that is simply
wrong, and it is the second time a silent zero has produced a misleading headline figure.

Extends D-008 rather than replacing it: the user may still set any month explicitly, and an
explicit value always wins.

## Scope
- `FlowPlan/Data/Repositories/FinanceRepository.swift`
- `FlowPlan/Features/Plan/StartingBalanceSection.swift`
- `FlowPlan/Features/Settings/SettingsView.swift`
- `FlowPlan/App/AppState.swift` (one preference)
- `FlowPlanTests/`
- `docs/DECISIONS.md` — add **D-017** recording this

Do NOT touch `Packages/FlowPlanDomain/**`. The engine keeps taking `startingBalance` as a plain
input and stays unaware that it can be derived — the rollover is an app-layer concern.

## What rolls over — read this carefully
September's opening balance = **August's actual closing cash**:

```
closing(month) = startingBalance(month)
               + incomeReceived(month)
               − expensesPaid(month)
               − savingsCompleted(month)
```

That is `MonthlyProjection.currentAvailableBalance` for the completed month.

**Do NOT roll over `projectedEndOfMonthBalance`.** That figure contains income not yet received
and obligations not yet paid. Carrying it forward would import a forecast as though it were cash
and quietly compound the error every month. Actuals only.

Money moved to savings is already subtracted from `currentAvailableBalance`, so it is correctly
excluded from what carries forward — savings are not spendable cash. Note that in a comment so
nobody "fixes" it later.

## Rules
1. If a month has an explicit `MonthSettingsEntity` row, **use it unchanged**. The user's own
   number always wins; never overwrite or silently correct it.
2. Otherwise, derive it from the previous month's closing cash.
3. Deriving the previous month may itself require deriving the one before it. Walk back to the
   most recent month with an explicit value, **cap the walk at 24 months**, and fall back to
   `.zero` if none is found. Memoise within a single resolution so a long chain is computed once.
4. A derived value is **never written to the store**. It is computed on read, so correcting an
   earlier month automatically corrects every later derived month.
5. Gate on a preference `carryBalanceForward`, default **true** — money carrying forward is the
   truthful default for a real account. Off means the old behaviour: explicit or zero.

## Presentation — the number must explain itself
In `StartingBalanceSection`, when the value is derived, show it as such:
`Rolled over from August · $1,234.56`, with the field still editable — typing a value creates the
explicit row and stops the derivation for that month.

Offer a way back: when a month has an explicit value, a small **Use rolled-over amount** action
deletes the row and returns to derivation. Never strand the user with a number they cannot undo.

Add the preference to Settings under Preferences: `Carry balance forward`, with a one-line
explainer — "Each month starts with what was left at the end of the previous one."

## Tests
- explicit value is returned unchanged and is unaffected by the previous month
- with no explicit value, the month opens with the previous month's closing cash
- a three-month chain with an explicit value only in the first resolves correctly through to the
  third, and editing the first updates the third
- savings recorded in the previous month reduce what carries forward
- **income expected but not received in the previous month does NOT carry forward** — this is
  the projection-vs-actual distinction and deserves its own named test
- the walk stops at 24 months and yields `.zero` when no explicit value exists anywhere
- with `carryBalanceForward` false, an unset month is `.zero` again
- resolving a long chain performs a bounded number of fetches, not one per month per call

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` unchanged (87 pass)
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] `grep -rn "projectedEndOfMonthBalance" FlowPlan/Data/` finds nothing — rollover uses actuals
- [ ] a derived starting balance is always labelled as rolled over, never shown bare
