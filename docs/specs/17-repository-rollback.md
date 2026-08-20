# Codex task spec — 17 — A failed write poisons every later write

## The defect, reported from a device
Deleting an existing debt showed **"Unable to save debt. The debt could not be saved."**

Root cause: `FinanceRepository` contains **zero calls to `context.rollback()`**. Every write
mutates managed objects and then calls `context.save()`, which commits the whole context. When a
write fails, the invalid objects stay in the context, so **every subsequent save fails too** —
including unrelated operations like deleting a different record. The context stays poisoned until
the app restarts.

This is QA report finding **1.5**, deferred as D-016. It is no longer deferrable: it is
reproducible in normal use and it presents as unrelated operations mysteriously failing.

The clean-store repository tests pass because they never fail a write first, which is exactly why
this survived the QA pass.

## Scope
- `FlowPlan/Data/Repositories/FinanceRepository.swift`
- `FlowPlan/Features/Plan/EditDebtView.swift` and the other Plan/Transaction editors that present
  write errors
- `FlowPlanTests/`
- `docs/DECISIONS.md` — update D-016: 1.5 is fixed, 1.6 remains

Do NOT touch `Packages/FlowPlanDomain/**`. All 102 domain tests must pass unchanged.

## 1. Every write rolls back on failure
Give the repository one private helper that all mutating operations route through:

```swift
/// Runs a mutation and commits it. On any failure the context is rolled back before the error
/// is rethrown, so a failed write cannot leave mutated objects behind. Without this, one
/// failure makes every later save() fail, because save() commits the whole context.
private func write<T>(_ body: () throws -> T) throws -> T {
    do {
        let result = try body()
        try context.save()
        return result
    } catch {
        context.rollback()
        throw error
    }
}
```

Route **every** mutating repository method through it — transactions, income, bills, budgets,
savings, month settings, accounts, debts, and all the settle methods. Remove the now-duplicated
`try context.save()` calls from each body. Any method that saves and is not routed through the
helper is a bug.

## 2. Do not mutate an object you are about to delete
`deleteDebt` sets `debt.updatedAt = timestamp` immediately before `context.delete(debt)`. Dirtying
a doomed object is pointless and can itself fail the save. Remove that line, and check the other
delete methods for the same pattern.

## 3. Error messages must name the operation that failed
`EditDebtView.deleteDebt()` and `deactivate()` both call `showSaveError()`, so a failed **delete**
reports "could not be saved". Give each operation its own message — "Couldn't delete this debt",
"Couldn't deactivate this debt" — and audit the other editors for the same copy-paste.

## 4. Stop discarding the underlying error
`showSaveError()` throws away the caught error and shows a fixed string, which is why this defect
could not be diagnosed from the user's report. Include the underlying failure in the presented
detail — a secondary line is enough — and log it via the existing `os.Logger` **without any
financial values**, per the privacy rule.

## Tests — the regression guard matters more than the fix
- **a write that fails, followed by a valid write, succeeds.** Force the first to fail (a
  duplicate settlement, or a validation the repository already rejects), then perform an unrelated
  valid write and assert it succeeds. This is the exact user-reported scenario and must fail
  against the current code.
- after a failed write, the failed change is **not observable** from the repository
- deleting a debt that has linked transactions succeeds and preserves those transactions
- deleting a debt whose monthly payment exceeds its balance succeeds (the reported record had a
  $728 balance and a $672 payment)
- a failed delete reports a delete message, not a save message

## Done when
- [ ] `grep -c "context.save()" FlowPlan/Data/Repositories/FinanceRepository.swift` shows exactly 1
- [ ] `grep -c "rollback" FlowPlan/Data/Repositories/FinanceRepository.swift` is at least 1
- [ ] `cd Packages/FlowPlanDomain && swift test` — 102 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
