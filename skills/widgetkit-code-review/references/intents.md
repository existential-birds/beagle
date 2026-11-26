# Configurable Widgets

## Configuration Approaches

| Approach | iOS | Status |
|----------|-----|--------|
| `StaticConfiguration` | 14+ | Non-configurable widgets |
| `IntentConfiguration` | 14+ | Legacy SiriKit intents |
| `AppIntentConfiguration` | 17+ | Modern App Intents |
| `StaticControlConfiguration` / `AppIntentControlConfiguration` | 18+ | `ControlWidget` (Control Center / Lock Screen / Action Button) |

**Migration warning**: Changing from `IntentConfiguration` to `AppIntentConfiguration` with the same `kind` string can cause existing user widgets to disappear or freeze.

## `AppIntentTimelineProvider`

```swift
struct ConfigurableProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MyEntry { .placeholder }  // Sync, instant

    func snapshot(for config: MyIntent, in context: Context) async -> MyEntry {
        MyEntry(date: .now, item: config.selectedItem)
    }

    func timeline(for config: MyIntent, in context: Context) async -> Timeline<MyEntry> {
        let entry = MyEntry(date: .now, item: config.selectedItem)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900)))
    }
}
```

## Widget Configuration

```swift
struct MyWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Widget"

    @Parameter(title: "Name", default: "Default") var name: String
    @Parameter(title: "Style") var style: DisplayStyle  // AppEnum
    @Parameter(title: "Item") var selectedItem: ItemEntity?  // AppEntity
}

struct MyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.app.widget", intent: MyWidgetIntent.self,
                               provider: ConfigurableProvider()) { entry in
            MyWidgetView(entry: entry)
        }
    }
}
```

## Dynamic Options

### `EntityStringQuery` for Custom Types (`AppEntity`)

`AppEntity` requires `Identifiable` (`id`), `static var typeDisplayRepresentation`, `var displayRepresentation`, `static var defaultQuery`, and `Sendable` under Swift 6 (`Codable` is **not** required).

```swift
struct ItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Item"
    static var defaultQuery = ItemQuery()

    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ItemQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ItemEntity] { /* fetch by IDs */ }
    func entities(matching string: String) async throws -> [ItemEntity] { /* search */ }
    func suggestedEntities() async throws -> [ItemEntity] { /* default list */ }
    func defaultResult() async -> ItemEntity? { /* REQUIRED for non-optional params */ }
}
```

### `DynamicOptionsProvider` for Simple Types

```swift
@Parameter(title: "Hour", optionsProvider: HourOptionsProvider()) var hour: Int

struct HourOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [Int] { Array(0..<24) }
    func defaultResult() async -> Int? { 12 }
}
```

## Critical Anti-Patterns

### Missing `defaultResult()`

```swift
// BAD: Widget shows "Select" instead of default value
struct ItemQuery: EntityStringQuery { /* no defaultResult() */ }

// GOOD: Always implement for non-optional entity parameters
func defaultResult() async -> ItemEntity? { items.first }
```

### Ignoring `nil` After App Updates

```swift
// BAD: Parameters added in updates are nil for existing widgets
let name = config.newParameter.name  // Crash if force-unwrapped!

// GOOD: Handle optional parameters safely
let name = config.newParameter?.name ?? "Default"
```

### Heavy Work in `placeholder(in:)`

```swift
// BAD: Blocks UI
func placeholder(in context: Context) -> Entry { Entry(data: fetchSync()) }

// GOOD: Return static data instantly
func placeholder(in context: Context) -> Entry { .placeholder }
```

### Breaking Migration

```swift
// BAD: Same kind causes widget disappearance when switching configuration type
AppIntentConfiguration(kind: "widget", ...)  // Was IntentConfiguration

// GOOD: Use new kind for new configuration type
AppIntentConfiguration(kind: "widget.v2", ...)
```

## Review Questions

1. **Does `EntityQuery` implement `defaultResult()`?** Missing causes "Select" UI instead of default.
2. **Does every `AppEntity` define `typeDisplayRepresentation`, `displayRepresentation`, and `defaultQuery`?**
3. **Are new parameters optional-safe?** Parameters added in updates are `nil` for existing widgets.
4. **Is `placeholder(in:)` instant?** Must be synchronous with static data only.
5. **Does `IntentConfiguration` -> `AppIntentConfiguration` migration use a new `kind`?** Same `kind` breaks existing widgets.
6. **Is configuration stored in the timeline entry?** Entry must hold intent data for view access.
