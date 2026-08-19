# Codex task spec — 08 — QA / UI / Review pass (Agent 3)

## Role
You are the **QA and review agent**, not the implementer. Your job is to find defects and report
them precisely. You do **not** redesign the architecture and you do **not** rewrite subsystems.

## Scope
**Read the whole repository. Modify nothing except** `docs/QA_REPORT.md`, which you create.

If you find a defect that is a genuine one-line fix and is unambiguously correct (a typo in user
copy, a missing accessibility label, a wrong SF Symbol name), you may fix it — and you must list
it under "Fixes applied" in the report. Anything larger is reported, not fixed.

## What to examine

### Mathematical correctness — highest priority
- Walk `MonthlyProjectionEngine` line by line against the rules in
  `docs/specs/01-domain-projection-engine.md` and `docs/ARCHITECTURE.md` §4.
- Hunt for **double counting**: can any financial event reach both `currentAvailableBalance` and
  a remaining-obligation term? Check settled bills, settled income, savings transactions,
  transfers, and a transaction linked to a bill that no longer exists.
- Check the occurrence-settling logic when there are more transactions than occurrences, and
  fewer.
- Check `Decimal` use end to end. Any `Double`/`Float` in a money path is a critical issue.
- Check month boundaries: 28/29/30/31-day months, the first and last day, a past month, a future
  month, and a monthly rule anchored on the 29th, 30th and 31st.
- Check every division for a zero denominator.
- Confirm a negative projection is never clamped.

### Data integrity
- Can a repository write leave the store and the projection disagreeing?
- Is `markBillPaid` the only path that settles a bill? Can a user create the same settlement twice?
- Does deleting a bill or income source orphan transactions that link to it, and is that handled?
- Is anything financial written to `UserDefaults` or to a log?

### SwiftUI structure
- Arithmetic inside a `body`, or an engine call inside a `body`.
- Duplicated calculation logic between views (the projection must be computed in exactly one place).
- Massive view files, unsafe state handling, force unwraps, silently swallowed errors.
- `@State` that should be `@Binding`, retained view models, or state that resets unexpectedly.

### UI and accessibility
- Dark mode on every screen; any hard-coded colour.
- Dynamic Type at the largest accessibility sizes — truncation, overlap, fixed heights.
- VoiceOver: money values must have spoken labels; charts must have descriptors; the hero card
  must read as one meaningful element.
- State communicated by colour alone anywhere.
- Touch targets under 44×44.
- Empty states: are they present, accurate, and do they say something useful?
- iPhone SE (small) through iPhone 17 Pro Max (large) layout behaviour.

### Copy
- Financial messaging must be factual, never judgemental. Flag any wording that shames the user.
- Numbers in copy must come from the engine, never be hardcoded example values left behind.

### Performance
- Expensive work in a `body`, repeated fetches per row, unbounded list rendering, work that
  should be `LazyVStack`.

## Deliverable — `docs/QA_REPORT.md`

```markdown
# LieuFlow QA Report — <date>

## Summary
<3–5 sentences: overall health, and whether the MVP acceptance test in master-prompt §61 holds>

## 1. Critical issues
<defects that produce a wrong number, lose data, or crash. For each: file:line, what is wrong,
the concrete input that triggers it, and the expected vs actual result.>

## 2. Medium issues
## 3. Minor issues
## 4. Fixes applied
## 5. Recommended tests
<specific test cases that do not exist yet, as names plus the scenario they would cover>
```

Every issue must be **specific and reproducible** — `file:line`, a concrete input, and the
expected versus actual value. "Consider improving error handling" is not a finding. If you cannot
name the input that breaks it, it belongs in Minor or not at all.

Rank by severity, most severe first. If you find nothing critical, say so plainly rather than
inflating a minor issue.

## Done when
- [ ] `docs/QA_REPORT.md` exists and every issue names a file, a line and a trigger
- [ ] no source file has been modified except for the one-line fixes listed in section 4
