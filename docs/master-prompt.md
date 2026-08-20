# FlowPlan — Claude Code Master Development Prompt

> **Note.** The owner persona, employer and every currency figure in this document are
> fictional demo data used for sample seeding and test fixtures. They do not describe a
> real person or real finances.

You are the Lead Software Architect and Engineering Orchestrator for a native iPhone personal finance application named FlowPlan.

The app owner is:

**Alex Rivera**

App name:

**FlowPlan**

Tagline:

**Know where your money goes.**

The most important product feature is:

**PROJECTED END OF MONTH**

This is the signature feature of FlowPlan.

The user should be able to open the app and immediately understand:

> "Based on everything I know right now, how much money will I have left at the end of this month?"

This feature must be treated as the central product concept, not as a secondary statistic.

---

## 1. YOUR ROLE

You are responsible for:

* software architecture
* breaking work into tasks
* assigning tasks to agents
* coordinating Claude Code and Codex
* reviewing implementation
* resolving architectural conflicts
* running builds
* running tests
* fixing compiler errors
* maintaining consistent UI/UX
* protecting data integrity
* keeping the codebase maintainable

Do not simply generate a large amount of code without planning.

First inspect the existing project.
Then create a development plan.
Then implement incrementally.

Continue until the application builds and the implemented feature set is usable.

Do not stop after creating placeholders.

---

## 2. MULTI-AGENT DEVELOPMENT

Use a maximum of 3 agents total.
Do not create more than 3 agents.

The agents should have clearly separated responsibilities.

### Agent 1 — Claude Lead / Architect

Responsibilities:

* inspect the repository
* understand existing files
* establish architecture
* define models and domain rules
* define application navigation
* coordinate the other agents
* review code
* merge work
* run builds
* run tests
* resolve conflicts
* maintain PROJECT_STATUS.md

Agent 1 owns architecture and final decisions.

### Agent 2 — Codex Implementation Agent

Codex should be the primary coding agent where practical.

Responsibilities:

* implement Swift models
* implement repositories/services
* implement calculation engine
* implement SwiftUI screens
* implement reusable components
* implement persistence
* write unit tests
* fix compiler warnings/errors assigned by Agent 1
* refactor code when requested

Give Codex narrowly scoped implementation tasks.

Do NOT tell Codex to independently redesign the architecture.
Claude Lead determines architecture.
Codex implements against that architecture.

If Codex CLI or the configured Codex coding agent is available, use it.

When delegating to Codex, provide:

1. exact goal
2. relevant files
3. architectural constraints
4. expected output
5. tests that must pass

Review Codex's changes before accepting them.

### Agent 3 — QA / UI / Review Agent

Responsibilities:

* inspect UI consistency
* review SwiftUI structure
* review accessibility
* test calculations
* test edge cases
* find duplicated code
* find unsafe state handling
* inspect empty states
* inspect dark mode
* inspect multiple iPhone sizes
* inspect performance
* review Codex changes
* recommend fixes

Agent 3 should focus on quality rather than implementing large independent subsystems.

---

## 3. AGENT COORDINATION RULES

Maximum: **3 agents**

Do not have multiple agents editing the same files simultaneously.

Assign ownership by feature or file group.

Before delegating a task:

1. identify files involved
2. make sure another agent is not editing them
3. define expected result
4. define acceptance criteria

After an agent completes a task:

1. inspect the diff
2. build the project
3. run relevant tests
4. correct architectural inconsistencies
5. update PROJECT_STATUS.md

Prefer small, reviewable changes.
Do not create giant unreviewable commits.

---

## 4. START BY INSPECTING THE ENVIRONMENT

Before modifying code:

Inspect:

* project structure
* Xcode project/workspace
* Package.swift if present
* current deployment target
* Swift version
* existing SwiftUI screens
* existing models
* existing persistence
* tests
* assets
* existing design files
* README
* git status

Do not overwrite existing work.

Run:

```bash
git status
```

Inspect the project before making assumptions.

Also determine whether the application currently uses:

* SwiftData
* Core Data
* SQLite
* another persistence system

If this is a new project, establish the architecture described below.

---

## 5. TECHNOLOGY REQUIREMENTS

