# Codex task spec — 11 — Expected income needs a "mark as received" workflow

## The defect, found in real use
The owner entered a weekly salary as planned income. Home showed:

```
AVAILABLE THIS MONTH   $0.00
INCOME  +$8,328    EXPENSES  $0    SAVINGS  $0
```

The arithmetic is correct — `currentAvailableBalance = startingBalance + incomeReceived − …`,
and `incomeReceived` counts only actual `.income` transactions, of which there were none. The
`$8,328` is `totalExpectedIncome`, i.e. the plan.

Two things are wrong at the product level:

1. **Bills can be settled in one tap; income cannot.** `markBillPaid` is wired into
   `UpcomingBillsSection` on Home. `markIncomeReceived` exists only inside `AddTransactionView`.
   Recording a weekly salary therefore means manually adding four transactions and linking each,
   while a bill takes one swipe. Fix the asymmetry.
2. **`$0.00` directly above `+$8,328` reads as a contradiction.** The screen states a figure it
   does not explain, which is the failure mode this product exists to avoid.

## Scope
Anything under `FlowPlan/` and `FlowPlanTests/`. Do NOT touch
`Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/**`,
`.../Models/ProjectionModels.swift`, `FlowPlan/Data/Repositories/FinanceRepository.swift`
(the settle methods already exist and are correct), or `FlowPlan.xcodeproj`.

## 1. `ExpectedIncomeSection` on Home
Create `FlowPlan/Features/Home/ExpectedIncomeSection.swift`, placed **directly above**
`UpcomingBillsSection`, and built to mirror it so the two read as a pair.

- Heading `Expected income` with a `View All` link to Plan.
- One row per **unsettled** income occurrence in the selected month, soonest first: a monogram
  square (as bills use), the source name, the expected date, the amount, and a small-caps status
  label — `OVERDUE` when the occurrence date has passed, otherwise `EXPECTED`.
- Leading swipe action **"Mark as received"**, plus a tappable row that opens a small confirm
  sheet showing the amount and date with an editable amount (real pay varies) and a
  **Mark as received** button.
- Both routes call `repository.markIncomeReceived(incomeID:amount:on:)` then
  `projectionStore.refresh()`. Do not create transactions any other way here.
- Cap at five rows with a "See all" affordance, matching the bills section.
- Hide the whole section when there are no unsettled occurrences.
- Accessibility: each row is one element reading name, date, amount and status; the swipe action
  has an accessible label.

To list unsettled occurrences, add a repository read (allowed: this is a new method on the
repository, not a change to the settle logic) or a small view-model helper that derives them from
`incomeSources()` and the month's transactions using the **same settled-in-date-order rule** the
engine uses. If you derive it, put it in one place both this section and Add Transaction's
"Match planned income" picker use — the two must never disagree about what is unsettled.

## 2. Explain a zero available balance
In `AvailableThisMonthCard`, when `currentAvailableBalance == 0`:

- if `remainingExpectedIncome > 0` and nothing has been received, show a secondary line:
  "No income recorded as received yet — {remainingExpectedIncome} still expected this month."
- if the starting balance has never been set, add: "Set your starting balance in Plan." with a
  tap target routing to Plan.

Factual, no judgement, and never shown when the balance is genuinely zero after real activity.

## 3. First-run asks for the starting balance
The Home first-run state currently offers only "Go to Plan". Add starting balance to what it
asks for, so a new user is not silently projecting from zero. A single amount field inline in the
first-run card, writing through `repository.setStartingBalance(_:for:)`, is enough — do not build
a wizard.

## Tests
- marking an occurrence received raises `currentAvailableBalance` by exactly that amount and
  lowers `remainingExpectedIncome` by the same, leaving `totalExpectedIncome` unchanged
- marking received twice for the same occurrence is rejected (the repository already guards this;
  assert the UI path surfaces it rather than crashing or duplicating)
- an occurrence with a date in the past reports `OVERDUE`, a future one `EXPECTED`
- the unsettled-occurrence list matches what Add Transaction's picker offers, for the same data
- a partial amount (received 900 against an expected 1,000) settles the occurrence and credits
  exactly 900
- the zero-balance explanation appears only when income is expected and none received

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` unchanged (87 pass)
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] `grep -rn "markIncomeReceived" FlowPlan/Features/Home/` shows the new call site
- [ ] Home shows expected income and upcoming bills as a matched pair
