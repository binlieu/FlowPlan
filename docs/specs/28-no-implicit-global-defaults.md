# Codex task spec — 28 — The repository silently falls back to UserDefaults.standard

## The defect
`startingBalancePersistsPerMonthAndMovesBalancesExactly` fails in a full test run and passes in
isolation.

`FinanceRepository.init(..., userDefaults: UserDefaults = .standard)` defaults to the **global**
defaults. Rollover consults `carryBalanceForward` through it, so a repository constructed without
an explicit suite reads process-wide state. Another test that sets `carryBalanceForward = false`
leaks into every later test that shares it — an order-dependent failure that no test can catch in
isolation.

This is the third defect in this project caused by implicit shared state, after the unretained
`ModelContainer` and the poisoned `ModelContext`. Remove the trap rather than patching the test.

## Scope
- `FlowPlan/Data/Repositories/FinanceRepository.swift`
- every construction site of `FinanceRepository`
- `FlowPlanTests/`

Do NOT touch `Packages/FlowPlanDomain/**`. All 106 domain tests must pass unchanged.

## Fix
1. **Remove the `= .standard` default** from `FinanceRepository.init`. `userDefaults` becomes a
   required parameter, so no construction can accidentally read global state. The compiler then
   finds every site.
2. **App code** passes the same defaults instance `AppState` uses — one source of truth for
   preferences per running app.
3. **Every test** passes an isolated, uniquely-named suite, following the pattern already used in
   `BalanceRolloverTests.carryBalanceForwardPreferenceDefaultsToTrueAndPersists`. Audit all test
   environments; any that construct a repository without an explicit suite must be fixed, not just
   the failing one.
4. Apply the same audit to any other type defaulting to `.standard` — if `AppState` or another
   type has the same fallback, make it explicit too, and list what you changed.

## Tests
- the previously failing test passes in a full run, repeatedly
- **an order-dependence guard**: one test sets `carryBalanceForward = false` in its own suite, and
  a second test using a different suite still observes the default `true`. This must fail against
  the current code.
- rollover still works end to end with an explicit suite

## Done when
- [ ] `grep -n "UserDefaults = .standard" FlowPlan/Data/Repositories/FinanceRepository.swift` finds nothing
- [ ] the full app suite passes on three consecutive runs
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