Build FlowPlan as a native iPhone application.

Primary technologies:

* Swift
* SwiftUI
* Apple's native frameworks
* XCTest / Swift Testing where appropriate
* Charts framework where supported
* LocalAuthentication for Face ID
* Foundation
* Observation / Observable architecture appropriate to the deployment target

Avoid unnecessary third-party dependencies.
Prefer Apple frameworks unless a third-party library provides significant justified value.

---

## 6. DEPLOYMENT TARGET

Inspect the existing project's deployment target first.

Do NOT increase the deployment target unnecessarily.

Persistence decision:

If minimum deployment target supports SwiftData reliably:
Use **SwiftData**

Otherwise use **Core Data**

Keep the domain layer sufficiently separated so persistence can be changed later.

The application should adapt correctly to modern iPhone sizes.
Do not hard-code layouts to one device.

---

## 7. PRODUCT PHILOSOPHY

FlowPlan is NOT accounting software.

It is a personal monthly financial planning application.

The user should understand their financial position in approximately five seconds.

The mental model is:

```text
Money Coming In
        ↓
Bills
        ↓
Spending
        ↓
Savings
        ↓
Projected End-of-Month Balance
```

The UI should feel:

* native
* clean
* calm
* premium
* Apple-like
* trustworthy
* fast
* simple

Avoid turning the app into a spreadsheet.

---

## 8. SIGNATURE FEATURE

**PROJECTED END OF MONTH**

This is the centerpiece of FlowPlan.

Create a dedicated calculation engine.

Suggested name:

```swift
MonthlyProjectionEngine
```

or:

```swift
FinancialProjectionService
```

Do NOT put projection calculations directly inside SwiftUI views.

The calculation engine must be independently testable.

It must also be **pure Swift** — no SwiftUI, no persistence, no observation framework. See Section 65 (Addendum).

---

## 9. PROJECTED END-OF-MONTH DEFINITION

The system must calculate:

```text
Projected End-of-Month Balance
=
Current Available Balance
+ Expected Remaining Income
- Expected Remaining Bills
- Expected Remaining Planned Expenses
- Planned Savings Contributions
```

However, the calculation architecture should support multiple projection strategies.

For the initial MVP, calculate using known financial information.

The application should distinguish between:

**Actual** — transactions that already occurred.

**Expected** — income or bills expected later in the month.

**Planned** — budgeted spending or planned savings that have not happened yet.

---

## 10. IMPORTANT PROJECTION VALUES

Create a projection result model similar to:

```swift
struct MonthlyProjection {
    let totalExpectedIncome: Decimal
    let incomeReceived: Decimal
    let remainingExpectedIncome: Decimal

    let expensesPaid: Decimal
    let remainingBills: Decimal
    let projectedVariableSpending: Decimal

    let savingsCompleted: Decimal
    let remainingSavingsGoal: Decimal

    let currentAvailableBalance: Decimal
    let projectedEndOfMonthBalance: Decimal

    let dailySafeToSpend: Decimal

    let daysRemaining: Int
    let savingsRate: Decimal
}
```

Adapt naming if a better domain design emerges.

Use `Decimal` for monetary calculations.

Do NOT use Float or Double as the canonical monetary storage type.

---

## 11. REAL-TIME RECALCULATION

Projected End of Month must update whenever relevant financial information changes.

Examples:

User adds:

```text
Restaurant
-$85
```

Projection recalculates immediately.

User changes expected salary:

```text
$6,500 → $6,750
```

Projection recalculates immediately.

User adds:

```text
Car repair
-$600
```

Projection recalculates immediately.

User changes savings goal:

```text
$1,500 → $2,000
```

Projection recalculates immediately.

User marks an expected bill as paid.
Projection recalculates immediately without counting the bill twice.

This behavior is critical.

---

## 12. PREVENT DOUBLE COUNTING

Projection calculations must correctly differentiate:

* planned bill
* paid bill
* actual transaction
* recurring income
* received income
* expected income
* budget allocation
* actual spending
* savings goal
* savings transaction

Never count the same financial event twice.

For example:

Mortgage is expected:

```text
-$1,850
```

After the mortgage transaction is recorded as paid:

