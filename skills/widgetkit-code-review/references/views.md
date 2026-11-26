# Widget Views & Controls

## Widget Families

**Home Screen:** `systemSmall`, `systemMedium`, `systemLarge`, `systemExtraLarge` (iPad only)

**Lock Screen (iOS 16+):** `accessoryCircular`, `accessoryRectangular`, `accessoryInline`

```swift
.supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
```

## View Composition

Use `@Environment(\.widgetFamily)` for adaptive layouts:

```swift
@Environment(\.widgetFamily) var widgetFamily

var body: some View {
    switch widgetFamily {
    case .systemSmall: CompactView()
    case .accessoryCircular: CircularWidgetView()
    case .accessoryInline: Text(entry.summary)
    default: DetailedView()
    }
}
```

- Use `@Environment(\.widgetRenderingMode)` to detect Lock Screen vibrant / tinted mode
- `AccessoryWidgetBackground()` works for `accessoryCircular`/`accessoryRectangular` only
- Use `ViewThatFits` for content that may truncate

## `containerBackground`

**Required for iOS 17+.** Widgets show a blank/error placeholder without this modifier.

```swift
Text("Content")
    .containerBackground(for: .widget) { Color.blue }
```

**Backwards compatibility:**
```swift
extension View {
    @ViewBuilder
    func widgetBackground(_ bg: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { bg }
        } else {
            background(bg)
        }
    }
}
```

**Configuration modifiers:**
- `.containerBackgroundRemovable(false)` — Prevent removal in StandBy
- `.contentMarginsDisabled()` — Opt out of automatic margins

## Interactive Widgets (iOS 17+) vs Deep Linking

Since iOS 17+, widgets support **interactive `Button(intent:)` and `Toggle(isOn:intent:)`** backed by `AppIntent` (running in-process or extension without launching the main app). Closure-based `Button(action: {})` still does **not** work in widgets.

```swift
// GOOD (iOS 17+): AppIntent-backed interactive controls
Button(intent: CompleteTaskIntent(taskID: entry.taskID)) {
    Label("Complete", systemImage: "checkmark.circle")
}

Toggle(isOn: entry.isTimerRunning, intent: ToggleTimerIntent()) {
    Text("Timer")
}

// BAD: Closure-based Button does nothing in widgets
Button(action: { completeTask() }) {
    Text("Complete")
}
```

For navigation into the app:

| Size | Method | Notes |
|------|--------|-------|
| `systemSmall` | `widgetURL()` | Entire widget is one tap target (unless using `Button(intent:)` / `Toggle(isOn:intent:)`) |
| `systemMedium`/`Large` | `Link` or `widgetURL()` | Multiple tappable navigation regions |

Handle deep links in the app with `.onOpenURL { url in handleDeepLink(url) }` and validate incoming URLs.

## `ControlWidget` (iOS 18+)

iOS 18 introduced `ControlWidget` for Control Center, Lock Screen quick actions, and the Action Button using `ControlWidgetButton` (with `AppIntent`) and `ControlWidgetToggle` (with `SetValueIntent` + `ControlValueProvider`):

```swift
struct TimerControl: ControlWidget {
    static let kind = "com.example.app.TimerControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: TimerValueProvider()) { isRunning in
            ControlWidgetToggle("Timer", isOn: isRunning, action: ToggleTimerIntent()) { active in
                Label(active ? "Running" : "Stopped", systemImage: "timer")
            }
        }
        .displayName("Timer")
    }
}
```

- Use `StaticControlConfiguration` for fixed controls, `AppIntentControlConfiguration` with `AppIntentControlValueProvider` for user-configurable controls.
- Keep `ControlValueProvider.previewValue` synchronous and `currentValue()` fast.

## Critical Anti-Patterns

| Issue | Problem |
|-------|---------|
| Missing `containerBackground` | iOS 17+ shows error instead of widget |
| `Link` in `systemSmall` | Silently fails, only `widgetURL` works |
| Closure-based `Button(action:)` in widgets | Does not execute; use `Button(intent:)` / `Toggle(isOn:intent:)` (iOS 17+) or `Link` / `widgetURL` |
| Same view for all families | Content truncated or wasted space |
| `AccessoryWidgetBackground` in `accessoryInline` | Renders empty view |
| No URL validation in `onOpenURL` | Security risk from malformed deep links |

## Review Questions

1. Does the widget use `containerBackground(for:)` for iOS 17+ compatibility?
2. Are Lock Screen families handled with appropriate compact layouts?
3. Is `widgetURL` used for `systemSmall` navigation instead of `Link`?
4. Do interactive controls use `Button(intent:)` / `Toggle(isOn:intent:)` (never closure-based `Button(action:)`)?
5. For iOS 18+ `ControlWidget`, are `ControlWidgetButton`/`ControlWidgetToggle` paired with `AppIntent`/`SetValueIntent` and fast `ControlValueProvider` implementations?
6. Is `AccessoryWidgetBackground` excluded from `accessoryInline` contexts?
7. Are deep link URLs validated before navigation?
