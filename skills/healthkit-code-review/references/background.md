# HealthKit Background Delivery

## Overview

Background delivery allows apps to receive HealthKit updates without the user launching the app. Requires:

1. **`enableBackgroundDelivery(for:frequency:)`** — Register for notifications
2. **`HKObserverQuery`** — Long-running query that monitors changes

## Required Configuration

### Entitlements (iOS 15+ / Xcode 13+)

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Capabilities

- HealthKit > Background Delivery
- Background Modes > Background Processing (if scheduling additional background processing)

## Update Frequencies

| Frequency | Behavior | Reality |
|-----------|----------|---------|
| `.immediate` | Wake on every change | Some types enforce hourly max (`stepCount`) |
| `.hourly` | At most once per hour | iOS may defer based on battery/CPU |
| `.daily` | At most once per day | Advisory, not guaranteed |
| `.weekly` | At most once per week | Advisory, not guaranteed |

**iOS has full discretion** to defer based on CPU, battery, connectivity, Low Power Mode.

## Background Execution Constraints

- **Time limit**: ~15 seconds for simple queries
- **3 strikes rule**: After 3 failed completions, delivery stops
- **watchOS budget**: 4 updates/hour (shared with `WKApplicationRefreshBackgroundTask`)

## Required Setup Pattern

Background delivery and observer queries must be registered **on every app launch**:
- **UIKit**: `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)`
- **SwiftUI (iOS)**: `App.init()` or `@UIApplicationDelegateAdaptor(AppDelegate.self)` inside `application(_:didFinishLaunchingWithOptions:)`
- **watchOS (SwiftUI)**: `WKApplicationDelegate` via `@WKApplicationDelegateAdaptor` (`applicationDidFinishLaunching()`) or `App.init()`

```swift
// SwiftUI App entry point with UIApplicationDelegateAdaptor
@main
struct HealthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let healthManager = HealthManager.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        healthManager.setupHealthKitBackgroundDelivery()
        return true
    }
}

// watchOS SwiftUI App entry point
// @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
// func applicationDidFinishLaunching() { healthManager.setupHealthKitBackgroundDelivery() }
```

```swift
func setupHealthKitBackgroundDelivery() {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    let stepType = HKQuantityType(.stepCount)

    // 1. Create and retain observer query
    let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
        defer { completionHandler() }  // MUST always call

        guard error == nil, let self else { return }
        Task {
            await self.fetchNewData()  // Keep minimal - ~15 sec limit
        }
    }
    observerQueries.append(query)

    // 2. Execute query
    healthStore.execute(query)

    // 3. Enable background delivery
    Task {
        try? await healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate)
    }
}
```

## Critical Anti-Patterns

### 1. Not Calling completionHandler

```swift
// BAD: completionHandler not called on error path
let query = HKObserverQuery(...) { query, completionHandler, error in
    if let error = error {
        print("Error: \(error)")
        return  // completionHandler not called!
    }
    self.fetchData()
    completionHandler()
}

// GOOD: Use defer to ensure it's always called
let query = HKObserverQuery(...) { query, completionHandler, error in
    defer { completionHandler() }  // Always called

    guard error == nil else {
        print("Error: \(error!)")
        return
    }
    self.fetchData()
}
```

### 2. Not Re-registering on App Launch

```swift
// BAD: Registering only once
class HealthManager {
    private var hasRegistered = false
    func setupBackgroundDelivery() {
        guard !hasRegistered else { return }  // Won't work after app restart/update!
        hasRegistered = true
        // ...
    }
}

// GOOD: Register every app launch (AppDelegate / @UIApplicationDelegateAdaptor / WKApplicationDelegate / App.init)
func application(_ app: UIApplication, didFinishLaunchingWithOptions: [...]) -> Bool {
    healthManager.setupBackgroundDelivery()  // Called every launch
    return true
}
```

### 3. Local Variable Query Gets Deallocated

```swift
// BAD: Query goes out of scope
func setupObserver() {
    let query = HKObserverQuery(...)
    healthStore.execute(query)
}  // query deallocated!

// GOOD: Store as property and stop when torn down
final class HealthManager {
    private var observerQueries: [HKObserverQuery] = []

    func setupObserver() {
        let query = HKObserverQuery(...)
        observerQueries.append(query)  // Keep reference
        healthStore.execute(query)
    }

    deinit {
        observerQueries.forEach { healthStore.stop($0) }
    }
}
```

### 4. Assuming Callback Means New Data

```swift
// BAD: Callback fires even without data changes
let query = HKObserverQuery(...) { query, completionHandler, error in
    defer { completionHandler() }
    self.processNewData()  // May process nothing - called on foreground too
}

// GOOD: Use HKAnchoredObjectQueryDescriptor to get actual changes
func fetchChanges() async throws {
    let descriptor = HKAnchoredObjectQueryDescriptor(
        predicates: [.quantitySample(type: stepType)],
        anchor: savedAnchor
    )
    let result = try await descriptor.result(for: healthStore)
    saveAnchor(result.newAnchor)
    await process(samples: result.addedSamples, deleted: result.deletedObjects)
}
```

### 5. Long-Running Work in Background Handler

```swift
// BAD: May exceed 15-second time limit
let query = HKObserverQuery(...) { query, completionHandler, error in
    self.downloadFromServer()
    self.processAllHistoricalData()
    self.syncToCloudKit()
    completionHandler()
}

// GOOD: Minimal work, defer full sync to active foreground state
let query = HKObserverQuery(...) { [weak self] _, completionHandler, error in
    defer { completionHandler() }
    guard error == nil, let self else { return }

    Task { @MainActor [weak self] in
        guard let self else { return }
        await self.fetchLatestSample()
        if UIApplication.shared.applicationState == .active {
            await self.performFullSync()
        }
    }
}
```

### 6. Missing Required Entitlement

```xml
<!-- BAD: Missing background delivery entitlement -->
<key>com.apple.developer.healthkit</key>
<true/>

<!-- GOOD: All required entitlements -->
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

## Review Questions

1. Is `enableBackgroundDelivery` + `HKObserverQuery` registered on every launch (`App.init()`, `@UIApplicationDelegateAdaptor`, `WKApplicationDelegate`, or `AppDelegate`)?
2. Are all required entitlements configured (especially `com.apple.developer.healthkit.background-delivery` for iOS 15+)?
3. Are observer queries stored as instance properties and stopped on teardown?
4. Is `completionHandler()` called in ALL code paths (`defer`)?
5. Is work in the observer callback minimal (~15 seconds)?
6. Does code handle that callbacks may fire without actual data changes?
7. Are `HKQueryAnchor`s persisted separately per sample type?
8. Is UI/state mutation isolated on `@MainActor`?