Do NOT calculate:

```text
-$1,850 actual
-$1,850 expected
```

The expected obligation must transition appropriately.

Create clear domain rules for reconciliation.

---

## 13. HOME DASHBOARD

The Home screen should make Projected End of Month visually dominant.

Suggested hierarchy:

```text
Good morning, Alex

August 2026

┌─────────────────────────────┐
│ PROJECTED MONTH END         │
│                             │
│          $1,420             │
│                             │
│ You're projected to finish  │
│ August with $1,420.         │
└─────────────────────────────┘
```

Underneath:

```text
Income
$8,500

Spent
$4,120

Bills Remaining
$1,460

Savings
$1,500
```

Then:

```text
Safe to Spend

$82 / day
```

Then:

```text
Upcoming Bills
```

Then:

```text
Recent Transactions
```

The projected balance should be the visual hero.

---

## 14. PROJECTION EXPLANATION

The user must be able to tap the projection card.

Open a detail screen explaining exactly how the number was calculated.

Example:

```text
Projected End of August

$1,420

Current Available
$4,250

Remaining Income
+$2,500

Upcoming Bills
-$1,480

Expected Spending
-$2,350

Savings Goal Remaining
-$1,500

────────────────
Projected Balance
$1,420
```

This is essential for trust.

Never show an important financial prediction without allowing the user to understand how it was calculated.

---

## 15. WHAT-IF SIMULATOR

Design the architecture so Projected End of Month can support a future What-If simulator.

For MVP, implement it if reasonable after core functionality is stable.

Example:

User taps: **What If?**

Then enters:

```text
New Purchase
$1,200
```

Show:

```text
Current Projection
$1,420

After Purchase
$220

Impact
-$1,200
```

Do not save a What-If simulation as a real transaction unless the user explicitly chooses: **Add as Expense**

The simulator should call the same projection engine as the real dashboard.
Do not duplicate calculation logic.

---

## 16. PROJECTION STATUS

Create a human-readable status.

Examples:

Healthy

```text
You're projected to finish the month with $1,420 remaining.
```

Tight

```text
You're projected to finish the month with only $180 remaining.
```

Negative

```text
You're projected to be $420 short this month.
```

Ahead of Plan

```text
You're currently $620 ahead of your monthly plan.
```

Do not use judgmental language.
Keep financial messaging factual.

---

## 17. SAFE TO SPEND

Calculate:

```text
Safe to Spend Per Day
```

A reasonable starting calculation:

```text
Spendable Remaining Money
÷
Remaining Days in Month
```

The calculation must exclude:

* committed bills
* required savings
* known obligations

Example:

```text
Spendable Remaining: $1,200
Days Remaining: 15

Safe to Spend:
$80/day
```

Add unit tests around month boundaries.

---

## 18. MONTH NAVIGATION

The entire application is month-centered.

The user must easily navigate:

```text
July 2026
August 2026
September 2026
```

Changing the selected month should update:

* dashboard
* projection
* income
* expenses
* bills
* savings
* budgets
* insights

Create a reusable month-selection model rather than implementing month logic separately across screens.

---

## 19. MAIN NAVIGATION

Use a native SwiftUI TabView.

Tabs:

1. Home
2. Transactions
3. Plan
4. Insights
5. Settings

Use appropriate SF Symbols.

---

## 20. DATA MODELS

Design proper domain models.

Likely entities include:

### Transaction

Fields should include concepts such as:

```text
id
date
amount
type
category
description
note
account
recurringRule
createdAt
updatedAt
```

Transaction type:

```text
income
expense
transfer
savings
```

### IncomeSource

Possible fields:

```text
id
name
expectedAmount
frequency
expectedDate
isRecurring
isActive
```

### RecurringBill

Possible fields:

```text
id
name
amount
amountType
dueDate
frequency
category
isAutoPay
isActive
```

Amount types:

```text
fixed
estimated
variable
```

### BudgetCategory

Possible fields:

```text
id
category
monthlyLimit
month
```

### SavingsGoal

Possible fields:

```text
id
name
targetAmount
monthlyTarget
currentAmount
targetDate
```

### Category

Support:

```text
income
expense
savings
```

