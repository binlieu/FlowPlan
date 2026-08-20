# FlowPlan QA Report — 2026-08-19

## Summary

The pure projection engine is healthy: its formulas, recurrence boundaries, settlement counts, zero-denominator guards, and unclamped negative results match the specifications, and all 87 domain tests pass. The exact master-prompt §61 car-repair invariant passes (`$600` of unbudgeted spending moves the projection by exactly `-$600`), and the static transaction-save path refreshes `ProjectionStore`, so that numerical acceptance path holds. The MVP should not be accepted as a whole yet because the app layer can double-count entered paychecks, cannot collect the required starting balance, and has several persistence and Decimal-pipeline failures that can produce wrong numbers or a crash. The app target and device UI could not be run in this sandbox because CoreSimulator and Xcode's package sandbox were unavailable, so the accessibility and device-layout findings below are static, reproducible code findings rather than simulator observations.

## 1. Critical issues

### 1.1 A paycheck entered through the UI cannot settle planned income and is counted twice

- **Location:** `FlowPlan/Features/Transactions/AddTransactionView.swift:418-455`; `FlowPlan/Data/Repositories/FinanceRepository.swift:137-145,369-387`; `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/MonthlyProjectionEngine.swift:26-39`.
- **Trigger:** Create one monthly income source for `$1,000`, then use Add Transaction to enter the received `$1,000` as Income in the same month.
- **Expected:** The transaction is linked to the income occurrence: `incomeReceived = 1,000`, `remainingExpectedIncome = 0`, `totalExpectedIncome = 1,000`, and the income contribution to projected month end is `$1,000`.
- **Actual:** Add Transaction always calls `addTransaction` without `settlesIncomeID`; the dedicated `markIncomeReceived` method is never called by app code. The engine correctly treats that unlinked transaction as extra income, so `incomeReceived = 1,000`, `remainingExpectedIncome = 1,000`, `totalExpectedIncome = 2,000`, and projected month end is overstated by `$1,000`.

### 1.2 `markIncomeReceived` allows the same occurrence to be settled repeatedly

- **Location:** `FlowPlan/Data/Repositories/FinanceRepository.swift:369-387` (compare the bill duplicate guard at `FinanceRepository.swift:339-351`).
- **Trigger:** For one `$1,000` monthly income occurrence, call `markIncomeReceived(incomeID:amount:on:)` twice in that month.
- **Expected:** The second call throws `settlementAlreadyRecorded`; the month contains one linked `$1,000` paycheck and projects `$1,000` of income.
- **Actual:** Both calls insert transactions. The engine reports `incomeReceived = 2,000`, `remainingExpectedIncome = 0`, and projects `$2,000`, even though only one occurrence existed.

### 1.3 Users cannot enter the starting balance required by the projection

- **Location:** `FlowPlan/Data/Repositories/FinanceRepository.swift:295-321`; `FlowPlan/Features/Plan/PlanView.swift:12-52`. `setStartingBalance` has no call site under `FlowPlan/` outside previews/sample/import support.
- **Trigger:** On a fresh install, the user starts the month with `$2,400`, plans `$1,000` of income and a `$200` bill, and does not load sample data or import JSON.
- **Expected:** The Plan UI lets the user record `$2,400`, and projected month end is `$2,400 + $1,000 - $200 = $3,200`.
- **Actual:** There is no starting-balance editor, so the repository returns `.zero` and projected month end is `$800`, understated by `$2,400`. Importing JSON or loading development sample data are the only non-test ways to create the row.

### 1.4 Plan money fields misparse comma decimal separators by 100×

- **Location:** `FlowPlan/Features/Plan/EditIncomeView.swift:209-218`, reused by `EditIncomeView.swift:110`, `EditBillView.swift:120`, `EditBudgetView.swift:98`, and `EditSavingsGoalView.swift:108-113`.
- **Trigger:** With a locale whose decimal separator is a comma, enter `12,50` in any Plan amount field and save.
- **Expected:** The stored `Decimal` is `12.50`.
- **Actual:** `PlanAmountParser` removes every comma and parses the POSIX string `1250`, so the stored amount is `1,250`. This exact conversion was reproduced from the checked-in parser logic.

### 1.5 Failed repository writes are not rolled back and can leave UI state and projection state disagreeing

