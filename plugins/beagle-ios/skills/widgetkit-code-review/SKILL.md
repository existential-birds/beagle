---
name: widgetkit-code-review
description: Reviews WidgetKit code for timeline management, view composition, configurable intents, and performance. Use when reviewing code with import WidgetKit, TimelineProvider, Widget protocol, or @main struct Widget.
---

# WidgetKit Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| TimelineProvider, entries, reload policies | [references/timeline.md](references/timeline.md) |
| Widget families, containerBackground, deep linking | [references/views.md](references/views.md) |
| AppIntentConfiguration, EntityQuery, @Parameter | [references/intents.md](references/intents.md) |
| Refresh budget, memory limits, caching | [references/performance.md](references/performance.md) |

## Review Checklist

- [ ] `placeholder(in:)` returns immediately without async work
- [ ] Timeline entries spaced at least 5 minutes apart
- [ ] `getSnapshot` checks `context.isPreview` for gallery previews
- [ ] `containerBackground(for:)` used for iOS 17+ compatibility
- [ ] `widgetURL` used for systemSmall (not Link)
- [ ] No Button views (use Link or widgetURL)
- [ ] No AsyncImage or UIViewRepresentable in widget views
- [ ] Images downsampled to widget display size (~30MB limit)
- [ ] App Groups configured for data sharing between app and widget
- [ ] EntityQuery implements `defaultResult()` for non-optional parameters
- [ ] New intent parameters handle nil for existing widgets after updates
- [ ] `reloadTimelines` called strategically (not on every data change)

## When to Load References

- TimelineProvider implementation or refresh issues -> timeline.md
- Widget sizes, Lock Screen, containerBackground -> views.md
- Configurable widgets, AppIntent migration -> intents.md
- Memory issues, caching, budget management -> performance.md

## Review Questions

1. Does the widget provide fallback entries for when system delays refresh?
2. Are Lock Screen families (accessoryCircular/Rectangular/Inline) handled appropriately?
3. Would migrating from IntentConfiguration break existing user widgets?
4. Is timeline populated with future entries or does it rely on frequent refreshes?
5. Is data cached via App Groups for widget access?

## Hard gates (before reporting)

Load `beagle-core:review-verification-protocol` plus the [Swift / iOS delta](../ios-verification-protocol/SKILL.md) **once, at review entry** — not once per finding. Reporting a finding is `beagle-core:verification-budget` tier REVERSIBLE: cite the evidence you already have and move on. Only a verdict that authorizes an irreversible action (deleting code, rewriting a file) earns that protocol's full evidence gate.

The three gates below are per-finding and cheap. Apply them in order. Budget: max **1** pass per finding; stop when each gate has a recorded artifact; tie-break: drop the finding or downgrade it to an open question and proceed — never re-run the gates hoping for a cleaner answer.

1. **Location artifact** — The finding includes `[FILE:LINE]` (or a line range) copied from the current file contents; the path resolves in this repo.
2. **Scope read** — You read the full surrounding implementation: the `TimelineProvider` (including `placeholder`, `getSnapshot`, and `getTimeline` when relevant), the `@main` `Widget` / widget bundle, or the configurable widget’s `AppIntentConfiguration` / intent types—not only a diff hunk or snippet.
3. **Platform or system claim** (only if the finding depends on refresh budget, ~30MB memory guidance, Lock Screen accessory families, iOS 17+ `containerBackground`, App Groups data sharing, or migration from `IntentConfiguration` to `AppIntentConfiguration`) — You name one concrete artifact you inspected (for example `.entitlements` / App Group id in project, `WidgetFamily` handling in source, `IPHONEOS_DEPLOYMENT_TARGET`, or the exact reference subsection you used) **or** you drop or downgrade the finding to an open question.

Use the issue format `[FILE:LINE] ISSUE_TITLE` for each reported finding.
