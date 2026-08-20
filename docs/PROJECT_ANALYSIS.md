# FlowPlan — Project Analysis (Phase 1, Discovery)

Date: 2026-08-19
Author: Claude Lead / Architect (Agent 1)

## 1. Starting state

The repository was **empty**. `/Volumes/Storage/Development/FlowPlan` contained no files,
no git repository, no Xcode project, no design assets, no README.

There was therefore **no existing work to preserve** and no existing architecture, persistence
choice, or deployment target to respect. Every decision below is greenfield.

`git init` was run and the master prompt was committed first, so all subsequent work is
revertable.

## 2. Environment discovered

| Item | Value |
|---|---|
| Xcode | 26.6 (build 17F113) |
| Swift | 6.3.3 (swiftlang-6.3.3.1.3) |
| macOS | Darwin 25.2.0 (arm64) |
| iOS runtimes installed | 26.2, 26.5 |
| Simulators | iPhone 17, 17 Pro, 17 Pro Max, 17e, Air, 16e, iPads |
| XcodeGen / Tuist | not installed |
| Codex CLI | present at `/opt/homebrew/bin/codex` |
| SwiftLint | not installed |

## 3. Consequences of that environment

- **SwiftData is available and safe.** The toolchain is far past the iOS 17 floor, so the
  persistence decision in the master prompt (§6) resolves to SwiftData, not Core Data.
- **No project generator is installed.** Rather than adding XcodeGen or Tuist as a build-time
  dependency, `project.pbxproj` is hand-written using Xcode 16+ **file-system-synchronized
  root groups**. Any file dropped into `FlowPlan/` or `FlowPlanTests/` is compiled
  automatically, so implementation agents never have to edit the project file — which removes
  the single most common source of merge conflicts in multi-agent iOS work.
- **The test loop can be fast.** Because the financial core lives in a local Swift package, it
  is exercised with `swift test` on the macOS host in a few seconds, with no simulator boot
  and no app host. Only UI-level tests need `xcodebuild test`.

## 4. Architecture established

See `ARCHITECTURE.md`. In summary:

```
Packages/FlowPlanDomain   pure Foundation. Models, recurrence, MonthlyProjectionEngine.
FlowPlan/Data             SwiftData @Model entities + repositories that map to domain values.
FlowPlan/Features         SwiftUI screens. Render state, dispatch intent, no arithmetic.
FlowPlan/Shared           components, formatting, extensions.
```

The domain package is the enforcement mechanism for the owner's hard constraint that the
projection engine stay pure: it is a separate module that never links SwiftUI or SwiftData,
so a violation is a compile error rather than a code-review opinion.

## 5. Risks

| Risk | Mitigation |
|---|---|
| Double counting between expected obligations and actual transactions — the highest-severity correctness risk in this product | Single reconciliation mechanism (`settlesBillID` / `settlesIncomeID`), a stated invariant that actuals are counted only in `currentAvailableBalance` and expectations only in the remaining-obligation terms, and a dedicated regression test suite |
| Hand-written `project.pbxproj` drifting or being corrupted by Xcode | Synchronized groups keep it small and static; it is committed and diffed like source |
| SwiftData + Swift 6 strict concurrency friction | App target pinned to Swift 5 language mode for velocity; the domain package is fully `Sendable` regardless, so a later migration is confined to the app layer |
| Decimal rounding in per-day figures | Safe-to-spend rounds **down** to 2 dp so the app never over-promises |
| Agents editing the same files | One owner per file group per task; specs list an explicit scope and a "do not touch" list |

## 6. Recommended plan

Phases follow the master prompt §48, with the projection engine first (Phase 3) because
every other screen consumes its output.

1. Scaffold + docs — done
2. Domain models + `MonthlyProjectionEngine` + tests — Codex, spec 01
3. SwiftData persistence, repositories, app state, seed data — Codex, spec 02
4. Home dashboard + projection breakdown + What-If — Codex, spec 03
5. Transactions + Plan screens — Codex, spec 04
6. Insights + Settings + Face ID — Codex, spec 05
7. QA pass, accessibility, dark mode, build and test verification — Agent 3
