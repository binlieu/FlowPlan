# Codex task spec — 29 — Settings cleanup: remove iCloud, simplify auto-lock

Three owner-requested changes. The version bump is already done in the project file; do not touch
`FlowPlan.xcodeproj`.

## 1. Remove the iCloud sync row
`DataSettingsView` shows a disabled "iCloud sync" row labelled as coming soon. The feature does
not exist and there is no committed plan to build it. Remove the row entirely rather than showing
a control that does nothing.

Keep iCloud in `docs/PROJECT_STATUS.md` under deferred work — removing the UI is not the same as
abandoning the idea.

## 2. Auto-lock: 1 minute and 5 minutes only, defaulting to 1 minute
`AutoLockInterval` currently has `immediately`, `oneMinute`, `fiveMinutes`, `never`.

**Remove `immediately` and `never`.** The owner's reasoning: turning Face ID off already means
"never lock", so `never` is a second control for the same thing, and `immediately` locks on every
brief interruption. The remaining cases are `oneMinute` and `fiveMinutes`, defaulting to
`oneMinute`.

**Migrate stored values.** `autoLockInterval` is persisted via `@AppStorage` as a raw string. An
install holding `"immediately"` or `"never"` must not decode to nil or crash — map both to
`oneMinute` on read. Add a test for each removed raw value.

**Remove the `immediately` branch in `BiometricGate.appDidEnterBackground()`**, which locked
instantly when that case was selected. With the shortest interval now a minute, locking is always
decided by elapsed time in `appDidBecomeActive()`. Confirm the existing biometric tests still pass
and update any that referenced the removed cases.

Keep the picker disabled while Face ID is off, as it already is — the relationship between the two
controls should stay visible rather than the picker disappearing.

## 3. Version
Already bumped to `1.1` in the project file. `SettingsView`'s About section reads it from
`CFBundleShortVersionString`, so no code change should be needed — **verify** that it displays
`1.1` rather than a hardcoded value, and fix it if it is hardcoded anywhere.

## Scope
- `FlowPlan/Features/Settings/DataSettingsView.swift`
- `FlowPlan/Features/Settings/SettingsView.swift`
- `FlowPlan/App/BiometricAuthenticator.swift`
- `FlowPlanTests/`
- `docs/PROJECT_STATUS.md`

Do NOT touch `Packages/FlowPlanDomain/**` or `FlowPlan.xcodeproj`. All 106 domain tests must pass
unchanged.

## Tests
- a stored `autoLockInterval` of `"immediately"` reads back as `oneMinute`
- a stored value of `"never"` reads back as `oneMinute`
- an unset preference defaults to `oneMinute`
- `AutoLockInterval.allCases` contains exactly two cases
- backgrounding for less than the interval does not lock; longer than it does
- the biometric gate still locks and unlocks correctly with the reduced case set

## Done when
- [ ] no iCloud row appears in Settings
- [ ] the auto-lock picker offers exactly "1 minute" and "5 minutes"
- [ ] About shows version 1.1
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
