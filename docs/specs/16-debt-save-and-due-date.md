# Codex task spec — 16 — Debt will not save, and has no due date

Two defects reported from real use on a device.

## 1. The Save button is silently disabled (blocking)
`EditDebtView.isValid` requires a non-empty **Category** *and* a parseable **APR**:

```swift
!trimmedName.isEmpty
    && !trimmedCategory.isEmpty
    && parsedBalance.map { $0 >= .zero } == true
    && parsedAPRPercentage.map { $0 >= .zero } == true   // nil when blank → false
    && parsedPayment.map { $0 > .zero } == true
```

A user entering a 0% loan, or one whose rate they do not know, leaves APR blank and the button
never enables. Tapping it does nothing and **no message explains why**. The same applies to
Category, which is not obviously mandatory.

Fix:
- **APR is optional.** Blank means `.zero`. A 0% debt is ordinary — a family loan, an interest-free
  plan — and must not block saving.
- **Category is optional.** Blank defaults to `"Debt"`.
- Genuinely required: **name**, **balance ≥ 0**, **monthly payment > 0**. Nothing else.
- When the form is incomplete, show **inline validation under the offending field** saying what is
  needed ("Enter a monthly payment"). A disabled control with no explanation is the defect here,
  not the validation itself — apply the same rule to the other Plan editors if they share it.
- If a save throws, surface the error. `showSaveError()` exists; make sure it is reachable and its
  message is legible rather than a silent no-op.

Audit `EditIncomeView`, `EditBillView`, `EditBudgetView` and `EditSavingsGoalView` for the same
pattern — a required field the user cannot discover — and fix any you find the same way.

## 2. A debt payment has no due date
Debts have `monthlyPayment` but no day of the month, so unlike a bill a payment cannot be dated,
cannot go overdue, and cannot be settled month by month. That is a gap in spec 15, not a
misunderstanding by the implementation.

### Domain
Add to `Debt`:
```swift
/// Day of the month the payment is due, 1...31, clamped to the month's length exactly as
/// RecurrenceRule clamps a monthly bill anchored on the 31st.
public let dueDay: Int
```

Extend `DebtSchedule` so a payment has a date:
`paymentDate(for:in:calendar:) -> Date?` — the clamped due date within that month, `nil` once the
debt is paid off.

`MonthlyProjection` gains `debtOccurrences: [DebtOccurrence]` (debt id, name, date, amount,
`isPaidThroughBills`), so the UI can list dated payments without recomputing the schedule. Keep
`Foundation`-only purity; no `Date()` inside the engine.

**Rule 19 is unchanged** — a debt marked `isPaidThroughBills` still contributes nothing. Adding a
date must not alter a single existing projection figure: **all 98 domain tests must pass
unchanged**, and that is the acceptance signal that this change is purely additive.

### App
- Editor gains a due-day picker (1–31) with a plain-language preview: "Due on the 15th of each
  month". Default to the 1st.
- Debt rows on Plan show `Due {n}th · {n} payments left · paid off {Month Year}`.
- **Dated debt payments appear in Home's `Bills` section** alongside bills, marked so they are
  distinguishable (a `DEBT` chip), with the same `OVERDUE` treatment and the same
  **Mark as paid** swipe, routing to `markDebtPaymentMade`. Debts marked `isPaidThroughBills` are
  **excluded** — their bill already appears there, and listing both is the double count this
  feature exists to avoid.
- Autopay bulk-settle stays bills-only; debt payments are settled individually.

## Tests
- a debt saves with APR and Category both blank, storing `.zero` APR and category `"Debt"`
- saving with an empty name, zero payment, or negative balance is blocked **and shows a message**
- `dueDay` 31 clamps to 30 in April and to 28/29 in February
- `paymentDate` returns nil after the payoff month
- a dated debt payment appears in the Home bills list, is `OVERDUE` when its date has passed, and
  settling it moves `remainingDebtPayments` to `debtPaymentsMade` with
  `projectedEndOfMonthBalance` **unchanged**
- a debt marked `isPaidThroughBills` never appears in the Home bills list
- all 98 existing domain tests pass unchanged

## Done when
- [ ] a debt saves with only name, balance and payment filled in
- [ ] no Plan editor has a disabled Save with no on-screen reason
- [ ] `cd Packages/FlowPlanDomain && swift test` — 98 prior tests pass, plus the new ones
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
