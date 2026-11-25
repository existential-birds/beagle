# HealthKit Queries

## Query Types Overview

Prefer **iOS 15.4+ Swift Concurrency Query Descriptors** (`HKSampleQueryDescriptor`, `HKAnchoredObjectQueryDescriptor`, `HKStatisticsQueryDescriptor`) over legacy callback-based `HKQuery` classes on modern targets:

| Descriptor (iOS 15.4+) | Legacy Equivalent | Use Case | Long-Running | Returns Deletions |
|------------------------|-------------------|----------|--------------|-------------------|
| `HKSampleQueryDescriptor` | `HKSampleQuery` | One-time snapshot | No | No |
| `HKAnchoredObjectQueryDescriptor` | `HKAnchoredObjectQuery` | Incremental sync, change tracking | Yes (`results(for:)`) | Yes |
| `HKStatisticsQueryDescriptor` | `HKStatisticsQuery` | Single aggregation (sum, avg, min, max) | No | N/A |
| `HKStatisticsCollectionQueryDescriptor` | `HKStatisticsCollectionQuery` | Time-series aggregations | Yes (`results(for:)`) | N/A |
| `HKActivitySummaryQuery` | `HKActivitySummaryQuery` | Activity rings data | Yes (optional) | No |

## HKSampleQueryDescriptor (iOS 15.4+)

Basic one-time async fetch with sorting:

```swift
let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
let descriptor = HKSampleQueryDescriptor(
    predicates: [.quantitySample(type: heartRateType, predicate: predicate)],
    sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
    limit: 100
)

let samples = try await descriptor.result(for: healthStore)
```

*(Legacy `HKSampleQuery` completion handlers run on an arbitrary background queue — dispatch UI updates to `@MainActor` / `DispatchQueue.main.async`.)*

## HKAnchoredObjectQueryDescriptor (iOS 15.4+)

For incremental sync with deletion tracking (`result(for:)` for one-shot snapshot, `results(for:)` `AsyncSequence` for continuous updates):

```swift
let descriptor = HKAnchoredObjectQueryDescriptor(
    predicates: [.quantitySample(type: stepType)],
    anchor: savedAnchor  // nil for first fetch, persisted per sample type
)

// One-shot incremental snapshot
let result = try await descriptor.result(for: healthStore)
process(added: result.addedSamples, deleted: result.deletedObjects)
saveAnchor(result.newAnchor, for: stepType)

// Continuous AsyncSequence updates (cancel Task on teardown)
let updateTask = Task {
    for try await update in descriptor.results(for: healthStore) {
        process(added: update.addedSamples, deleted: update.deletedObjects)
        saveAnchor(update.newAnchor, for: stepType)
    }
}
```

**Important**: `HKQueryAnchor` cannot be reused across different sample types.

## HKStatisticsQueryDescriptor (iOS 15.4+)

For aggregations — use correct options per data type:

| Data Type | Valid Options |
|-----------|---------------|
| Cumulative (steps, distance) | `.cumulativeSum` |
| Discrete (weight, heart rate) | `.discreteAverage`, `.discreteMin`, `.discreteMax` |

```swift
let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
let descriptor = HKStatisticsQueryDescriptor(
    predicate: .quantitySample(type: stepCountType, predicate: predicate),
    options: .cumulativeSum  // Use .discreteAverage for body mass
)

let statistics = try await descriptor.result(for: healthStore)
let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
```

## Predicate Building

```swift
let predicate = HKQuery.predicateForSamples(
    withStart: startDate,
    end: endDate,
    options: [.strictStartDate, .strictEndDate]
)
// .strictStartDate: Sample start >= startDate
// .strictEndDate: Sample end <= endDate
// [] (empty): Sample overlaps with range
```

## Critical Anti-Patterns

### 1. Unbounded Queries Without Predicates

```swift
// BAD: May fetch millions of samples - memory exhaustion
let descriptor = HKSampleQueryDescriptor(
    predicates: [.quantitySample(type: stepCountType)],
    sortDescriptors: []
)

// GOOD: Always bound with date predicates and/or limit
let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
let descriptor = HKSampleQueryDescriptor(
    predicates: [.quantitySample(type: stepCountType, predicate: predicate)],
    sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
    limit: 1000
)
```

### 2. Manual Summing Instead of Statistics Query

```swift
// BAD: Inefficient for cumulative data
let samples = try await sampleDescriptor.result(for: healthStore)
let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) }

// GOOD: Use HKStatisticsQueryDescriptor
let descriptor = HKStatisticsQueryDescriptor(
    predicate: .quantitySample(type: stepCountType, predicate: predicate),
    options: .cumulativeSum
)
let total = try await descriptor.result(for: healthStore)?
    .sumQuantity()?.doubleValue(for: .count()) ?? 0
```

### 3. Not Handling Deleted Samples

```swift
// BAD: Ignoring deletions in anchored query
let result = try await descriptor.result(for: healthStore)
for sample in result.addedSamples {
    syncToServer(sample)
}
// Missing result.deletedObjects handling!

// GOOD: Process both additions and deletions
let result = try await descriptor.result(for: healthStore)
for sample in result.addedSamples {
    syncToServer(sample)
}
for deleted in result.deletedObjects {
    deleteFromServer(deleted.uuid)  // Critical for data integrity
}
saveAnchor(result.newAnchor, for: sampleType)
```

### 4. Reusing Anchors Across Sample Types

```swift
// BAD: Single anchor for all types
var anchor: HKQueryAnchor?
func syncWorkouts() { /* uses anchor */ }
func syncSteps() { /* reuses same anchor - Wrong! */ }

// GOOD: Separate anchor per type
var anchors: [String: HKQueryAnchor] = [:]
func sync(type: HKSampleType) async throws {
    let descriptor = HKAnchoredObjectQueryDescriptor(
        predicates: [.sample(type: type)],
        anchor: anchors[type.identifier]
    )
    let result = try await descriptor.result(for: healthStore)
    anchors[type.identifier] = result.newAnchor
}
```

### 5. UI Updates Off MainActor

```swift
// BAD: Legacy query handler runs on background thread
let query = HKSampleQuery(...) { query, samples, error in
    self.tableView.reloadData()  // Crash or undefined behavior!
}

// GOOD: Isolate UI updates on @MainActor with async/await
@MainActor
func loadSamples() async throws {
    let samples = try await descriptor.result(for: healthStore)
    self.samples = samples
    self.tableView.reloadData()
}
```

### 6. Not Stopping Long-Running Queries or Cancelling Tasks

```swift
// BAD: Legacy observer query never stopped (or results(for:) Task leaked)
class HealthVC: UIViewController {
    var query: HKObserverQuery?
    override func viewDidLoad() {
        query = HKObserverQuery(...)
        healthStore.execute(query!)
    }  // Query continues forever
}

// GOOD: Stop legacy query in deinit / cancel continuous Task
class HealthVC: UIViewController {
    var query: HKObserverQuery?
    private var streamTask: Task<Void, Never>?

    deinit {
        if let query { healthStore.stop(query) }
        streamTask?.cancel()
    }
}
```

## Review Questions

1. Are modern iOS 15.4+ query descriptors used where deployment target allows?
2. Are date predicates used to bound query results (especially with `HKObjectQueryNoLimit` or omitted `limit`)?
3. Are UI updates isolated on `@MainActor`?
4. Are deleted objects handled in anchored queries?
5. Are `HKQueryAnchor`s persisted separately per sample type?
6. Are long-running queries stopped (`healthStore.stop(_:)`) or continuous `results(for:)` `Task`s cancelled when no longer needed?
7. Are correct statistics options used for cumulative vs discrete data types?
