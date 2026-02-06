# HealthKit Authorization

## Authorization Model

HealthKit uses **per-data-type, separate read/write authorization**. Users grant access individually for each health data type.

### Required Setup

1. **Entitlement**: `com.apple.developer.healthkit` capability
2. **Info.plist Keys**:
   - `NSHealthShareUsageDescription` - Why app needs to **read** health data
   - `NSHealthUpdateUsageDescription` - Why app needs to **write** health data

### HKAuthorizationStatus (Write Only)

| Status | Meaning |
|--------|---------|
| `.notDetermined` | User hasn't been asked yet |
| `.sharingAuthorized` | User granted write access |
| `.sharingDenied` | User explicitly denied write access |

**Critical**: Read permission status is intentionally hidden for privacy.

### Key Methods

| Method | Purpose |
|--------|---------|
| `isHealthDataAvailable()` | Check device support (not on iPad pre-iPadOS 17) |
| `authorizationStatus(for:)` | Check **write** permission only |
| `getRequestStatusForAuthorization(toShare:read:)` | Check if auth sheet would appear |
| `requestAuthorization(toShare:read:)` | Request permissions from user |

## Critical Anti-Patterns

### 1. Misinterpreting requestAuthorization Success

```swift
// BAD: success does NOT mean permission granted
healthStore.requestAuthorization(toShare: types, read: types) { success, error in
    if success {
        self.startRecordingWorkout()  // May fail if permission denied!
    }
}

// GOOD: success means dialog flow completed
healthStore.requestAuthorization(toShare: types, read: types) { success, error in
    if success {
        // Check specific type for write operations
        if self.healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized {
            self.startRecordingWorkout()
        }
    }
}
```

### 2. Checking Read Permission Status

```swift
// BAD: Cannot determine read permission status
let status = healthStore.authorizationStatus(for: heartRateType)
if status == .sharingAuthorized {  // This only checks WRITE status!
    displayHeartRateData()
}

// GOOD: Just attempt to fetch - empty results if denied
func fetchHeartRateData() async {
    let results = try? await healthStore.execute(query)
    // Handle empty results gracefully
}
```

### 3. Not Checking Device Availability

```swift
// BAD: HealthKit not available on iPad (pre-iPadOS 17)
func requestHealthKitAccess() {
    healthStore.requestAuthorization(toShare: types, read: types) { _, _ in }
}

// GOOD: Always check availability first
func requestHealthKitAccess() {
    guard HKHealthStore.isHealthDataAvailable() else {
        showHealthKitNotAvailableMessage()
        return
    }
    healthStore.requestAuthorization(toShare: types, read: types) { _, _ in }
}
```

### 4. Widgets Requesting Authorization

```swift
// BAD: Widgets cannot present authorization UI
struct HealthWidget: Widget {
    func getTimeline(...) {
        healthStore.requestAuthorization(...)  // Will silently fail
    }
}

// GOOD: Use getRequestStatusForAuthorization in widgets
struct HealthWidget: Widget {
    func getTimeline(...) {
        let status = try? await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
        if status == .shouldRequest {
            showOpenAppPrompt()
        } else {
            displayHealthData()  // May be empty if denied
        }
    }
}
```

### 5. Accessing Data Before Authorization Completes

```swift
// BAD: Race condition (HKError code 5)
func initialize() {
    healthStore.requestAuthorization(toShare: types, read: types) { _, _ in }
    fetchHealthData()  // Called before authorization completes!
}

// GOOD: Wait for authorization
func initialize() async {
    do {
        try await healthStore.requestAuthorization(toShare: types, read: types)
        await fetchHealthData()
    } catch {
        handleAuthorizationError(error)
    }
}
```

## HKError Codes

| Code | Constant | Meaning |
|------|----------|---------|
| - | `.errorAuthorizationDenied` | User denied permission |
| - | `.errorAuthorizationNotDetermined` | App hasn't requested yet |
| 4 | - | Missing HealthKit entitlement |
| 5 | - | Transaction failed (often premature data access) |

## Review Questions

1. Is `isHealthDataAvailable()` called before any HealthKit operations?
2. Is the `requestAuthorization` completion handler correctly interpreted?
3. Is there any attempt to determine read permission status? (anti-pattern)
4. Are all Info.plist usage description keys present with meaningful text?
5. Do widgets avoid calling `requestAuthorization`?
6. Is authorization status re-checked before write operations (not cached)?