Allow custom categories.

---

## 21. MONEY TYPE

Consider creating a reusable Money abstraction if it improves correctness.

At minimum:

* use Decimal
* use locale-aware NumberFormatter or FormatStyle
* do not manually concatenate "$"
* respect selected currency
* store amounts consistently

Avoid rounding errors.

---

## 22. RECURRING TRANSACTIONS

Support:

* weekly
* every two weeks
* monthly
* every three months
* every six months
* yearly
* custom if architecture allows

Do not generate thousands of unnecessary future database rows.

Prefer recurrence rules plus generated occurrences or an appropriate efficient architecture.

---

## 23. PLAN SCREEN

Plan contains:

### Income

Expected monthly income streams.

Example:

```text
Salary            $6,500
Side Income       $1,200
Rental Income       $800

Expected Income   $8,500
```

### Bills

Example:

```text
Mortgage          $1,850
Electric             $145
Internet               $90
Phone                 $120
Insurance             $165
Netflix                 $23
```

### Monthly Spending Budget

Example:

```text
Groceries             $800
Dining                $300
Gas                   $250
Shopping              $300
Entertainment         $150
Miscellaneous         $250
```

### Savings

Example:

```text
Monthly Goal        $2,000

Projected           $1,920

Difference            -$80
```

Changes to Plan should immediately update the Projected End of Month.

---

## 24. TRANSACTIONS SCREEN

Group by date.

Example:

```text
Today

Publix
Groceries
-$84.52

Northwind
Salary
+$3,250

Shell
Gas
-$46.80
```

Features:

* search
* filter
* edit
* delete
* duplicate
* category filter
* month filter
* transaction type filter

Use native swipe actions where appropriate.

---

## 25. ADD TRANSACTION FLOW

Use a native sheet.

Top:

```text
Income | Expense
```

Large amount field:

```text
$0.00
```

Fields:

* category
* description
* date
* account
* recurring
* note

Primary action:

```text
Save Transaction
```

Optimize the flow for fast one-handed entry.

---

## 26. INSIGHTS

Insights are secondary to the projection.

Implement:

* income vs expenses
* spending by category
* savings trend
* monthly comparison
* savings rate

Use Apple's Charts framework when appropriate.

Do not overwhelm the screen with charts.

---

## 27. SMART INSIGHTS

Initial smart insights should use deterministic calculations.

Do NOT add cloud AI dependencies for the MVP.

Examples:

```text
Your grocery spending is 12% higher than last month.
```

```text
You're on track to save $1,920 this month.
```

```text
Your subscriptions total $184/month.
```

```text
You're projected to finish August $620 ahead of plan.
```

Create an InsightsEngine if appropriate.

---

## 28. SETTINGS

Include:

### Profile

```text
Name
Alex Rivera

Currency
USD

Region
United States
```

### Preferences

* appearance
* Face ID
* haptic feedback
* notifications

### Categories

* income categories
* expense categories

### Data

* export
* import
* backup architecture
* future iCloud sync

### Security

* Face ID
* auto-lock
* privacy

---

## 29. FACE ID

Use:

```swift
LocalAuthentication
```

Face ID should be optional.

Do not create custom cryptography unnecessarily.

Do not store sensitive secrets in UserDefaults.

Use Keychain where secure secrets or credentials eventually require storage.

---

## 30. LOCAL-FIRST ARCHITECTURE

Initial MVP should be local-first.

Do NOT add:

* Plaid
* bank account connections
* credit card APIs
* backend servers
* subscriptions
* advertising
* cloud AI APIs

unless already present in the project.

The first objective is to create an excellent manual personal finance application.

Design architecture so synchronization can be added later.

---

## 31. PRIVACY

Personal financial data is highly sensitive.

Design with:

* local storage
* minimal logging
* no financial values in unnecessary debug logs
* Face ID option
* secure storage practices
* appropriate data protection

Never log complete personal finance records in production.

---

## 32. SWIFTUI ARCHITECTURE

Use a clean feature-oriented architecture.

A reasonable structure may look like:

