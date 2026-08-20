# Codex task spec — 13 — Overdue bills are invisible, and autopay needs settling

## The defect, found in real use
A bill whose due date had passed was still shown as "Upcoming" with an `AUTO PAY` label and had
not been recorded as spent.

The projection maths is correct — `remainingBills` counts overdue occurrences with no date
filter, so the money is still subtracted. Two presentation/workflow faults sit on top:

1. `UpcomingBillsSection.status(for:)` derives its label from `isAutoPay` and `amountType` only.
   **It never looks at the date**, so an overdue bill is indistinguishable from a future one and
   sits under a heading that calls it "Upcoming".
2. An autopay bill past its due date has almost certainly been paid — the money left the account
   — but the app keeps it as an unpaid obligation. `AVAILABLE THIS MONTH` therefore overstates
   cash and `EXPENSES` understates spending until the user manually marks it paid. Requiring
   manual confirmation for a payment that is by definition automatic is the wrong default.

`ExpectedIncomeSection` already solved the first half for income (`OVERDUE` / `EXPECTED`). Bills
should match it — the two sections must read as a pair.

## Scope
Anything under `FlowPlan/` and `FlowPlanTests/`.
Do NOT touch `Packages/FlowPlanDomain/**` — the engine is correct — or `FlowPlan.xcodeproj`.

## 1. Overdue status on bills
Extend the bill row status so the date is considered, in this precedence:

- occurrence date **before today** → `OVERDUE`
- otherwise `AUTO PAY` / `ESTIMATED` / `UPCOMING` exactly as now

`OVERDUE` must be visually distinct from the other labels and must **not** rely on colour alone —
pair it with an SF Symbol (`exclamationmark.circle`) as the projection status badge does. Reuse
the income section's overdue treatment so the two match.

Sort overdue occurrences to the top of the list, oldest first, ahead of future ones.

Reference date comes from an injectable clock, not `Date()` inline, so it is testable.

## 2. Rename the section honestly
"Upcoming" is wrong once it contains overdue items. Title the section **`Bills`** with the same
`View All` affordance, or keep `Upcoming` and add a separate `Overdue` group above it — pick one
and be consistent with how income presents the same situation. Do not leave a past-due item under
a heading that says upcoming.

## 3. Settling autopay bills
Add a way to settle overdue autopay bills without visiting each row:

- When one or more **autopay** occurrences are past due and unsettled, show an inline prompt at
  the top of the section: "{n} autopay bills were due. Mark them paid?" with a
  **Mark all as paid** action and a dismiss.
- The action settles each of those occurrences through `repository.markBillPaid(...)` at its own
  due date and amount, then calls `projectionStore.refresh()` once.
- **Do not settle anything silently.** A scheduled payment can fail, and writing transactions the
  user never confirmed would put a wrong number in their history. The prompt is one tap; that is
  the right trade.
- Dismissing must persist for that set of occurrences so the prompt does not nag on every launch.

Non-autopay overdue bills keep the existing per-row swipe only — they genuinely may not be paid.

## Tests
- an occurrence dated before the reference date reports `OVERDUE`; on or after reports its
  normal status; an autopay bill due tomorrow is `AUTO PAY`, due yesterday is `OVERDUE`
- overdue occurrences sort above future ones, oldest first
- "Mark all as paid" settles exactly the overdue autopay occurrences and leaves manual and
  future ones untouched
- after settling, `remainingBills` falls by the settled total, `expensesPaid` rises by it, and
  **`projectedEndOfMonthBalance` is unchanged** — the double-counting invariant
- `currentAvailableBalance` falls by the settled total, which is the whole point of the fix
- dismissing the prompt keeps it dismissed for those occurrences across a refresh

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` unchanged (87 pass)
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] no past-due bill is ever labelled `UPCOMING` or shown under an "Upcoming" heading