- **Location:** `FlowPlan/Data/Repositories/FinanceRepository.swift:148-162` (the same mutate-then-save pattern is used throughout `FinanceRepository.swift:137-387`); `FlowPlan/Features/Transactions/AddTransactionView.swift:463-466`.
- **Trigger:** Start with an existing `$100` expense, edit it to `$900`, and force `ModelContext.save()` to fail (for example, a full/unwritable store or a persistence constraint failure).
- **Expected:** The error is shown, the stored/in-memory transaction remains `$100`, and the projection remains based on `$100`.
- **Actual:** The managed entity is changed to `$900` before `save()` throws, and neither repository nor caller invokes `context.rollback()`. The error path skips `projectionStore.refresh()`, leaving an unsaved `$900` entity observable from the context while the published projection still reflects `$100`; a later successful save can persist the failed edit.

### 1.6 Creating a month-only budget override is not atomic and a failed save can replace the effective budget with a partial copy

- **Location:** `FlowPlan/Features/Plan/EditBudgetView.swift:162-180,184-207`; `FlowPlan/Data/Repositories/FinanceRepository.swift:100-123,243-248`.
- **Trigger:** Defaults contain `Groceries = $500` and `Dining = $300`. Add an August-only `Utilities = $100` budget and force the second clone or final add to fail after the first default clone has saved.
- **Expected:** The operation fails as one transaction and August continues using both defaults, total `$800`.
- **Actual:** Each clone saves independently. Once the first `$500` override exists, `budgets(for:)` suppresses all defaults and returns only the partial override set, so the failed operation leaves August with an effective budget of `$500` and moves its projection by `$300`.

### 1.7 Category identity is case-sensitive in projection math but case-insensitive elsewhere in the UI

- **Location:** `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/MonthlyProjectionEngine.swift:59-68`; `FlowPlan/Features/Transactions/AddTransactionView.swift:403-414`; `FlowPlan/Features/Settings/CategoriesSettingsView.swift:286-291`; `FlowPlan/Features/Plan/EditBudgetView.swift:33-41`.
- **Trigger:** Create a `Groceries = $500` budget, then add a `$100` expense under a newly typed `groceries` category.
- **Expected:** The expense consumes `$100` of the Groceries allowance: `$100` actual plus `$400` remaining, so the category contributes `-$500` to projected month end.
- **Actual:** The engine treats the strings as different keys: `$100` actual plus the untouched `$500` budget remain, so the category contributes `-$600` and projected month end is understated by `$100`. Settings deduplicates these same names case-insensitively, making the identity rules internally inconsistent.

### 1.8 Money crosses through `Double`/`CGFloat`; the savings editor can crash and charts lose exact values

- **Location:** `FlowPlan/Features/Plan/SavingsGoalSection.swift:17-18,123-145,161-186,198-209`; `FlowPlan/Features/Insights/IncomeVsExpensesChart.swift:97-103`; `FlowPlan/Features/Insights/SpendingByCategoryChart.swift:72-77`; `FlowPlan/Features/Home/EstimatedSavingsCard.swift:137-144`; `FlowPlan/Features/Home/CashFlowBar.swift:102-107,154-155`; `FlowPlan/Features/Home/MonthSpendingCard.swift:151-155,182-183`; `FlowPlan/Shared/DesignSystem/BudgetProgressBar.swift:37-44`.
- **Trigger A:** Import or otherwise persist an active monthly savings target of `10,000,000,000,000,000,000`, then open Plan.
- **Expected:** The Decimal value is either rendered exactly or rejected with validation.
- **Actual:** The target is converted to `Double`, then `sliderTarget` executes `Int(value.rounded())`; the value exceeds `Int.max` and traps, crashing the screen.
- **Trigger B:** Render a chart amount of `9,007,199,254,740,993`.
- **Expected:** The plotted/spoken financial value remains exactly `9,007,199,254,740,993`.
- **Actual:** `NSDecimalNumber.doubleValue` becomes `9,007,199,254,740,992`, losing one unit before charting or accessibility descriptor generation. This violates the repository's explicit Decimal-only money-path rule even where the conversion is display-only.

### 1.9 Repository read failures are silently converted into valid-looking empty financial data