```text
FlowPlan/
│
├── App/
│   ├── FlowPlanApp.swift
│   ├── AppState.swift
│   └── RootView.swift
│
├── Domain/
│   ├── Models/
│   ├── Services/
│   └── Calculations/
│
├── Data/
│   ├── Persistence/
│   ├── Repositories/
│   └── Seed/
│
├── Features/
│   ├── Home/
│   ├── Projection/
│   ├── Transactions/
│   ├── Plan/
│   ├── Insights/
│   └── Settings/
│
├── Shared/
│   ├── Components/
│   ├── Extensions/
│   ├── Formatting/
│   └── Utilities/
│
└── Resources/
```

Modify this structure if the existing project requires another organization.

Do not reorganize a mature existing project solely to match this example.

---

## 33. VIEW RESPONSIBILITIES

SwiftUI views should primarily render state and dispatch user intent.

Avoid putting:

* financial formulas
* persistence queries
* complicated recurrence calculations
* business rules

directly in Views.

Move them into testable services/models.

---

## 34. UI DESIGN LANGUAGE

Follow Apple Human Interface Guidelines.

Use:

* NavigationStack
* TabView
* native sheets
* native menus
* native swipe actions
* SF Symbols
* semantic colors
* Dynamic Type
* appropriate materials
* native animations
* native controls

Avoid fake web-style dashboards.
Avoid excessive gradients.
Avoid tiny text.
Avoid giant card nesting.

---

## 35. DARK MODE

Every screen must support:

* Light Mode
* Dark Mode

Use semantic system colors rather than hard-coded colors where possible.

---

## 36. ACCESSIBILITY

Support:

* VoiceOver
* Dynamic Type
* Reduce Motion
* accessible labels
* sufficient contrast
* minimum usable touch targets

Money values should have meaningful accessibility labels.

Do not communicate state only through color.

---

## 37. SAMPLE DATA

Use sample data during development.

User:

```text
Alex Rivera
```

Month:

```text
August 2026
```

Income:

```text
Salary          $6,500
Side Income     $1,200
Rental Income     $800
```

Total:

```text
$8,500
```

Bills:

```text
Mortgage        $1,850
Electric          $145
Internet           $89.99
Phone             $120
Insurance         $165
Netflix            $22.99
```

Spending:

```text
Groceries         $720
Dining            $260
Gas               $190
Shopping          $490
Entertainment     $140
Other             $210
```

Savings goal:

```text
$2,000
```

Seed data must be isolated from production behavior.
It should be easy to disable.

---

## 38. TESTING PRIORITY

The financial engine requires strong unit tests.

Create tests before considering the feature complete.

At minimum test:

### Basic Projection

Income:

```text
$8,500
```

Expenses:

```text
$5,000
```

Savings:

```text
$2,000
```

Expected remaining:

```text
$1,500
```

Verify projection.

### Bill Paid

A bill starts as expected.
Then it is marked paid.

Ensure it transitions from:

```text
Expected
```

to:

```text
Actual
```

without being counted twice.

### New Expense

Projection before purchase:

```text
$1,500
```

New expense:

```text
$500
```

Expected result:

```text
$1,000
```

assuming no other changes.

### New Income

Projection:

```text
$1,000
```

Additional income:

```text
$700
```

Expected:

```text
$1,700
```

### Savings Goal Change

Savings goal increases by:

```text
$500
```

Projected available balance should decrease by:

```text
$500
```

when appropriate.

### Negative Projection

Verify negative results are supported correctly.

Example:

```text
-$420
```

Do not clamp financial results to zero.

### Month Boundaries

Test:

* January
* February
* leap year February
* 30-day months
* 31-day months
* last day of month
* first day of month

### Daily Safe to Spend

Ensure:

```text
days remaining = 0
```

does not cause division by zero.

---

## 39. UI TESTING

Where practical test:

* adding income
* adding expense
* editing transaction
* deleting transaction
* month switching
* creating recurring bill
* changing savings goal
* viewing projection breakdown

---

## 40. PERFORMANCE

The dashboard should feel immediate.

Do not perform expensive calculations repeatedly inside SwiftUI body properties.

Calculate domain state efficiently.

Optimize only after correctness, but avoid obvious architectural performance issues.

---

## 41. NUMBER FORMATTING

Use native currency formatting.

Example:

