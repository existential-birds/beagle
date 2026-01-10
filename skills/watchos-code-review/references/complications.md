# watchOS Complications

## Evolution

- **ClockKit**: Deprecated framework (watchOS 2-8)
- **WidgetKit**: Modern replacement (watchOS 9+)
- **watchOS 10**: Smart Stack with relevance-based prioritization
- **watchOS 11**: `RelevantContext` API for context-aware widgets

## Widget Families (WidgetKit)

| Family | Use Case | ClockKit Equivalent |
|--------|----------|---------------------|
| `accessoryRectangular` | Multiple lines, graphs | `graphicRectangular` |
| `accessoryCircular` | Gauges, progress | `graphicCircular` variants |
| `accessoryInline` | Single text line | `utilitarianSmallFlat` |
| `accessoryCorner` | Icon + curved label (watchOS only) | `utilitarianSmall` |

## Timeline Provider Types

### Static Widget

```swift
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ())
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ())
}
```

### Configurable Widget (AppIntents)

```swift
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry
    func snapshot(for configuration: ConfigIntent, in context: Context) async -> SimpleEntry
    func timeline(for configuration: ConfigIntent, in context: Context) async -> Timeline<SimpleEntry>
    func recommendations() -> [AppIntentRecommendation<ConfigIntent>]
}
```

## Smart Stack Relevance

```swift
struct SimpleEntry: TimelineEntry {
    var date: Date
    var event: Event?

    var relevance: TimelineEntryRelevance? {
        guard let event = event else {
            return TimelineEntryRelevance(score: 0)
        }
        return TimelineEntryRelevance(
            score: 10,
            duration: event.endDate.timeIntervalSince(date)
        )
    }
}
```

## Critical Anti-Patterns

### 1. Exceeding Refresh Budget

```swift
// BAD: Called on every data change
func dataDidUpdate() {
    WidgetCenter.shared.reloadTimelines(ofKind: "MyWidget")
}

// GOOD: Throttle reloads, use timeline entries
func getTimeline(...) {
    var entries: [Entry] = []
    for hourOffset in 0..<24 {
        let date = Calendar.current.date(byAdding: .hour, value: hourOffset, to: Date())!
        entries.append(Entry(date: date, data: predictedData(for: date)))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
}
```

**Budget**: ~40-70 refreshes/day (~every 15-60 minutes)

### 2. Gaps in Timeline

```swift
// BAD: Only entries for events
func getTimeline(...) {
    for event in events {
        entries.append(Entry(date: event.startDate, event: event))
    }
}

// GOOD: Entries for state changes
func getTimeline(...) {
    entries.append(Entry(date: Date(), event: currentEvent))
    for event in upcomingEvents {
        entries.append(Entry(date: event.startDate, event: event))
        entries.append(Entry(date: event.endDate, event: nil))  // End state
    }
}
```

### 3. Expensive Operations in Placeholder

```swift
// BAD: Blocks UI
func placeholder(in context: Context) -> Entry {
    let data = fetchLatestData()  // Network call!
    return Entry(date: Date(), data: data)
}

// GOOD: Return static data immediately
func placeholder(in context: Context) -> Entry {
    return Entry(date: Date(), data: .placeholder)
}
```

### 4. AsyncImage in Widget

```swift
// BAD: Won't work
var body: some View {
    AsyncImage(url: imageURL)  // Widgets can't do async in view
}

// GOOD: Fetch in timeline provider
func getTimeline(...) {
    let imageData = try? Data(contentsOf: imageURL)
    let entry = Entry(date: Date(), imageData: imageData)
    completion(Timeline(entries: [entry], policy: .atEnd))
}
```

### 5. Not Implementing Migration

```swift
// BAD: User complications become blank
class ComplicationController: NSObject, CLKComplicationDataSource {
    // Missing: var widgetMigrator: CLKComplicationWidgetMigrator
}

// GOOD: Implement migration
extension ComplicationController: CLKComplicationWidgetMigrator {
    func widgetConfiguration(
        from descriptor: CLKComplicationDescriptor
    ) async -> CLKComplicationWidgetMigrationConfiguration? {
        return CLKComplicationStaticWidgetMigrationConfiguration(
            kind: "MyWidget",
            extensionBundleIdentifier: "com.myapp.widget"
        )
    }
}
```

## Key Modifiers

| Modifier | Purpose |
|----------|---------|
| `.widgetAccentable()` | Mark for accent coloring |
| `.widgetLabel { }` | Curved text for corner/circular |
| `.containerBackground(for: .widget)` | Smart Stack background |
| `.privacySensitive()` | Redact in Always-On |
| `AccessoryWidgetBackground()` | Consistent backdrop |

## Always-On Display

```swift
var body: some View {
    VStack {
        Image(systemName: "heart.fill")
            .widgetAccentable()

        if isLuminanceReduced {
            Text("\(value)")
                .redacted(reason: .placeholder)  // Hide sensitive
        } else {
            Text("\(value) BPM")
                .privacySensitive()
        }
    }
}
```

## Review Questions

1. Is WidgetKit used instead of ClockKit (watchOS 9+)?
2. Does `placeholder()` return immediately without async work?
3. Does the timeline include future entries (not just current)?
4. Is `TimelineEntryRelevance` implemented for Smart Stack?
5. Is `.privacySensitive()` applied to sensitive content?
6. Is `@Environment(\.isLuminanceReduced)` checked for Always-On?
7. Are images pre-fetched (not using AsyncImage)?
8. Is ClockKit migration implemented if updating from older app?
