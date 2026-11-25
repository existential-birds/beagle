# HealthKit Authorization

## Authorization Model

HealthKit uses **per-data-type, separate read/write authorization**. Users grant access individually for each health data type.

### Required Setup

1. **Entitlement**: `com.apple.developer.healthkit` capability
2. **Info.plist Keys**:
   - `NSHealthShareUsageDescription` — Why app needs to **read** health data
   - `NSHealthUpdateUsageDescription` — Why app needs to **write** health data

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
| `isHealthDataAvailable()` | Check device support (not on iPad pre-iPadOS 17; unavailable on some Macs/devices) |
| `authorizationStatus(for:)` | Check **write** permission only |
| `statusForAuthorizationRequest(toShare:read:)` | Async check if auth sheet would appear (`getRequestStatusForAuthorization(toShare:read:)` for legacy completion) |
| `requestAuthorization(toShare:read:)` | Request permissions from user |

## Critical Anti-Patterns

### 1. Misinterpreting requestAuthorization Success

```swift
// BAD: success/no-throw does NOT mean permission granted
try await healthStore.requestAuthorization(toShare: types, read: types)
startRecordingWorkout()  // May fail if write permission denied!

// GOOD: completing authorization means dialog flow finished
try await healthStore.requestAuthorization(toShare: types, read: types)
if healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized {
    startRecordingWorkout()
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
func fetchHeartRateData() async throws -> [HKQuantitySample] {
    let descriptor = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: heartRateType)],
        sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
        limit: 50
    )
    return try await descriptor.result(for: healthStore)  // Empty if denied
}
```

### 3. Not Checking Device Availability

```swift
// BAD: HealthKit may be unavailable on target device
func requestHealthKitAccess() async throws {
    try await healthStore.requestAuthorization(toShare: types, read: types)
}

// GOOD: Always check availability first
func requestHealthKitAccess() async throws {
    guard HKHealthStore.isHealthDataAvailable() else {
        showHealthKitNotAvailableMessage()
        return
    }
    try await healthStore.requestAuthorization(toShare: types, read: types)
}
```

### 4. Widgets Requesting Authorization

```swift
// BAD: Widgets cannot present authorization UI
struct HealthWidget: Widget {
    func getTimeline(...) {
        Task { try? await healthStore.requestAuthorization(...) }  // Will fail
    }
}

// GOOD: Use statusForAuthorizationRequest in widgets
struct HealthWidget: Widget {
    func getTimeline(...) async {
        let status = try? await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
        if status == .shouldRequest {
            showOpenAppPrompt()
        } else {
            await displayHealthData()  // May be empty if denied
        }
    }
}
```

### 5. Accessing Data Before Authorization Completes

```swift
// BAD: Race condition (HKError code 5)
func initialize() {
    Task { try? await healthStore.requestAuthorization(toShare: types, read: types) }
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
2. Is `requestAuthorization` success/completion correctly interpreted (write status checked via `authorizationStatus(for:)`, read denied handled as empty)?
3. Is there any attempt to determine read permission status? (anti-pattern)
4. Are all `Info.plist` usage description keys present with meaningful text?
5. Do widgets avoid calling `requestAuthorization` and instead check `statusForAuthorizationRequest`?
6. Is authorization status re-checked before write operations (not cached)?
