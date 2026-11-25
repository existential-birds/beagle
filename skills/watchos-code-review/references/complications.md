# watchOS Complications (Deltas)

For shared `TimelineProvider`, `AppIntentTimelineProvider`, refresh budget (~40–70/day), timeline gap avoidance, `placeholder(in:)`, `AsyncImage` restrictions, and `containerBackground(for: .widget)`, see `widgetkit-code-review` at [widgetkit-code-review](../../widgetkit-code-review/SKILL.md). This file covers **watchOS-specific** complication behaviors.

## Evolution

- **ClockKit**: Deprecated framework (watchOS 2–8)
- **WidgetKit**: Standard replacement (watchOS 9+)
- **watchOS 10**: Smart Stack with `TimelineEntryRelevance` prioritization
- **watchOS 11**: `RelevantContext` / `WidgetRelevance` for context-aware Smart Stack placement (date, location, sleep, workout)

## watchOS Widget Families

| Family | Use Case | ClockKit Equivalent |
|--------|----------|---------------------|
| `accessoryRectangular` | Multiple lines, graphs | `graphicRectangular` |
| `accessoryCircular` | Gauges, progress | `graphicCircular` variants |
| `accessoryInline` | Single text line | `utilitarianSmallFlat` |
| `accessoryCorner` | Icon + curved `.widgetLabel { }` (watchOS only) | `utilitarianSmall` |

```swift
// watchOS-only accessoryCorner layout with curved label
var body: some View {
    Image(systemName: "heart.fill")
        .widgetAccentable()
        .widgetLabel {
            Text("\(entry.bpm) BPM")
        }
}
```

## Smart Stack Relevance & `RelevantContext`

```swift
struct SimpleEntry: TimelineEntry {
    var date: Date
    var event: Event?

    var relevance: TimelineEntryRelevance? {
        guard let event else {
            return TimelineEntryRelevance(score: 0)
        }
        return TimelineEntryRelevance(
            score: 10,
            duration: event.endDate.timeIntervalSince(date)
        )
    }
}
```

On watchOS 11+, prefer `RelevanceConfiguration` / `RelevantContext` (e.g., `.date(from:to:)`, `.workout`, `.location`) via `WidgetRelevance` on `AppIntentTimelineProvider` when relevance depends on system context rather than static timeline scores alone.

## Always-On Display

```swift
struct ComplicationView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    let value: Int

    var body: some View {
        VStack {
            Image(systemName: "heart.fill")
                .widgetAccentable()

            if isLuminanceReduced {
                Text("\(value)")
                    .redacted(reason: .placeholder)  // Redact or simplify when wrist is lowered
            } else {
                Text("\(value) BPM")
                    .privacySensitive()
            }
        }
    }
}
```

## Key watchOS Complication Modifiers

| Modifier / View | Purpose |
|-----------------|---------|
| `.widgetAccentable()` | Mark elements for watch face tint/accent coloring |
| `.widgetLabel { }` | Curved text/gauge around `accessoryCorner` or `accessoryCircular` |
| `.privacySensitive()` | Redact private health/personal metrics in Always-On Display |
| `AccessoryWidgetBackground()` | Consistent translucent backdrop in `accessoryCircular`/`accessoryRectangular` |
| `.containerBackground(for: .widget)` | Smart Stack card background |

## ClockKit-to-WidgetKit Migration

Apps upgrading existing users from watchOS 8 or earlier ClockKit complications must implement `CLKComplicationWidgetMigrator` so existing watch face slots don't turn blank:

```swift
// BAD: User watch face complications become blank after update
final class ComplicationController: NSObject, CLKComplicationDataSource {
    // Missing: CLKComplicationWidgetMigrator conformance
}

// GOOD: Map legacy ClockKit descriptors to new WidgetKit kinds
extension ComplicationController: CLKComplicationWidgetMigrator {
    func widgetConfiguration(
        from descriptor: CLKComplicationDescriptor
    ) async -> CLKComplicationWidgetMigrationConfiguration? {
        CLKComplicationStaticWidgetMigrationConfiguration(
            kind: "MyWidget",
            extensionBundleIdentifier: "com.myapp.watchkitapp.widgets"
        )
    }
}
```

## Review Questions

1. Is WidgetKit used instead of deprecated ClockKit (watchOS 9+)?
2. For `accessoryCorner`, is `.widgetLabel { }` used appropriately for curved text?
3. Is `TimelineEntryRelevance` or watchOS 11 `RelevantContext` implemented for Smart Stack placement?
4. Are `.privacySensitive()` and `@Environment(\.isLuminanceReduced)` handled for Always-On Display?
5. Is `CLKComplicationWidgetMigrator` implemented when migrating legacy ClockKit apps?
6. Are shared WidgetKit rules (`placeholder()`, 5-min entry spacing, `containerBackground`, no `AsyncImage`) checked via `widgetkit-code-review` ([widgetkit-code-review](../../widgetkit-code-review/SKILL.md))?
