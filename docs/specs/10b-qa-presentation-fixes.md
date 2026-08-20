# Codex task spec — 10b — QA presentation, architecture and accessibility fixes

Second QA pass. Correctness defects were fixed in 10a. See `docs/QA_REPORT.md` for full
reproduction steps.

## Scope — touch ONLY these
- `FlowPlan/Features/Home/HomeView.swift`
- `FlowPlan/Features/Home/EstimatedSavingsCard.swift`
- `FlowPlan/Features/Home/AvailableThisMonthCard.swift`
- `FlowPlan/Features/Home/CashFlowBar.swift`
- `FlowPlan/Features/Insights/InsightsView.swift`
- `FlowPlan/Features/Insights/SmartInsightsSection.swift`
- `FlowPlan/Features/Settings/SettingsView.swift`
- `FlowPlan/Features/Plan/PlanView.swift`
- `FlowPlan/Features/Plan/SavingsGoalSection.swift`
- `FlowPlan/App/AppLockView.swift`
- `FlowPlan/App/ProjectionStore.swift`
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Models/Insight.swift`
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/InsightsEngine.swift`
- `Packages/FlowPlanDomain/Tests/FlowPlanDomainTests/InsightsEngineTests.swift`
- `docs/PROJECT_STATUS.md`
- `FlowPlanTests/` — tests

## 1. QA 2.3 — a negative projection is labelled "estimated savings" (highest priority here)
`EstimatedSavingsCard` shows `projectedEndOfMonthBalance` under the label `ESTIMATED SAVINGS`,
with `{projected} / {savingsTarget}` as goal progress. With a projected shortfall it reads
`ESTIMATED SAVINGS -$420` and `-$420 / $2,000`, and VoiceOver says "Estimated savings, negative
420". Projected leftover cash is not savings, and a shortfall is not negative savings.

- When `projectedEndOfMonthBalance >= 0`, keep the card as designed.
- When it is negative, switch the label and copy to a factual shortfall: `PROJECTED SHORTFALL`,
  the amount, and "You're projected to be $420 short this month." Hide the goal-progress row and
  the ring rather than drawing negative progress.
- The goal row must never claim progress above 100%: cap the ring fill and render the figure as
  `{min(projected, target)} of {target}` with a separate "goal met" state when it is exceeded.
- Apply the same correction to the cash-flow legend's third segment.

## 2. QA 2.4 + 2.1 — the domain formats currency, and Insights bypasses ProjectionStore
`InsightsEngine` builds display strings with a hardcoded `USD`/`en_US`, so insight copy shows
dollars while the rest of the screen shows the user's currency. A pure domain type must not
format money at all.

- Change `Insight` to carry **structured values**, not a finished sentence: a `kind`, the
  `Decimal` amounts and any percentage/category it needs. Move sentence construction and money
  formatting into `SmartInsightsSection`, using `MoneyFormatter` and `AppState.currencyCode`.
- `InsightsView` currently calls the engine itself and performs ~13 repository fetches per
  render. Route insights through `ProjectionStore` so the engine is called **once** per change,
  consistent with the rest of the app, and fetch outside `body`.

Keep the wording factual and non-judgemental. Update `InsightsEngineTests` to assert on
structured values instead of on English strings.

## 3. QA 3.4 — the greeting says "Good morning" at every hour
`HomeView.greeting` is hardcoded. The pre-redesign Home had time-of-day logic and the rewrite
dropped it. Restore morning/afternoon/evening from the current hour via an injectable clock, and
keep the empty-name behaviour from spec 07's addendum ("Good morning" with no trailing comma).
Add a test covering all three periods and the empty-name case.

## 4. QA 2.10 — an explicit zero starting balance is reported as missing
`hasStartingBalance` is `startingBalance != .zero`, so a user who genuinely starts the month at
zero is told their projection is incomplete forever. Track "has the user set this value" in the
app layer (the presence of a `MonthSettingsEntity` row) rather than inferring it from the amount,
and feed that into the completeness display. Do not change the engine's arithmetic.

## 5. QA 1.9 follow-through — the stale-data banner
10a made read failures explicit in `ProjectionStore`. Surface it: when the store is in an error
state, Home shows a factual banner — "Your data couldn't be loaded. The figures below may be out
of date." — above the hero card. Never show a figure that is known to be stale without saying so.

## 6. Accessibility — QA 2.6, 2.7, 3.1, 3.2
- The Home hero card must be **one** VoiceOver element whose label states the amount and the
  interpretation, not a pile of separate labels.
- `AppLockView` must set `.accessibilityHidden(true)` on the content behind it and trap focus, so
  financial figures are not readable via VoiceOver while the app is locked.
- Plan section-header actions ("Add", "Edit") need a minimum 44×44 hit area.
- Transaction descriptions and categories must not be forced to one line at accessibility text
  sizes; allow wrapping.

## 7. QA 3.3 + 2.9 — smaller fixes
- Face ID appears twice in Settings (Preferences and Security). Keep one, in Security.
- A deactivated savings goal is stranded with no route to reactivate or delete. Show inactive
  goals in a collapsed "Inactive" group with both actions.

## 8. QA 3.5 — `PROJECT_STATUS.md` is materially stale
Rewrite it to reflect reality: specs 01–10 complete, the test counts, the build status, the
deferred items (Debt, Accounts, iCloud, widgets), and the known issues that remain open from the
QA report.

## Deferred deliberately — record in `docs/DECISIONS.md` as D-016, do not fix
- QA 1.5 (no rollback on failed save), 1.6 (non-atomic budget override) — need a repository-wide
  transaction strategy, not point fixes.
- QA 1.8 (Decimal→Double for chart geometry) — the layout conversions are legitimate; only the
  `Int(value.rounded())` slider path can trap. Clamp that one path and leave the rest.
- QA 2.5, 2.8 and the remaining minors.

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` passes; purity greps still clean
- [ ] app builds for the iPhone 17 simulator, no new warnings; all app tests pass
- [ ] a negative projection never renders as "savings" anywhere
- [ ] `grep -rn "USD\|en_US" Packages/FlowPlanDomain/Sources/` finds nothing

---

## SCOPE AUTHORISATION (revised)

`FlowPlan/App/RootView.swift` and `FlowPlan/Features/Transactions/TransactionRow.swift` are
authorised, along with `docs/DECISIONS.md`.

More generally, the allow-list above was the wrong shape for a fix pass — it was written from a
guess about which files hold each defect. **Replace it with a deny-list:** you may touch anything
under `FlowPlan/`, `FlowPlanTests/`, the three named `FlowPlanDomain` files, and the two docs.

Do NOT touch:
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/MonthlyProjectionEngine.swift`
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Models/ProjectionModels.swift`
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Support/**`
- `FlowPlan/Data/**`
- `FlowPlan.xcodeproj`
- `docs/QA_REPORT.md`

If a fix still needs something on the deny-list, stop and say so — that is the right call and you
made it correctly twice.
