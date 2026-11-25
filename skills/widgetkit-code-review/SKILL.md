---
name: widgetkit-code-review
description: "Reviews WidgetKit code for timeline management, view composition, interactive widgets/ControlWidgets, configurable intents, and performance. Use when reviewing code with import WidgetKit, TimelineProvider, ControlWidget, Widget protocol, or @main struct Widget."
---

# WidgetKit Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| `TimelineProvider`, entries, reload policies, `RelevantContext` | [references/timeline.md](references/timeline.md) |
| Widget families, `containerBackground`, `Button(intent:)`, `ControlWidget` | [references/views.md](references/views.md) |
| `AppIntentConfiguration`, `EntityQuery`, `AppEntity`, `@Parameter` | [references/intents.md](references/intents.md) |
| Refresh budget, memory limits (~30MB), caching, App Groups | [references/performance.md](references/performance.md) |

## Review Checklist

- [ ] `placeholder(in:)` returns immediately without async work
- [ ] Timeline entries spaced at least 5 minutes apart
- [ ] `getSnapshot` checks `context.isPreview` for gallery previews
- [ ] `containerBackground(for:)` used for iOS 17+ compatibility
- [ ] `widgetURL` used for `systemSmall` (not `Link`)
- [ ] Interactive widget controls use `Button(intent:)` or `Toggle(isOn:intent:)` (iOS 17+); no closure-based `Button(action:)`
- [ ] iOS 18+ `ControlWidget` uses `ControlWidgetButton` / `ControlWidgetToggle` backed by `AppIntent` / `SetValueIntent` and `ControlValueProvider`
- [ ] Smart Stack widgets use `TimelineEntryRelevance` or `RelevantContext` (`WidgetRelevance`) where context matters
- [ ] No `AsyncImage` or `UIViewRepresentable` in widget views
- [ ] Images downsampled to widget display size (~30MB collective limit)
- [ ] App Groups configured for data sharing between app and widget
- [ ] `EntityQuery` implements `defaultResult()` for non-optional parameters; `AppEntity` includes `typeDisplayRepresentation`
- [ ] New intent parameters handle `nil` for existing widgets after updates; `IntentConfiguration` -> `AppIntentConfiguration` migration uses a new `kind`
- [ ] `reloadTimelines` called strategically (not on every data change)

## When to Load References

- `TimelineProvider` implementation, `RelevantContext`, or refresh issues -> [references/timeline.md](references/timeline.md)
- Widget sizes, Lock Screen, `containerBackground`, `Button(intent:)`, or `ControlWidget` -> [references/views.md](references/views.md)
- Configurable widgets, `AppEntity`, or `AppIntent` migration -> [references/intents.md](references/intents.md)
- Memory issues, caching, or budget management -> [references/performance.md](references/performance.md)

## Review Questions

1. Does the widget provide fallback entries for when the system delays refresh?
2. Are Lock Screen families (`accessoryCircular`/`Rectangular`/`Inline`) and `ControlWidget` surfaces handled appropriately?
3. Would migrating from `IntentConfiguration` to `AppIntentConfiguration` break existing user widgets?
4. Do interactive controls use `Button(intent:)` / `Toggle(isOn:intent:)` rather than closure-based `Button(action:)`?
5. Is data cached via App Groups for widget access?

## Hard gates (before reporting)

Complete **in order** for each finding you intend to report. Do not advance until the pass condition is satisfied.

1. **Location artifact** — The finding includes `[FILE:LINE]` (or a line range) copied from the current file contents; the path resolves in this repo.
2. **Scope read** — You read the full surrounding implementation: the `TimelineProvider` (including `placeholder`, `getSnapshot`, and `getTimeline` when relevant), the `@main` `Widget` / `ControlWidget` / widget bundle, or the configurable widget’s `AppIntentConfiguration` / intent types—not only a diff hunk or snippet.
3. **Platform or system claim** (only if the finding depends on refresh budget, ~30MB memory guidance, Lock Screen accessory families, iOS 17+ `containerBackground` / `Button(intent:)`, iOS 18+ `ControlWidget`, App Groups data sharing, or migration from `IntentConfiguration` to `AppIntentConfiguration`) — You name one concrete artifact you inspected (for example `.entitlements` / App Group id in project, `WidgetFamily` handling in source, `IPHONEOS_DEPLOYMENT_TARGET`, or the exact reference subsection you used) **or** you drop or downgrade the finding to an open question.
4. **Protocol** — Pre-report steps in `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) are satisfied for this item (no finding if they are not).

Use the issue format `[FILE:LINE] ISSUE_TITLE` for each reported finding. Hard gate 4 is the full pre-report checklist for this skill’s review type.
