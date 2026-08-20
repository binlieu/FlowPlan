# Codex task spec — 18 — Writes save but the UI never re-renders

## The defect, reported from a device on a clean install
Adding a debt, deactivating one, and deleting one all appear to do nothing. **Force-quitting and
reopening shows the change was saved all along.** The writes are correct; the UI is stale.

## Root cause
`PlanView.body` fetches by calling the repository directly:

```swift
sources: repository.incomeSources(),
bills:   repository.bills(),
debts:   repository.debts(),
plans:   repository.savingsPlans(),
```

These are plain function calls. SwiftUI has no dependency on them, so the view re-renders only
when some *other* tracked value changes. After a write, `finish()` calls
`projectionStore.refresh()` — but when the write does not alter the projection, nothing is
invalidated and the list keeps showing stale data. Cases that change nothing in the projection:

- a debt marked `isPaidThroughBills` (Rule 19: contributes zero by design)
- deactivating or deleting such a debt
- editing a name, category or due day

This is why it looks intermittent: a *counted separately* debt changes the projection and appears
immediately, while an *in monthly bills* debt never does.

Note the inconsistency already in the codebase: `SavingsGoalSection` and `EditBudgetView` use
`@Query` and update live. The income, bills and debt sections do not.

## Fix — one change token, bumped where writes already funnel
Spec 17 routed every mutating repository method through a single `write` helper. Bump a change
token there, so no future write can forget to do it.

- Add an `@Observable` token the views can read — e.g. `private(set) var dataVersion: Int` on
  `ProjectionStore`, incremented by the repository's successful `write` (via a callback or a
  shared observable the repository holds). **Increment only on success**, after `context.save()`
  returns, never on a rolled-back failure.
- `PlanView` (and any other view fetching through the repository inside `body`) reads
  `dataVersion` so a bump invalidates it and the fetches re-run.
- Do **not** move SwiftData entities into views to fix this. Repositories keep returning domain
  value types; the architecture boundary stays as it is.

Audit every view that calls a repository fetch inside `body` — Plan, Home's expected income and
bills sections, Activity, Insights — and make each depend on the token. Anything already using
`@Query` is fine and needs no change.

## Tests
Unit tests cannot catch a missing SwiftUI dependency, so test the token contract instead:

- `dataVersion` increases after each successful add, update, delete and settle, across every
  entity type — parametrise so a new repository method that forgets the bump fails a test
- `dataVersion` does **not** change when a write fails and rolls back
- adding a debt marked `isPaidThroughBills` leaves `projectedEndOfMonthBalance` identical **and
  still bumps `dataVersion`** — this exact combination is the reported bug
- deactivating a debt bumps the token

Add a `#Preview` or a brief note in `PlanView` recording why the token dependency exists, so it is
not "cleaned up" later as an unused read.

## Done when
- [ ] adding, editing, deactivating and deleting a debt update the Plan list immediately, with no
      relaunch, including for a debt marked `isPaidThroughBills`
- [ ] `cd Packages/FlowPlanDomain && swift test` — 102 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] no view calls a repository fetch inside `body` without depending on the token
