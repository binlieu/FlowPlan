# Codex task spec — 22 — A debt "in monthly bills" with no matching bill vanishes silently

## The defect, reported from a device
A user added a debt (`Tundra`, $32,081, 3.99% APR, due 1st, auto-pay) and turned on
**Payment is in Monthly Bills**. Their Monthly Bills list was empty.

Result: `OUTSIDE MONTHLY BILLS $0`, the payment contributes nothing to the projection, it is
excluded from auto-record (correctly — `isPaidThroughBills` debts must never be settled twice),
and it never appears in Activity. **The payment is counted nowhere, and nothing says so.**

Every individual rule behaved as designed. The product still lost a $500/month obligation without
a word, which is precisely the failure this app exists to prevent.

## Fix — make the claim verifiable, and say so when it is not
`isPaidThroughBills` is an assertion by the user that a corresponding bill exists. The app must
detect when that assertion does not hold and surface it rather than silently dropping the money.

### 1. Detect the orphan
A debt is **orphaned** when `isActive && isPaidThroughBills` and no active `RecurringBill`
plausibly corresponds to it. Match generously — the user should not have to name things
identically:

- an exact or case-insensitive name match, **or**
- a bill whose amount equals the debt's `monthlyPayment` and whose due day matches `dueDay`

If neither holds, the debt is orphaned. Put this in the app layer, not the engine — the engine's
Rule 19 stays exactly as it is, and all 106 domain tests must pass unchanged.

### 2. Warn where the decision was made
- **`DebtSection` row:** an inline warning under an orphaned debt —
  "Marked as paid through Monthly Bills, but no matching bill was found. This payment isn't
  counted in your plan." with an `exclamationmark.triangle` and a **Count it separately** action
  that clears the flag in one tap.
- **`EditDebtView`:** when the toggle is switched on and no matching bill exists, show the same
  explanation beneath the toggle immediately, so the consequence is visible at the moment of
  choosing rather than discovered later.
- Home's first-run / completeness messaging should mention it too if a debt is orphaned, since it
  materially affects the projection.

Copy stays factual and non-judgemental — state what is not counted and offer the fix.

### 3. Do not auto-correct
Do **not** silently clear the flag or start counting the payment. The user may be about to add the
bill. Warn, offer the one-tap fix, and leave the choice with them.

## Tests
- a debt with `isPaidThroughBills` and no bills is reported orphaned
- a debt matching a bill by name (including different casing) is **not** orphaned
- a debt matching a bill by amount and due day but not name is **not** orphaned
- an inactive debt, or one with the flag off, is never orphaned
- clearing the flag via the row action makes the payment appear in `remainingDebtPayments` and
  lowers `projectedEndOfMonthBalance` by the payment
- the orphan check changes no projection figure by itself — assert a full `MonthlyProjection`
  equality before and after the warning appears

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] a debt whose payment is counted nowhere always says so on screen
