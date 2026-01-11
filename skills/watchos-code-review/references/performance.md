# watchOS Performance

## Constraints

### Memory

| Constraint | Limit |
|------------|-------|
| Device RAM | ~1 GB (Series 9/10/Ultra 2) |
| App bundle | ~50 MB |
| Widget/Complication images | ~30 MB |
| Background task memory | Limited |

### CPU and Battery

| Constraint | Limit |
|------------|-------|
| CPU usage threshold | <80% sustained |
| Background task duration | ~3 min when backgrounding; ~30s when resumed |
| Background refresh | 4 per hour with complication; 15+ min apart |
| Extended runtime | Battery-intensive; end promptly |

### Network

| Consideration | Details |
|---------------|---------|
| Connection | URLSession abstracts Bluetooth/Wi-Fi/cellular |
| WebSocket/Stream | Not supported |
| Background minimum interval | 10+ minutes recommended |

## Critical Anti-Patterns

### 1. Nested TabViews (Memory Leak)

```swift
// BAD: Causes memory leaks
NavigationStack {
    TabView {
        TabView {  // DON'T NEST!
            ContentView()
        }
    }
}

// GOOD: Single level
NavigationStack {
    TabView {
        ContentView()
    }
}
```

### 2. Not Completing Background Tasks

```swift
// BAD: Missing completion handler
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
            doWork()
            // MISSING: setTaskCompletedWithSnapshot!
        }
    }
}

// GOOD: Always complete with defer
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
            defer { refreshTask.setTaskCompletedWithSnapshot(false) }
            doWork()
        }
    }
}
```

### 3. Protected File Access in Background

```swift
// BAD: Fails when screen locked
func backgroundHandler() {
    let data = try? Data(contentsOf: protectedFileURL)  // Fails!
}

// GOOD: Use no file protection for background data
try data.write(to: url, options: .noFileProtection)
```

### 4. WKInterface Property Updates

```swift
// BAD: Each property = ~200ms message
func updateUI() {
    label.setText(newText)      // Update 1
    label.setTextColor(.red)    // Update 2
    image.setImage(newImage)    // Update 3
}

// GOOD: Only set when values change
func updateUI() {
    if textChanged {
        label.setText(newText)
    }
    if colorChanged {
        label.setTextColor(.red)
    }
}
```

### 5. Constant UI Updates During Workout

```swift
// BAD: Updates even when dimmed
struct WorkoutView: View {
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(heartRate)")
            .onReceive(timer) { _ in updateUI() }
    }
}

// GOOD: Adaptive update rate
struct WorkoutView: View {
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        TimelineView(.periodic(from: .now, by: updateInterval)) { _ in
            Text("\(heartRate)")
        }
    }

    var updateInterval: TimeInterval {
        isLuminanceReduced ? 10.0 : 1.0  // Slower when dimmed
    }
}
```

### 6. Large WKInterfaceTable

```swift
// BAD: All cells load upfront (no reuse)
func loadTable(items: [Item]) {
    table.setNumberOfRows(items.count, withRowType: "Row")  // 100+ rows = bad
}

// GOOD: Keep under 20 rows, use incremental updates
func loadTable(items: [Item]) {
    let limitedItems = Array(items.prefix(20))
    table.setNumberOfRows(limitedItems.count, withRowType: "Row")
}

func addRows(at indexes: IndexSet) {
    table.insertRows(at: indexes, withRowType: "Row")  // Incremental
}
```

### 7. Loading All Data

```swift
// BAD: Load everything
func loadRecords() async -> [Record] {
    return await database.fetchAll()
}

// GOOD: Load what's displayed
func loadRecords(limit: Int = 10) async -> [Record] {
    return await database.fetch(limit: limit)
}
```

## Battery Optimization

### Extended Runtime Sessions

```swift
// Always end when activity completes
class MindfulnessManager {
    var session: WKExtendedRuntimeSession?

    func startSession(duration: TimeInterval) {
        session = WKExtendedRuntimeSession()
        session?.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.session?.invalidate()
            self?.session = nil
        }
    }
}
```

### Image Optimization

```swift
// Downsample to display size
func displayImage(_ image: UIImage, targetSize: CGSize) {
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let downsampledImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    imageView.setImage(downsampledImage)
}
```

### HealthKit Queries

```swift
// Store and stop long-running queries
class HealthManager {
    var observerQuery: HKObserverQuery?

    deinit {
        if let query = observerQuery {
            healthStore.stop(query)
        }
    }
}
```

## Review Questions

1. Is `TabView` nested within another `TabView`? (Memory leak)
2. Are all `WKRefreshBackgroundTask` completion handlers called?
3. Are files using `.noFileProtection` if accessed in background?
4. Is UI update frequency reduced when `isLuminanceReduced` is true?
5. Is `WKExtendedRuntimeSession` invalidated when activity completes?
6. Are WKInterface properties only set when values change?
7. Are WKInterfaceTables kept under 20 rows?
8. Are images downsampled to display size?
9. Are long-running queries stored and stopped in `deinit`?