- **Location:** `FlowPlan/Data/Repositories/FinanceRepository.swift:38-54,496-504`; `FlowPlan/App/ProjectionStore.swift:33-41`.
- **Trigger:** Persist a month with a `$500` starting balance, `$1,000` expected income, a `$200` bill, and a `$300` budget; then force its SwiftData fetches to fail during `projectionStore.refresh()` (for example, by opening a damaged/unavailable store).
- **Expected:** Refresh surfaces an error and retains the last known projection rather than asserting that no data exists.
- **Actual:** Every failed fetch is logged generically and returned as `[]`; the failed starting-balance fetch becomes `.zero`. `ProjectionStore` accepts that as real input and publishes a `$0` projection, hiding all records and presenting a materially wrong number with no user-visible error.

## 2. Medium issues

### 2.1 `InsightsView` calls the projection engine outside `ProjectionStore` and performs at least 13 repository fetches per populated render

- **Location:** `FlowPlan/Features/Insights/InsightsView.swift:9-10,12-44,80-105`.
- **Trigger:** Open Insights for a month containing transactions and cause one body reevaluation (for example, change Dynamic Type or return from another screen).
- **Expected:** The view reads cached view state; `ProjectionStore` remains the single engine caller, with each required dataset fetched once per refresh.
- **Actual:** `previousProjection` rebuilds an input and calls `MonthlyProjectionEngine.project` during body evaluation. `currentTransactions` is fetched four times, `previousTransactions` twice, `bills` once, and the previous projection input performs six more repository reads: at least 13 fetches plus an engine run for one render.

### 2.2 Budget rows duplicate financial aggregation inside body evaluation

- **Location:** `FlowPlan/Features/Plan/SpendingBudgetSection.swift:12-31,55-102`.
- **Trigger:** Render Plan with 100 budget rows and 10,000 monthly transactions.
- **Expected:** Per-category totals are computed once outside the SwiftUI body and supplied as state from the authoritative calculation layer.
- **Actual:** Every `budgetRow` filters and reduces the complete transaction array, causing about 1,000,000 predicate checks on each body evaluation and duplicating the engine's category-spending rule in a view.

### 2.3 The UI presents projected cash balance as savings, including impossible goal copy

- **Location:** `FlowPlan/Features/Home/EstimatedSavingsCard.swift:53-70,103-135`; `FlowPlan/Features/Home/CashFlowBar.swift:102-115,134-138`.
- **Trigger:** Use a plan with projected month-end balance `-$420` and a `$2,000` savings target.
- **Expected:** The screen factually says there is a projected `$420` shortfall and separately reports savings progress.
- **Actual:** The card says `ESTIMATED SAVINGS -$420`, displays `-$420 / $2,000` as the goal, and VoiceOver announces “Estimated savings, negative 420…”. The cash-flow legend repeats the same misclassification.

### 2.4 Insights ignore the user's selected currency

- **Location:** `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/InsightsEngine.swift:52-77,154-178`; `FlowPlan/Features/Insights/InsightsView.swift:98-105`.
- **Trigger:** Select EUR and produce a `$500`-equivalent projection variance or income gap.
- **Expected:** Insight copy uses the selected currency, for example `€500` under an appropriate locale.
- **Actual:** `InsightsEngine` hardcodes currency code `USD` and locale `en_US`, so the message displays `$500` while the rest of the screen displays euros.

### 2.5 The savings insight makes an unsupported “on track” claim

- **Location:** `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/InsightsEngine.swift:82-92`.
- **Trigger:** On the last day of the month, set `savingsTarget = $2,000`, `savingsCompleted = $0`, and leave the full `$2,000` remaining.
- **Expected:** Factual copy reports `$0 saved` and `$2,000 remaining`, or omits a pace judgement.
- **Actual:** The only condition is `savingsTarget > 0`, so the app says “You're on track to save $2,000 this month.”

### 2.6 The Home hero card is not one meaningful VoiceOver element

- **Location:** `FlowPlan/Features/Home/AvailableThisMonthCard.swift:19-47,90-107,146-168`.
- **Trigger:** Enable VoiceOver and focus a populated Available This Month card.
- **Expected:** One focus stop announces the card's meaning and all relevant values together.
- **Actual:** The card has no container-level accessibility grouping or label. Its amount is one element and each of the three metrics is separately combined, producing multiple disconnected focus stops instead of one meaningful hero element.

