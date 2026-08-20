# Codex task spec — 26 — Starting balance behaves wrongly when carry-forward is off

## The defect
With **Carry balance forward** off in Settings, `StartingBalanceSection` still shows the
**"Use rolled-over amount"** action whenever the month has an explicit value. There is no
rolled-over amount in that mode, so tapping it deletes the user's entry and leaves the month at
`$0` with nothing to fall back on — a destructive action offering something that does not exist.

The amount field itself is editable and saving works; the surrounding affordance and copy are the
problem.

## Scope
- `FlowPlan/Features/Plan/StartingBalanceSection.swift`
- `FlowPlanTests/`

Do NOT touch `Packages/FlowPlanDomain/**` or the repository's rollover resolution — that logic is
correct. All 106 domain tests must pass unchanged.

## Fix
1. **Hide "Use rolled-over amount" when `appState.carryBalanceForward` is false.** There is
   nothing to revert to. Show it only when carry-forward is on *and* the month has an explicit
   value.

2. **Say what mode the user is in.** When carry-forward is off, the explanation becomes:
   "What you had available at the start of the month. Each month is entered separately because
   Carry balance forward is off." Keep the existing copy when it is on.

3. **Prompt when unset.** With carry-forward off and no explicit value for the month, the field
   shows its `0.00` placeholder and the explanation adds "Enter this month's starting balance so
   your projection is accurate." — factual, no scolding. This is the case that silently projects
   from zero, which has already caused one reported defect.

4. **Offer a way to clear an entry**, since the revert action is gone in this mode: a
   **Clear** action when carry-forward is off and the month has an explicit value, removing the
   row and returning the field to its placeholder. Confirm it, because it changes a financial
   figure.

## Tests
- with carry-forward off, "Use rolled-over amount" is not offered for an explicit month
- with carry-forward on, it is still offered, and still reverts to the derived value
- with carry-forward off, entering a value persists it for that month and does not affect
  the next month
- clearing an explicit value with carry-forward off returns the month to unset, and the
  projection uses zero
- the completeness indicator still reports a starting balance that has never been set,
  distinct from one deliberately set to zero

## Done when
- [ ] no action offers a rolled-over amount when carry-forward is off
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
