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
| Connection | `URLSession` abstracts Bluetooth/Wi-Fi/cellular routing |
| WebSockets vs Low-Level Sockets | `URLSessionWebSocketTask` **is** supported on watchOS 6+ for active foreground use; low-level `NWConnection` / `URLSessionStreamTask` sockets are restricted (Apple TN3135) |
| Background minimum interval | 10+ minutes recommended |

## Critical Anti-Patterns

### 1. Nested `TabView`s (Memory Leak)

```swift
// BAD: Causes memory leaks on watchOS
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
// BAD: Fails when wrist is locked
func backgroundHandler() {
    let data = try? Data(contentsOf: protectedFileURL)  // Fails!
}

// GOOD: Use no file protection for background-accessible data
try data.write(to: url, options: .noFileProtection)
```

### 4. Constant UI Updates During Workout / Always-On

```swift
// BAD: Updates every second even when wrist is lowered
struct WorkoutView: View {
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(heartRate)")
            .onReceive(timer) { _ in updateUI() }
    }
}

// GOOD: Adaptive update rate with isLuminanceReduced
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

### 5. Loading Unbounded Datasets Upfront

```swift
// BAD: Load everything into watch memory
func loadRecords() async -> [Record] {
    await database.fetchAll()
}

// GOOD: Load only what's displayed
func loadRecords(limit: Int = 10) async -> [Record] {
    await database.fetch(limit: limit)
}
```

## Battery Optimization

### Extended Runtime Sessions

```swift
// Always invalidate promptly when activity completes
@MainActor
final class MindfulnessManager {
    private var session: WKExtendedRuntimeSession?
    private var endTask: Task<Void, Never>?

    func startSession(duration: TimeInterval) {
        session = WKExtendedRuntimeSession()
        session?.start()

        endTask?.cancel()
        endTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            session?.invalidate()
            session = nil
        }
    }
}
```

### Image Optimization

```swift
// Downsample large images to watch display size before rendering in SwiftUI
func downsampleImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
}
```

### HealthKit Queries

```swift
// Store and stop long-running queries
final class HealthManager {
    private let healthStore = HKHealthStore()
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
3. Are files using `.noFileProtection` if accessed while the watch is locked in background?
4. Is UI update frequency reduced when `isLuminanceReduced` is true?
5. Is `WKExtendedRuntimeSession` invalidated promptly when activity completes?
6. Are images downsampled to watch display size?
7. Are long-running HealthKit queries stored and stopped in `deinit`?
8. Is any low-level socket (`NWConnection`/`URLSessionStreamTask`) misused where `URLSession` or `URLSessionWebSocketTask` is required?
