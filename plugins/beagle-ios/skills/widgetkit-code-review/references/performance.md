# Widget Performance

## Budget System

Widgets operate under strict refresh budgets to conserve battery:

- **Daily budget**: 40-70 refreshes for frequently viewed widgets
- **Refresh interval**: Every 15-60 minutes in production
- **Debug mode**: No limits during development

### Timeline Policies

```swift
Timeline(entries: entries, policy: .atEnd)       // Refresh when timeline exhausted
Timeline(entries: entries, policy: .after(date)) // Refresh after specific date
Timeline(entries: entries, policy: .never)       // Manual refresh via reloadTimelines()
```

Populate timelines with as many future entries as possible. Keep entries at least 5 minutes apart.

## Memory Limits

Widgets are constrained to approximately **30MB** - this applies collectively across all timeline entries.

```swift
// BAD: Loading full-resolution images
let image = UIImage(contentsOfFile: path)

// GOOD: Downsample to widget display size
func downsample(imageAt url: URL, to size: CGSize, scale: CGFloat) -> UIImage? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
    let maxDim = max(size.width, size.height) * scale
    let downsampleOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDim
    ] as CFDictionary
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
    return UIImage(cgImage: cg)
}
```

## Data Fetching

Network calls must complete within timeline generation. Never call APIs in `getSnapshot()`:

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    Task {
        guard let data = try? await fetchData() else {
            completion(Timeline(entries: [Entry(date: Date(), data: cachedData)], policy: .after(Date().addingTimeInterval(900))))
            return
        }
        completion(Timeline(entries: [Entry(date: Date(), data: data)], policy: .after(Date().addingTimeInterval(3600))))
    }
}

func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(context.isPreview ? .sample : Entry(date: Date(), data: cachedData ?? .sample))
}
```

For background downloads, use `onBackgroundURLSessionEvents` modifier on the widget configuration.

## Caching Strategies

### App Groups for Shared Data

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.widgets")

// Main app: save and notify widget
func saveWidgetData(_ data: WidgetData) {
    if let encoded = try? JSONEncoder().encode(data) {
        sharedDefaults?.set(encoded, forKey: "widgetData")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// Widget: read cached data
func loadWidgetData() -> WidgetData? {
    guard let data = sharedDefaults?.data(forKey: "widgetData") else { return nil }
    return try? JSONDecoder().decode(WidgetData.self, from: data)
}
```

Both app and widget extension must have the same App Group in Signing & Capabilities.

## Critical Anti-Patterns

### AsyncImage Not Supported

```swift
// BAD: Widgets render synchronously
AsyncImage(url: imageURL)

// GOOD: Pre-fetch in timeline provider
Image(uiImage: cachedImage)
```

### Excessive Reloads

```swift
// BAD: Burns budget quickly
WidgetCenter.shared.reloadAllTimelines()

// GOOD: Reload specific widget strategically
WidgetCenter.shared.reloadTimelines(ofKind: "specificWidget")
```

### UIKit Components

```swift
// BAD: UIViewRepresentable not supported
MapViewRepresentable()

// GOOD: Use MKMapSnapshotter for map images
Image(uiImage: mapSnapshot)
```

### Keychain Access

Keychain can fail with `errSecInteractionNotAllowed` after extended periods. Use App Groups instead.

### Sparse Timelines

```swift
// BAD: Forces frequent refreshes
Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))

// GOOD: Pre-computed entries
let entries = (0..<24).map { Entry(date: Date().addingTimeInterval(Double($0) * 3600), data: data) }
Timeline(entries: entries, policy: .atEnd)
```

## Review Questions

1. Does the widget downsample images to display size, or load full-resolution assets?
2. Are timeline entries pre-computed for future dates to minimize refresh frequency?
3. Does `getSnapshot()` avoid network calls and use cached/sample data?
4. Is App Groups configured correctly for both app and widget extension targets?
5. Are `reloadTimelines()` calls strategic, or does every data update trigger a reload?
6. Does the widget view avoid AsyncImage and other async loading patterns?