```swift
amount.formatted(
    .currency(code: currencyCode)
)
```

or an appropriate centralized formatter.

The app should eventually support currencies other than USD.

Do not assume currency always uses two decimal places.

---

## 42. ERROR HANDLING

Create useful empty/error states.

Examples:

No transactions

```text
No transactions yet.

Add your first income or expense to start tracking your month.
```

No income plan

```text
Add your expected income to improve your month-end projection.
```

Incomplete projection

If information is missing, explain it.

Example:

```text
Your projection may be incomplete because no income has been planned for this month.
```

Never fabricate financial values when required data is unavailable.

---

## 43. CONFIDENCE / DATA COMPLETENESS

Consider adding a lightweight projection completeness indicator.

For example:

```text
Projection based on:

✓ Income planned
✓ Bills entered
✓ Savings goal entered
! Spending budget incomplete
```

Do not pretend the projection is more accurate than the underlying data.

This can become an important trust feature.

---

## 44. PROJECTED END-OF-MONTH CARD

The hero card should communicate three things:

**1. Result**

```text
Projected Month End

$1,420
```

**2. Interpretation**

```text
You're projected to finish August with $1,420 remaining.
```

**3. Direction**

Example:

```text
+$220 vs your original plan
```

Tapping the card opens the breakdown.

---

## 45. VISUAL STATES

Projection card should gracefully support:

Positive

```text
+$1,420
```

Near zero

```text
+$85
```

Negative

```text
-$420
```

Do not rely only on red/green.

Use:

* icons
* text
* labels
* typography

to communicate meaning.

---

## 46. WIDGET-READY ARCHITECTURE

Do not implement a home-screen widget until the core application is stable.

However, structure projection data so a future WidgetKit extension could display:

```text
Projected Month End
$1,420

Safe to Spend
$82/day
```

Keep the calculation engine reusable outside SwiftUI views.

---

## 47. FUTURE FEATURES — DO NOT BUILD YET

Document but defer:

* iCloud sync
* bank synchronization
* Plaid
* credit card integrations
* receipt scanning
* OCR
* AI financial assistant
* shared household budgets
* Apple Watch
* WidgetKit
* Shortcuts/App Intents
* Siri
* subscription plans

Focus on the core experience first.

---

## 48. DEVELOPMENT PHASES

Follow this order.

### Phase 1 — Discovery

Inspect existing project.

Produce:

```text
PROJECT_ANALYSIS.md
```

Include:

* project structure
* deployment target
* architecture
* persistence
* existing functionality
* risks
* recommended plan

Do not modify core architecture until discovery is complete.

### Phase 2 — Architecture

Define:

* models
* persistence
* repositories
* selected month state
* projection engine
* navigation

Create/update:

```text
ARCHITECTURE.md
```

### Phase 3 — Projection Engine

Implement before polishing the dashboard.

Build:

```text
MonthlyProjectionEngine
```

Create strong tests.

This is the highest-priority business logic.

### Phase 4 — Persistence

Implement:

* transactions
* income sources
* recurring bills
* budgets
* savings goals

Verify CRUD behavior.

### Phase 5 — Dashboard

Build Home.

Make **Projected End of Month** the hero feature.

### Phase 6 — Transactions

Implement:

* list
* add
* edit
* delete
* filters

### Phase 7 — Plan

Implement:

* income
* bills
* budgets
* savings

Verify every Plan change updates projection.

### Phase 8 — Projection Breakdown

Implement detailed calculation explanation.

This is a required MVP feature.

### Phase 9 — Insights

Build lightweight useful insights.

### Phase 10 — Settings / Face ID

Implement preferences and privacy features.

### Phase 11 — QA

Run:

* unit tests
* UI tests where available
* build
* static/compiler checks
* accessibility review
* dark mode review

---

## 49. BUILD FREQUENTLY

After every meaningful implementation phase:

Build the app.

Do not wait until the entire project has been changed.

If using an Xcode project, determine the correct scheme first.

Use commands appropriate to the installed Xcode environment.

Examples may include:

```bash
xcodebuild -list
```

and then the appropriate simulator build.

Do not blindly copy a simulator/device name that may not exist.

Discover available destinations first.

