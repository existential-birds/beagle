# Timeline Management

## Core Concepts

WidgetKit renders widgets as static snapshots at predetermined times. The system controls refresh timing to optimize battery life, allowing 40-70 refreshes per day (every 15-60 minutes). Timeline entries should be at least 5 minutes apart. The system may delay refreshes significantly beyond requested times.

## TimelineProvider Protocol

Three required methods with distinct purposes:

| Method | Sync/Async | Purpose |
|--------|-----------|---------|
| `placeholder(in:)` | Synchronous | Redacted loading state; return immediately |
| `getSnapshot(in:completion:)` | Async | Widget gallery preview; check `context.isPreview` |
| `getTimeline(in:completion:)` | Async | Primary content; returns entries array + reload policy |

```swift
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, data: .placeholder)  // Must be instant
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
        completion(Entry(date: .now, data: context.isPreview ? .sample : .current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = (0..<12).map { hour in
            Entry(date: Calendar.current.date(byAdding: .hour, value: hour, to: .now)!, data: .forHour(hour))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
```

## TimelineEntry

Requires only `date` property. Add custom properties for widget data:

```swift
struct MyEntry: TimelineEntry {
    let date: Date                          // Required: when to display
    let relevance: TimelineEntryRelevance?  // Optional: Smart Stack ranking
    let title: String                       // Custom data
}
```

## Reload Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `.atEnd` | Request new timeline after last entry expires | Regularly changing content |
| `.after(Date)` | Wait until specified date | Known future update time |
| `.never` | No auto-refresh; requires `reloadTimelines` call | App-driven updates only |

All policies are suggestions. System decides actual timing based on budget and battery.

## App-Driven Reloads

```swift
WidgetCenter.shared.reloadTimelines(ofKind: "MyWidget")  // Specific widget
WidgetCenter.shared.reloadAllTimelines()                  // All widgets
```

Limitations: Not immediate; may only update when app backgrounds; subject to daily budget.

## Critical Anti-Patterns

```swift
// BAD: Entries too close together
for minute in 0..<60 {
    let date = Calendar.current.date(byAdding: .minute, value: minute, to: now)!
    entries.append(Entry(date: date))
}

// GOOD: Reasonable intervals (5+ minutes minimum)
for hour in 0..<24 {
    let date = Calendar.current.date(byAdding: .hour, value: hour, to: now)!
    entries.append(Entry(date: date))
}
```

```swift
// BAD: Heavy work in synchronous placeholder
func placeholder(in context: Context) -> Entry {
    let data = fetchDataSync()  // Blocks UI, may timeout
    return Entry(date: .now, data: data)
}
```

```swift
// BAD: Ignoring isPreview
func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
    fetchRealData { completion(Entry(date: .now, data: $0)) }  // Slow for gallery
}

// GOOD: Sample data for previews, real data otherwise
func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
    if context.isPreview {
        completion(Entry(date: .now, data: .sample))
    } else {
        completion(Entry(date: .now, data: .current))
    }
}
```

```swift
// BAD: Expecting exact refresh timing
Timeline(entries: entries, policy: .after(exactDeadline))  // May refresh hours late

// GOOD: Include fallback entries past critical times
```

## Review Questions

1. **Does `placeholder(in:)` return immediately without async work?**
2. **Are timeline entries spaced at least 5 minutes apart?**
3. **Does `getSnapshot` check `context.isPreview` for gallery previews?**
4. **Is the reload policy appropriate?** Static: `.never`; Dynamic: `.atEnd`/`.after`
5. **Are there fallback entries past critical times?** System may delay refreshes.
6. **Is `reloadTimelines` called only when necessary?** Each call consumes budget.
