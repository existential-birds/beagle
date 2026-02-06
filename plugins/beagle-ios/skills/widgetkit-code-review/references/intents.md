# Configurable Widgets

## Configuration Approaches

| Approach | iOS | Status |
|----------|-----|--------|
| `StaticConfiguration` | 14+ | Non-configurable widgets |
| `IntentConfiguration` | 14+ | Legacy SiriKit intents |
| `AppIntentConfiguration` | 17+ | Modern App Intents |

**Migration warning**: Changing from `IntentConfiguration` to `AppIntentConfiguration` can cause existing user widgets to disappear or freeze.

## AppIntentTimelineProvider

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

### EntityStringQuery for Custom Types

```swift
struct ItemEntity: AppEntity {
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

### DynamicOptionsProvider for Simple Types

```swift
@Parameter(title: "Hour", optionsProvider: HourOptionsProvider()) var hour: Int

struct HourOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [Int] { Array(0..<24) }
    func defaultResult() async -> Int? { 12 }
}
```

## Critical Anti-Patterns

### Missing defaultResult()
```swift
// BAD: Widget shows "Select" instead of value
struct ItemQuery: EntityStringQuery { /* no defaultResult() */ }

// GOOD: Always implement for non-optional entity parameters
func defaultResult() async -> ItemEntity? { items.first }
```

### Ignoring Nil After App Updates
```swift
// BAD: Parameters added in updates are nil for existing widgets
let name = config.newParameter.name  // Crash!

// GOOD: Handle optional parameters
let name = config.newParameter?.name ?? "Default"
```

### Heavy Work in Placeholder
```swift
// BAD: Blocks UI
func placeholder(in context: Context) -> Entry { Entry(data: fetchSync()) }

// GOOD: Return static data instantly
func placeholder(in context: Context) -> Entry { .placeholder }
```

### Breaking Migration
```swift
// BAD: Same kind causes widget disappearance
AppIntentConfiguration(kind: "widget", ...)  // Was IntentConfiguration

// GOOD: Use new kind for new configuration type
AppIntentConfiguration(kind: "widget.v2", ...)
```

## Review Questions

1. **Does EntityQuery implement `defaultResult()`?** Missing causes "Select" UI instead of default.
2. **Are new parameters optional-safe?** Parameters added in updates are nil for existing widgets.
3. **Is placeholder instant?** Must be synchronous with static data only.
4. **Does migration use new kind?** Same kind string breaks existing widgets.
5. **Is configuration stored in timeline entry?** Entry must hold intent for view access.
6. **Are AppEntity types Codable?** Required for WidgetKit to persist configuration.