### 2.7 The Face ID overlay does not remove financial tabs from the accessibility tree

- **Location:** `FlowPlan/App/RootView.swift:21-32`; `FlowPlan/App/AppLockView.swift:6-55`.
- **Trigger:** Enable Face ID, lock the app, turn on VoiceOver, and navigate past the Unlock control.
- **Expected:** Only the modal lock content is accessible; balances, transaction rows, and tabs are hidden until authentication succeeds.
- **Actual:** `tabs` remains a sibling under the opaque lock overlay, with no `.accessibilityHidden(biometricGate.isLocked)` or modal accessibility containment. `zIndex` changes drawing order only, so the underlying financial controls remain in the accessibility hierarchy.

### 2.8 Compact money formatting assumes exactly two fractional digits

- **Location:** `FlowPlan/Shared/Formatting/MoneyFormatter.swift:9-24`.
- **Trigger:** Use currency `KWD` and render compact amount `1.234`.
- **Expected:** Currency-aware output preserves the currency's three minor-unit digits, such as `KWD 1.234`.
- **Actual:** Compact style forces `.fractionLength(2)` for every fractional amount and displays `KWD 1.23`, contradicting the currency-agnostic formatting requirement.

### 2.9 Deactivating a savings goal strands it with no route to reactivate or delete it

- **Location:** `FlowPlan/Features/Plan/EditSavingsGoalView.swift:62-64,150-175`; `FlowPlan/Data/Repositories/FinanceRepository.swift:89-97`; `FlowPlan/Features/Plan/PlanView.swift:37-43`.
- **Trigger:** Edit the only savings goal, switch Active off, and save.
- **Expected:** The inactive goal remains visible in Plan with an inactive state so it can be edited, reactivated, or deleted.
- **Actual:** `savingsPlans()` filters inactive goals out. Plan then shows only Add Savings Goal, and the inactive record is no longer reachable from the UI.

### 2.10 An explicitly entered zero starting balance is reported as missing

- **Location:** `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/MonthlyProjectionEngine.swift:141-147`; `FlowPlan/Features/Home/AvailableThisMonthCard.swift:179-186`; `FlowPlan/Features/Projection/ProjectionCompletenessView.swift:66-81`.
- **Trigger:** Import a real MonthSettings row with starting balance `$0` and no other planning inputs.
- **Expected:** Zero is treated as an entered opening balance; completeness says it is present and the Home card shows the known `$0` state.
- **Actual:** Presence is inferred from `startingBalance != .zero`, so the value is declared missing and Home shows “No plan … yet.” The model has no separate presence signal to distinguish “entered zero” from “not entered.”

## 3. Minor issues

### 3.1 Plan section-header actions have sub-44-point touch targets

- **Location:** `FlowPlan/Features/Plan/ExpectedIncomeSection.swift:35-47`; `MonthlyBillsSection.swift:39-51`; `SpendingBudgetSection.swift:40-52`; `SavingsGoalSection.swift:60-81`.
- **Trigger:** Try to tap Add/Edit at the edge of its text label on an iPhone SE.
- **Expected:** Each interactive target is at least `44×44` points.
- **Actual:** The buttons use only a subheadline text label with no minimum frame or padding, leaving an intrinsic target well below 44 points high.

### 3.2 Transaction descriptions and categories are forced to one line at accessibility sizes

- **Location:** `FlowPlan/Features/Transactions/TransactionRow.swift:16-25`.
- **Trigger:** On iPhone SE at Dynamic Type `.accessibility5`, display a transaction named “Annual automobile insurance premium adjustment” in category “Transportation and vehicle maintenance”.
- **Expected:** The row grows vertically so the meaningful text remains readable.
- **Actual:** Both fields have `.lineLimit(1)` and truncate with an ellipsis.

### 3.3 Face ID appears twice in the same Settings screen

- **Location:** `FlowPlan/Features/Settings/SettingsView.swift:39-60,79-100`.
- **Trigger:** Open Settings on a Face ID-capable device.
- **Expected:** One Face ID control appears in Security.
- **Actual:** Identical toggles bound to the same value appear in both Preferences and Security, so changing either control silently changes the other duplicate.