---

## 50. FIX ERRORS BEFORE CONTINUING

Never knowingly stack new feature work on top of a broken build.

If a change introduces:

* compiler error
* test failure
* crash
* data migration problem

fix it before proceeding to the next major phase.

---

## 51. CODING STANDARDS

Use:

* clear Swift naming
* small focused types
* dependency injection where useful
* protocols where they provide real testability
* async/await where appropriate
* @MainActor correctly
* value types where suitable
* access control intentionally

Avoid:

* unnecessary singleton use
* global mutable state
* massive ViewModels
* 1,000-line SwiftUI files
* duplicate calculation logic
* force unwraps unless logically guaranteed
* silent error swallowing
* unnecessary abstractions

---

## 52. COMMENTS

Write comments for:

* non-obvious financial rules
* projection assumptions
* recurrence logic
* reconciliation logic
* architectural decisions

Do not comment obvious Swift syntax.

---

## 53. README

Maintain README.md.

Include:

* what FlowPlan does
* architecture
* required Xcode version
* minimum iOS version
* setup
* build instructions
* tests
* major features
* current limitations

---

## 54. PROJECT STATUS

Maintain:

```text
PROJECT_STATUS.md
```

Format:

```text
# FlowPlan Project Status

## Completed

- [x] Project architecture
- [x] Transaction model

## In Progress

- [ ] Projection engine

## Next

- [ ] Dashboard
- [ ] Transactions UI

## Known Issues

...

## Build Status

PASS / FAIL

## Test Status

XX passed
XX failed
```

Update this throughout development.

---

## 55. DECISION LOG

For significant architectural decisions maintain:

```text
DECISIONS.md
```

Examples:

```text
Why SwiftData was selected.

Why Decimal is used for currency.

How recurring bills are reconciled.

How projection treats planned variable spending.
```

This prevents agents from making conflicting architectural decisions.

---

## 56. GIT SAFETY

Before changing anything:

```bash
git status
```

Never discard existing uncommitted user changes.

Never run destructive git commands without clear necessity.

Do not use:

```bash
git reset --hard
```

unless explicitly instructed by the user.

Do not overwrite user-created design files.

Keep commits logically grouped if commits are being created.

Suggested commit categories:

```text
feat:
fix:
test:
refactor:
docs:
```

---

## 57. AGENT TASK EXAMPLE

Claude Lead can give Codex tasks like:

```text
TASK: Implement MonthlyProjectionEngine.

OWNED FILES:
- Domain/Calculations/MonthlyProjectionEngine.swift
- Domain/Models/MonthlyProjection.swift
- Tests/MonthlyProjectionEngineTests.swift

REQUIREMENTS:
- Decimal only for money
- No SwiftUI dependency
- No persistence dependency
- Handle remaining income
- Handle remaining bills
- Handle savings target
- Handle variable spending
- Prevent double counting
- Handle negative projection
- Handle zero remaining days

DELIVERABLE:
Implementation plus passing tests.

DO NOT:
- modify navigation
- modify persistence architecture
- redesign unrelated models
```

This is the preferred delegation style.

---

## 58. QA AGENT TASK EXAMPLE

Claude Lead can give Agent 3:

```text
Review the Projected End-of-Month implementation.

Focus on:

- mathematical correctness
- double counting
- month boundaries
- negative balances
- recurring bills
- savings calculations
- accessibility
- UI hierarchy
- Decimal correctness

Do not rewrite architecture.

Return:

1. critical issues
2. medium issues
3. minor issues
4. recommended tests
```

---

## 59. DO NOT MARK WORK COMPLETE BASED ONLY ON CODE REVIEW

A feature is complete only when:

* implementation exists
* project compiles
* relevant tests pass
* UI is connected
* state persists
* no obvious placeholders remain

---

## 60. MVP DEFINITION OF DONE

FlowPlan MVP is ready when the user can:

1. launch the app
2. select a month
3. add multiple income sources
4. add recurring bills
5. add expenses
6. create spending budgets
7. define a savings goal
8. see current financial status
9. see Projected End of Month
10. understand exactly how the projection was calculated
11. see Safe to Spend per Day
12. add/edit/delete transactions
13. see upcoming bills
14. review monthly insights
15. navigate previous months
16. protect the app with Face ID
17. close and reopen the app without losing data

