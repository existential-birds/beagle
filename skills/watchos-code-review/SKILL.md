---
name: watchos-code-review
description: "Reviews watchOS code for app lifecycle, complications (ClockKit/WidgetKit), WatchConnectivity, and performance constraints. Use when reviewing code with import WatchKit, WKExtension, WKApplicationDelegate, WCSession, or watchOS-specific patterns."
---

# watchOS Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| App lifecycle, scenes, background modes, extended runtime | [references/lifecycle.md](references/lifecycle.md) |
| watchOS WidgetKit deltas, Smart Stack, Always-On, ClockKit migration | [references/complications.md](references/complications.md) |
| `WCSession`, message passing, file transfer, reachability | [references/connectivity.md](references/connectivity.md) |
| Memory limits, background refresh, battery optimization | [references/performance.md](references/performance.md) |

For shared WidgetKit `TimelineProvider` / `AppIntentTimelineProvider`, refresh budget, and `containerBackground` rules in watchOS complications, also consult `widgetkit-code-review` at [widgetkit-code-review](../widgetkit-code-review/SKILL.md).

## Review Checklist

- [ ] SwiftUI `App` protocol used with `@WKApplicationDelegateAdaptor` for lifecycle events
- [ ] `scenePhase` read from root view (not sheets/modals where it always reports `.active`)
- [ ] `WKExtendedRuntimeSession` started only while app is active (not from background)
- [ ] Workout sessions recovered in `applicationDidFinishLaunching` via `recoverActiveWorkoutSession()` (`HKWorkoutSession?` + `session.associatedWorkoutBuilder()`)
- [ ] `WKApplicationRefreshBackgroundTask` scheduled at least 5 minutes apart; next scheduled before completing current
- [ ] `URLSessionDownloadTask` (not `DataTask`) used for background network requests
- [ ] WidgetKit used instead of deprecated ClockKit for watchOS 9+ complications (with `CLKComplicationWidgetMigrator` when migrating legacy apps)
- [ ] `TimelineEntryRelevance` / `RelevantContext` (watchOS 11+) used for Smart Stack prioritization
- [ ] `isLuminanceReduced` and `.privacySensitive()` respected for Always-On Display
- [ ] `WCSession` delegate set before `activate()`; singleton initialized early
- [ ] `isReachable` checked before `sendMessage`; `transferUserInfo` used for guaranteed delivery
- [ ] Received files moved synchronously before `WCSessionDelegate` callback returns

## When to Load References

- Reviewing app lifecycle, background modes, workouts, or extended sessions -> [references/lifecycle.md](references/lifecycle.md)
- Reviewing watchOS complications, Smart Stack relevance, or Always-On Display -> [references/complications.md](references/complications.md)
- Reviewing `WCSession` iPhone-Watch communication -> [references/connectivity.md](references/connectivity.md)
- Reviewing memory, battery, networking, or watchOS performance -> [references/performance.md](references/performance.md)

## Output Format

Report issues using: `[FILE:LINE] ISSUE_TITLE`

Examples:

- `[WatchApp.swift:18] WKExtendedRuntimeSession started while app not active`
- `[ConnectivityManager.swift:42] WCSession.activate() before delegate assignment`
- `[ComplicationTimeline.swift:67] Timeline has no future entries`

## Hard gates (before reporting)

Complete **in order** for each finding you intend to report. Do not advance until the pass condition is satisfied.

1. **Location artifact** — The finding includes `[FILE:LINE]` (or a line range) copied from the current file contents; the path resolves in this repo.
2. **Scope read** — You read the full surrounding unit: the `View` body, `WKApplicationDelegate` / scene method, `TimelineProvider` implementation, `WCSessionDelegate` callback, or workout/background task handler that owns the behavior—not only a diff hunk.
3. **watchOS or pairing claim** (only if the finding depends on background modes, complication/timeline contracts, `WCSession` reachability or transfer semantics, workout or extended runtime rules, or device-specific limits) — You name one concrete artifact you inspected (for example `Info.plist` / target capabilities for background modes, the `WK*` / `WCSession` call order in source, entitlements, or a subsection you read in the matching doc from [Quick Reference](#quick-reference)) **or** you downgrade the item to an open question in [Review Questions](#review-questions).
4. **Protocol** — Pre-report steps in `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) are satisfied for this item (no finding if they are not).

Use the issue format `[FILE:LINE] ISSUE_TITLE` for each reported finding. Hard gate 4 is the full pre-report checklist for this skill’s review type.

## Review Questions

1. Is the app using modern SwiftUI lifecycle with `@WKApplicationDelegateAdaptor`?
2. Are `WKRefreshBackgroundTask` tasks completing properly with `setTaskCompletedWithSnapshot`?
3. Is UI update frequency reduced when `isLuminanceReduced` is true?
4. Are `WCSessionDelegate` callbacks updating UI state on `@MainActor`?
5. Is `TabView` nested within another `TabView`? (Memory leak on watchOS)