### 3.4 The greeting is “Good morning” at every time of day

- **Location:** `FlowPlan/Features/Home/HomeView.swift:83-104`.
- **Trigger:** Open Home at 9:00 PM.
- **Expected:** A time-neutral greeting or “Good evening”.
- **Actual:** The hardcoded greeting is “Good morning”.

### 3.5 Project status documentation is materially stale

- **Location:** `docs/PROJECT_STATUS.md:14-38`.
- **Trigger:** A contributor reads the status before planning follow-up work.
- **Expected:** It reflects the implemented app and current test suite.
- **Actual:** It says the domain engine is still in progress, every later feature is next, and only placeholder tests exist, while this review ran 87 real domain tests over the completed feature set.

## 4. Fixes applied

None. This was a review-only pass; no source file was modified. Verification performed: `swift test --disable-sandbox` passed all 87 `FlowPlanDomain` tests. An app-target `xcodebuild` was attempted with temporary DerivedData/package/cache paths, but the managed environment blocked CoreSimulator and nested `sandbox-exec`, so no simulator, app test, or device-size visual pass was possible here.

## 5. Recommended tests

- `enteredPaycheckCanSettlePlannedIncomeWithoutDoubleCounting` — add a planned salary through the user flow, record its receipt, and assert `incomeReceived = plannedIncomeTotal`, `remainingExpectedIncome = 0`, and no projection jump.
- `markIncomeReceivedRejectsDuplicateOccurrence` — call the settlement API twice for one monthly occurrence and assert the second call throws and writes nothing.
- `incomeSettlementsMoreThanOccurrencesAreRejected` — cover the explicit “more transactions than occurrences” repository boundary; the domain already covers fewer settlements than occurrences.
- `orphanedIncomeSettlementCountsExactlyOnce` — import a transaction linked to a nonexistent income source and assert it remains received actual income without an expectation term.
- `planAmountParserRespectsCommaDecimalLocale` — under `fr_FR` or `de_DE`, assert `12,50` saves as `12.50` in income, bill, budget, and savings editors.
- `startingBalanceCanBeCreatedAndEditedFromPlan` — enter `$2,400`, refresh, and assert current/projected balances move by exactly `$2,400`.
- `zeroStartingBalanceCountsAsEntered` — persist an explicit zero MonthSettings row and assert completeness marks the balance present.
- `repositoryRollsBackFailedTransactionUpdate` — inject a failing save after mutating `$100` to `$900`; assert the context, disk value, and projection all remain `$100`.
- `monthBudgetOverrideCreationIsAtomic` — fail after the first copied default and assert no partial overrides exist and default budgets remain effective.
- `budgetCategoryIdentityIsCanonical` — mix `Groceries`, `groceries`, whitespace, and locale-sensitive casing; assert one category consumes one allowance exactly once.
- `savingsSliderHandlesDecimalBoundsWithoutDoubleOrIntTrap` — load targets around `2^53`, `Int.max`, and Decimal extremes and assert exact, noncrashing behavior.
- `monthlyAnchors29And30ClampAndRestoreAcrossFebruary` — supplement the existing 31st/leap tests with both missing anchor days across leap and non-leap February.
- `insightsUseSelectedCurrency` — set EUR and KWD and assert all insight strings and compact displays use the selected currency's locale/minor units.
- `savingsInsightDoesNotClaimOnTrackWithoutPaceEvidence` — last day, zero saved, positive remaining target; assert factual copy only.
- `insightsRenderFetchesEachDatasetOnceAndDoesNotCallProjectionEngine` — inject counting repositories/engine and assert body evaluation performs no financial computation.
- `lockedAppExposesOnlyLockAccessibilityElements` — UI test the locked VoiceOver hierarchy and assert no tab, balance, or transaction identifiers are reachable.
- `availableHeroIsOneAccessibilityElement` — assert a populated hero produces one focus element with current balance, income, expenses, and savings in its label/value.
- `planHeaderActionsMeetMinimumHitArea` — inspect Add/Edit frames and assert width and height are each at least 44 points.
- `darkModeAndAccessibility5DeviceMatrix` — snapshot every screen on iPhone SE-size and iPhone 17 Pro Max-size layouts in light/dark mode at `.accessibility5`, checking for clipped, overlapping, or truncated financial content.
