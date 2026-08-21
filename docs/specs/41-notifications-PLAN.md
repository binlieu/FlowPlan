# PLAN (not yet approved) — 41 — Local notifications

Settings has had a `Notifications` toggle since spec 07 that does nothing, with the footer
"Notification scheduling is not enabled in this version." This plan would make it real.

**Nothing here is built yet. Awaiting approval.**

## Constraints that shape the design
- **Local only.** No server, no push certificates, no account. Everything is
  `UNCalendarNotificationTrigger` scheduled on device, consistent with "your financial data is
  stored only on this device."
- **iOS allows 64 pending local notifications per app.** More than that and the system silently
  drops the rest, so the schedule must be budgeted rather than "one per occurrence forever".
- **The domain package stays pure.** Deciding *what* to notify and *when* is arithmetic over a
  month's plan, so it belongs in `FlowPlanDomain` as a pure function returning a list of requests.
  Only the delivery is app-layer.
- **The plan changes constantly.** Adding a bill, settling a payment, changing a due day or
  switching month all invalidate the schedule, so it must be rebuilt from scratch on every write
  rather than patched incrementally.

## Proposed architecture
```
FlowPlanDomain (pure)
  NotificationPlan.swift
    struct ScheduledNotification { id, fireDate, kind, values }   // no formatted strings
    func notifications(for: MonthlyProjection, ...) -> [ScheduledNotification]

FlowPlan (app)
  NotificationScheduler.swift        // protocol, so tests use a fake — as BiometricAuthenticating does
  SystemNotificationScheduler.swift  // UNUserNotificationCenter behind that protocol
  NotificationCoordinator.swift      // permission, rebuild-on-write, 64-request budget, copy
```
Copy is built in the app layer, matching the spec 31 decision that the domain must not format
currency. `ScheduledNotification` carries values, not sentences.

## Proposed notification types
| Kind | When | Why |
|---|---|---|
| Bill due tomorrow | 18:00 the day before | The one people actually want |
| Bill or debt overdue | 18:00 the day after | Catches a missed manual payment |
| Income expected today | 09:00 on the day | Prompts marking it received |
| Projection turned negative | on the day it flips | The product's core warning |
| Month rolled over | 09:00 on the 1st | Prompts setting the new month up |

**Auto-pay items would be excluded** from due/overdue reminders when "Record auto-pay
automatically" is on — the app already records those, so a reminder is noise about something
handled.

## The decision I need from you: what appears on the lock screen
A notification body is visible to anyone holding the phone, even locked. Three options:

- **Amount-free** — "Electric is due tomorrow." Nothing financial leaks.
- **With amounts** — "Electric ($89.99) is due tomorrow." More useful, but your bills and balances
  become readable over your shoulder.
- **A setting**, defaulting to amount-free.

This one is genuinely a values question rather than a technical one, and it interacts with the
Face ID lock: an app that hides its numbers behind biometrics but announces them on the lock
screen is inconsistent.

## Testing
- `NotificationPlan` is pure, so it unit-tests directly: right count, right dates, no duplicates,
  respects the 64 cap, excludes auto-pay when the preference is on, empty when the toggle is off.
- `NotificationCoordinator` tests use a fake scheduler and assert what was requested and
  cancelled, never touching the real notification centre.
- Permission-denied and permission-revoked paths must be covered — the toggle has to reflect the
  system state, not just the stored preference.

## What I would not do
- No "you overspent" or "you're behind" nagging. The insights rule from the master prompt is
  factual and non-judgemental; notifications are more intrusive, so the bar should be higher.
- No daily summary. It becomes noise and gets the app's notifications switched off entirely.

## Rough size
Three specs: the pure plan and its tests; the scheduler, coordinator and permission handling;
then Settings wiring plus the real-device verification. Notifications cannot be verified in the
simulator the way I have been checking layout — the delivery path needs your phone, and I would
want to confirm one real notification arrives before calling it done.

## Open questions
1. Lock-screen content — amount-free, with amounts, or a setting?
2. Are all five notification types wanted, or a subset?
3. Fixed times (18:00 / 09:00) or configurable?
