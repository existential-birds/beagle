# HealthKit Background Delivery

## Overview

Background delivery allows apps to receive HealthKit updates without user launching the app. Requires:

1. **`enableBackgroundDelivery(for:frequency:)`** - Register for notifications
2. **`HKObserverQuery`** - Long-running query that monitors changes

## Required Configuration

### Entitlements (iOS 15+/Xcode 13+)

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Capabilities

- HealthKit > Background Delivery
- Background Modes > Background Processing

## Update Frequencies

| Frequency | Behavior | Reality |
|-----------|----------|---------|
| `.immediate` | Wake on every change | Some types enforce hourly max (stepCount) |
| `.hourly` | At most once per hour | iOS may defer based on battery/CPU |
| `.daily` | At most once per day | Advisory, not guaranteed |
| `.weekly` | At most once per week | Advisory, not guaranteed |

**iOS has full discretion** to defer based on CPU, battery, connectivity, Low Power Mode.

## Background Execution Constraints

- **Time limit**: ~15 seconds for simple queries
- **3 strikes rule**: After 3 failed completions, delivery stops
- **watchOS budget**: 4 updates/hour (shared with WKApplicationRefreshBackgroundTask)

## Required Setup Pattern

```swift
// AppDelegate.swift - MUST be in didFinishLaunchingWithOptions
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [...]) -> Bool {
    setupHealthKitBackgroundDelivery()
    return true
}

func setupHealthKitBackgroundDelivery() {
    let stepType = HKQuantityType(.stepCount)

    // 1. Create observer query
    let query = HKObserverQuery(sampleType: stepType, predicate: nil) {
        query, completionHandler, error in
        defer { completionHandler() }  // MUST always call

        guard error == nil else { return }
        self.fetchNewData()  // Keep minimal - 15 sec limit
    }

    // 2. Execute query
    healthStore.execute(query)

    // 3. Enable background delivery
    healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
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
        guard !hasRegistered else { return }  // Won't work after app update!
        hasRegistered = true
        // ...
    }
}

// GOOD: Always register in didFinishLaunchingWithOptions
// Registration must happen every app launch
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

// GOOD: Store as property
class HealthManager {
    private var observerQueries: [HKObserverQuery] = []

    func setupObserver() {
        let query = HKObserverQuery(...)
        observerQueries.append(query)  // Keep reference
        healthStore.execute(query)
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

// GOOD: Use HKAnchoredObjectQuery to get actual changes
func fetchChanges(completion: @escaping () -> Void) {
    let query = HKAnchoredObjectQuery(type: type, anchor: savedAnchor, ...) {
        query, samples, deleted, newAnchor, error in
        defer { completion() }

        guard let samples = samples, let newAnchor = newAnchor else { return }
        self.anchor = newAnchor  // Persist

        // Only process actual new samples
        self.process(samples: samples, deleted: deleted ?? [])
    }
    healthStore.execute(query)
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

// GOOD: Minimal work, schedule full sync for later
let query = HKObserverQuery(...) { query, completionHandler, error in
    defer { completionHandler() }  // Complete quickly

    // Just fetch latest
    self.fetchLatestSample { sample in
        self.pendingSamples.append(sample)

        // Schedule full sync when app is active
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                self.performFullSync()
            }
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

1. Is `enableBackgroundDelivery` called in `application(_:didFinishLaunchingWithOptions:)`?
2. Are all required entitlements configured (especially iOS 15+)?
3. Are observer queries stored as instance properties?
4. Is `completionHandler()` called in ALL code paths?
5. Is work in the observer callback minimal (~15 seconds)?
6. Does code handle that callbacks may fire without actual data changes?
7. Are anchors persisted to track processed data?
8. Is the update frequency appropriate for the data type?
