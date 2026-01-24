# HealthKit Data Types

## Data Type Hierarchy

| Type | Class | Purpose |
|------|-------|---------|
| Quantity | `HKQuantityType` / `HKQuantitySample` | Measurable numeric values with units |
| Category | `HKCategoryType` / `HKCategorySample` | Enumerated categorical values |
| Correlation | `HKCorrelationType` / `HKCorrelation` | Groups of related samples |
| Characteristic | `HKCharacteristicType` | Static, immutable user data |
| Workout | `HKWorkout` / `HKWorkoutBuilder` | Exercise sessions |

## HKQuantityType - Measurable Data

Common quantity types and their units:

| Type | Unit |
|------|------|
| `.stepCount` | `.count()` |
| `.heartRate` | `HKUnit(from: "count/min")` |
| `.distanceWalkingRunning` | `.meter()` |
| `.activeEnergyBurned` | `.kilocalorie()` |
| `.bloodPressureSystolic` | `.millimeterOfMercury()` |
| `.oxygenSaturation` | `.percent()` |

### Creating HKQuantitySample

```swift
// 1. Get quantity type
guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

// 2. Create quantity with unit
let quantity = HKQuantity(unit: .count(), doubleValue: 10000)

// 3. Create sample with metadata
let metadata: [String: Any] = [
    HKMetadataKeyTimeZone: TimeZone.current.identifier,
    HKMetadataKeyWasUserEntered: false
]
let sample = HKQuantitySample(type: stepType, quantity: quantity,
                               start: startDate, end: endDate, metadata: metadata)

// 4. Save
healthStore.save(sample) { success, error in }
```

## HKCategoryType - Enumerated Data

### Sleep Analysis (iOS 16+)

```swift
let sleepType = HKCategoryType(.sleepAnalysis)

// Create both in-bed and asleep samples
let inBedSample = HKCategorySample(
    type: sleepType,
    value: HKCategoryValueSleepAnalysis.inBed.rawValue,
    start: bedTime, end: wakeTime
)
let asleepSample = HKCategorySample(
    type: sleepType,
    value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,  // iOS 16+
    start: fallAsleepTime, end: actualWakeTime
)
healthStore.save([inBedSample, asleepSample]) { _, _ in }
```

## HKCorrelation - Blood Pressure

Blood pressure requires a correlation with both systolic and diastolic:

```swift
// Create systolic sample
let systolicType = HKQuantityType(.bloodPressureSystolic)
let systolicSample = HKQuantitySample(
    type: systolicType,
    quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 120),
    start: date, end: date
)

// Create diastolic sample
let diastolicType = HKQuantityType(.bloodPressureDiastolic)
let diastolicSample = HKQuantitySample(
    type: diastolicType,
    quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 80),
    start: date, end: date
)

// Create correlation
let bpType = HKCorrelationType(.bloodPressure)
let bpCorrelation = HKCorrelation(
    type: bpType, start: date, end: date,
    objects: [systolicSample, diastolicSample]
)
```

**Important**: Request permissions on systolic/diastolic types, NOT the correlation type.

## HKCharacteristicType - Static Data

Read-only characteristics set by user in Health app:

```swift
do {
    let biologicalSex = try healthStore.biologicalSex().biologicalSex
    switch biologicalSex {
    case .female, .male, .other: // handle
    case .notSet: // user hasn't set
    @unknown default: break
    }
} catch {
    // Permission denied or not set
}
```

## HKWorkoutBuilder Pattern

```swift
let config = HKWorkoutConfiguration()
config.activityType = .running
config.locationType = .outdoor

let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
try await builder.beginCollection(at: startDate)

// Add samples during workout
try await builder.addSamples([heartRateSample, distanceSample])

// Finish
try await builder.endCollection(at: endDate)
let workout = try await builder.finishWorkout()
```

## Critical Anti-Patterns

### 1. Wrong Units for Quantity Types

```swift
// BAD: Incompatible units
let heartRate = HKQuantity(unit: .count(), doubleValue: 72)  // Wrong!
let distance = HKQuantity(unit: .kilocalorie(), doubleValue: 5000)  // Wrong!

// GOOD: Correct compatible units
let heartRate = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: 72)
let distance = HKQuantity(unit: .meter(), doubleValue: 5000)
```

### 2. Force Unwrapping Quantity Types

```swift
// BAD: Can crash
let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

// GOOD: Safe unwrapping
guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
    print("Step count type unavailable")
    return
}
```

### 3. Requesting Correlation Type Permission

```swift
// BAD: Cannot request permission for correlation types
let bpType = HKCorrelationType(.bloodPressure)
let typesToRead: Set<HKObjectType> = [bpType]  // Will fail!

// GOOD: Request underlying quantity types
let systolicType = HKQuantityType(.bloodPressureSystolic)
let diastolicType = HKQuantityType(.bloodPressureDiastolic)
let typesToRead: Set<HKObjectType> = [systolicType, diastolicType]
```

### 4. Not Including Time Zone Metadata

```swift
// BAD: No time zone
let sample = HKQuantitySample(type: type, quantity: quantity, start: start, end: end)

// GOOD: Include time zone
let metadata: [String: Any] = [HKMetadataKeyTimeZone: TimeZone.current.identifier]
let sample = HKQuantitySample(type: type, quantity: quantity,
                               start: start, end: end, metadata: metadata)
```

### 5. Reading Characteristics Without Error Handling

```swift
// BAD: Force try
let sex = try! healthStore.biologicalSex().biologicalSex

// GOOD: Handle errors
do {
    let sex = try healthStore.biologicalSex().biologicalSex
    // Check for .notSet
} catch {
    // Handle permission denied or not set
}
```

### 6. Only Creating InBed Sleep Sample

```swift
// BAD: Missing actual sleep sample
let inBedSample = HKCategorySample(type: sleepType,
    value: HKCategoryValueSleepAnalysis.inBed.rawValue, ...)
// No asleep sample!

// GOOD: Create both
let inBedSample = HKCategorySample(type: sleepType,
    value: HKCategoryValueSleepAnalysis.inBed.rawValue,
    start: bedTime, end: wakeTime)
let asleepSample = HKCategorySample(type: sleepType,
    value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
    start: sleepTime, end: wakeTime)
healthStore.save([inBedSample, asleepSample]) { _, _ in }
```

## Unit Conversion

```swift
// HealthKit handles conversion automatically
let distanceInMeters = sample.quantity.doubleValue(for: .meter())
let distanceInMiles = sample.quantity.doubleValue(for: .mile())

// User preferred units
healthStore.preferredUnits(for: [stepType]) { units, error in
    let preferredUnit = units[stepType]
}
```

## Review Questions

1. Is `isHealthDataAvailable()` checked before creating HKHealthStore?
2. Are quantity types used with compatible units?
3. Are correlation types (blood pressure) created with all required sub-samples?
4. Are permissions requested on underlying types, not correlation types?
5. Are characteristics read with proper error handling for `.notSet`?
6. Is metadata included (time zone, sync identifier)?
7. Are sleep samples created correctly (both inBed and asleep)?
8. Is `HKWorkoutBuilder` used instead of deprecated HKWorkout init?
