# Widget Views

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

- Use `@Environment(\.widgetRenderingMode)` to detect Lock Screen vibrant mode
- `AccessoryWidgetBackground()` works for `accessoryCircular`/`accessoryRectangular` only
- Use `ViewThatFits` for content that may truncate

## containerBackground

**Required for iOS 17+.** Widgets show error without this modifier.

```swift
Text("Content")
    .containerBackground(for: .widget) { Color.blue }
```

**Backwards compatibility:**
```swift
extension View {
    func widgetBackground(_ bg: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) { bg }
        } else { return background(bg) }
    }
}
```

**Configuration modifiers:**
- `.containerBackgroundRemovable(false)` - Prevent removal in StandBy
- `.contentMarginsDisabled()` - Opt out of automatic margins

## Deep Linking

| Size | Method | Notes |
|------|--------|-------|
| `systemSmall` | `widgetURL()` | Entire widget is one tap target |
| `systemMedium`/`Large` | `Link` or `widgetURL()` | Multiple tappable regions |

```swift
// Small widgets: entire widget taps
.widgetURL(URL(string: "myapp://item/\(entry.id)")!)

// Medium/Large: multiple targets
Link(destination: URL(string: "myapp://section1")!) { Text("Section 1") }
```

Handle in app with `.onOpenURL { url in handleDeepLink(url) }`

## Critical Anti-Patterns

| Issue | Problem |
|-------|---------|
| Missing `containerBackground` | iOS 17 shows error instead of widget |
| `Link` in `systemSmall` | Silently fails, only `widgetURL` works |
| `Button` in widgets | Never works, use `Link` or `widgetURL` |
| Same view for all families | Content truncated or wasted space |
| `AccessoryWidgetBackground` in `accessoryInline` | Renders empty view |
| No URL validation in `onOpenURL` | Security risk from malformed deep links |

## Review Questions

1. Does the widget use `containerBackground(for:)` for iOS 17+ compatibility?
2. Are Lock Screen families handled with appropriate compact layouts?
3. Is `widgetURL` used for `systemSmall` instead of `Link`?
4. Does the code avoid `Button` views (never work in widgets)?
5. Is `AccessoryWidgetBackground` excluded from `accessoryInline` contexts?
6. Are deep link URLs validated before navigation?