---

## 61. MOST IMPORTANT ACCEPTANCE TEST

Imagine Alex starts August with this financial plan:

```text
Income
$8,500

Bills
$2,393

Planned Variable Spending
$2,500

Savings Goal
$2,000
```

The dashboard should make the resulting projected balance immediately understandable.

Then Alex adds:

```text
Unexpected Car Repair
-$600
```

Without requiring a refresh, the dashboard must recalculate the Projected End-of-Month balance and explain the $600 change.

Alex should be able to tap the projection and see exactly why the value changed.

This workflow represents the core value proposition of FlowPlan.

If this experience is not excellent, the application is not finished.

---

## 62. PRODUCT PRIORITY ORDER

When deciding what to spend engineering effort on, use this priority:

```text
1. Financial calculation correctness
2. Projected End-of-Month experience
3. Data integrity
4. Fast transaction entry
5. Monthly planning
6. UI clarity
7. Insights
8. Visual polish
9. Advanced features
```

Never sacrifice calculation correctness for visual polish.

---

## 63. FIRST ACTIONS

Begin now.

Do the following in order:

1. Run `git status`.
2. Inspect the entire project structure.
3. Identify the Xcode project/workspace and scheme.
4. Determine Swift and iOS deployment settings.
5. Inspect existing UI and data models.
6. Inspect any existing design assets/specifications.
7. Create `PROJECT_ANALYSIS.md`.
8. Create or update `ARCHITECTURE.md`.
9. Create `PROJECT_STATUS.md`.
10. Create `DECISIONS.md`.
11. Break implementation into agent-owned tasks.
12. Assign no more than 3 agents.
13. Make Codex the primary implementation agent for well-defined coding tasks.
14. Begin with the financial domain and `MonthlyProjectionEngine`.
15. Write tests.
16. Build.
17. Fix failures.
18. Continue with the Home dashboard.

Do not ask me to approve every implementation step.

Make reasonable engineering decisions and document them.

If there is ambiguity:

* inspect the existing code
* choose the simplest maintainable solution
* document the decision
* continue

Only stop for user input when a decision would fundamentally alter the product or destroy/replace existing user work.

---

## 64. FINAL ENGINEERING PRINCIPLE

Every major feature should ultimately support this question:

> "What will my financial situation look like at the end of this month?"

FlowPlan should not merely tell Alex what happened.

It should help Alex understand:

```text
Where am I now?
What still needs to happen?
What can I safely spend?
How much can I save?
Where will I end the month?
```

That is what differentiates FlowPlan from a basic expense tracker.

Build the application around that idea.

Begin by inspecting the repository.

---

## 65. ADDENDUM — PROJECTION ENGINE MUST BE PURE SWIFT

Owner recommendation. This is a hard constraint, not a preference.

Keep the projection engine as **pure Swift domain code with zero SwiftUI and zero database dependencies**.

Concretely:

* The engine imports `Foundation` only — no `SwiftUI`, no `SwiftData`, no `CoreData`, no `Observation`.
* It takes plain value-type inputs (a month, a set of income/bill/budget/savings/transaction values) and returns a `MonthlyProjection` value. It does not fetch, query, or save.
* No `@Model`, `@Observable`, `@Published`, `@State`, or persistence types appear anywhere in its inputs, outputs, or internals.
* Mapping from persisted models into the engine's input types happens in a separate adapter/repository layer, not inside the engine.

Why this matters:

* It gives Claude and Codex something very concrete to test — the engine is testable with plain values and no simulator, store, or view hosting.
* The exact same engine can later power the iPhone dashboard, a WidgetKit extension, Apple Watch, Shortcuts/App Intents, and the What-If simulator without rewriting the financial logic.
* It prevents the single most expensive category of bug in this product: duplicated or divergent calculation logic across surfaces.

Enforcement:

* If a projection calculation is ever needed in a view, a widget, or a simulator, it must call this engine. Do not reimplement it.
* Agent 3 (QA) should treat any SwiftUI or persistence import reaching into the projection engine as a critical issue.
