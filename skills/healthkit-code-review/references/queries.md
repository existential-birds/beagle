# HealthKit Queries

## Query Types Overview

| Query Type | Use Case | Long-Running | Returns Deletions |
|------------|----------|--------------|-------------------|
| `HKSampleQuery` | One-time snapshot | No | No |
| `HKAnchoredObjectQuery` | Incremental sync, change tracking | Yes (with updateHandler) | Yes |
| `HKStatisticsQuery` | Single aggregation (sum, avg, min, max) | No | N/A |
| `HKStatisticsCollectionQuery` | Time-series aggregations | Yes | N/A |
| `HKActivitySummaryQuery` | Activity rings data | Yes (optional) | No |

## HKSampleQuery

Basic one-time fetch with sorting:

```swift
let query = HKSampleQuery(
    sampleType: sampleType,
    predicate: predicate,
    limit: HKObjectQueryNoLimit,
    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
) { (query, samples, error) in
    DispatchQueue.main.async {
        // Handle results - update UI
    }
}
healthStore.execute(query)
```

## HKAnchoredObjectQuery

For incremental sync with deletion tracking:

```swift
let query = HKAnchoredObjectQuery(
    type: sampleType,
    predicate: predicate,
    anchor: savedAnchor,  // nil for first fetch, persisted for subsequent
    limit: HKObjectQueryNoLimit
) { (query, samples, deletedObjects, newAnchor, error) in
    // Process samples AND deletedObjects
    self.saveAnchor(newAnchor)  // Persist for next query
}
// Optional: continuous monitoring
query.updateHandler = { (query, samples, deleted, newAnchor, error) in }
healthStore.execute(query)
```

**Important**: HKQueryAnchor cannot be reused across different sample types.

## HKStatisticsQuery

For aggregations - use correct options per data type:

| Data Type | Valid Options |
|-----------|---------------|
| Cumulative (steps, distance) | `.cumulativeSum` |
| Discrete (weight, heart rate) | `.discreteAverage`, `.discreteMin`, `.discreteMax` |

```swift
let query = HKStatisticsQuery(
    quantityType: stepCountType,
    quantitySamplePredicate: predicate,
    options: .cumulativeSum  // Use .discreteAverage for body mass
) { (query, statistics, error) in
    let sum = statistics?.sumQuantity()?.doubleValue(for: .count())
}
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

### 1. HKObjectQueryNoLimit Without Predicates

```swift
// BAD: May fetch millions of samples - memory exhaustion
let query = HKSampleQuery(
    sampleType: stepCountType,
    predicate: nil,
    limit: HKObjectQueryNoLimit,
    sortDescriptors: nil
) { ... }

// GOOD: Always bound with predicates
let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
let query = HKSampleQuery(
    sampleType: stepCountType,
    predicate: predicate,
    limit: 1000,  // Safety net
    sortDescriptors: [...]
) { ... }
```

### 2. Manual Summing Instead of Statistics Query

```swift
// BAD: Inefficient for cumulative data
let query = HKSampleQuery(...) { query, samples, error in
    var total = 0.0
    for sample in samples as? [HKQuantitySample] ?? [] {
        total += sample.quantity.doubleValue(for: .count())
    }
}

// GOOD: Use HKStatisticsQuery
let query = HKStatisticsQuery(
    quantityType: stepCountType,
    quantitySamplePredicate: predicate,
    options: .cumulativeSum
) { query, statistics, error in
    let total = statistics?.sumQuantity()?.doubleValue(for: .count())
}
```

### 3. Not Handling Deleted Samples

```swift
// BAD: Ignoring deletions in anchored query
let query = HKAnchoredObjectQuery(...) { query, samples, deletedObjects, newAnchor, error in
    for sample in samples ?? [] {
        self.syncToServer(sample)
    }
    // Missing deletion handling!
}

// GOOD: Process both additions and deletions
let query = HKAnchoredObjectQuery(...) { query, samples, deletedObjects, newAnchor, error in
    for sample in samples ?? [] {
        self.syncToServer(sample)
    }
    for deleted in deletedObjects ?? [] {
        self.deleteFromServer(deleted.uuid)  // Critical for data integrity
    }
    self.saveAnchor(newAnchor)
}
```

### 4. Reusing Anchors Across Sample Types

```swift
// BAD: Single anchor for all types
var anchor: HKQueryAnchor?
func syncWorkouts() { HKAnchoredObjectQuery(type: workoutType, anchor: anchor, ...) }
func syncSteps() { HKAnchoredObjectQuery(type: stepType, anchor: anchor, ...) }  // Wrong!

// GOOD: Separate anchor per type
var anchors: [String: HKQueryAnchor] = [:]
func sync(type: HKSampleType) {
    let query = HKAnchoredObjectQuery(type: type, anchor: anchors[type.identifier], ...) {
        query, samples, deleted, newAnchor, error in
        self.anchors[type.identifier] = newAnchor
    }
}
```

### 5. UI Updates on Background Thread

```swift
// BAD: Query handler runs on background thread
let query = HKSampleQuery(...) { query, samples, error in
    self.tableView.reloadData()  // Crash or undefined behavior
}

// GOOD: Dispatch to main thread
let query = HKSampleQuery(...) { query, samples, error in
    DispatchQueue.main.async {
        self.tableView.reloadData()
    }
}
```

### 6. Not Stopping Long-Running Queries

```swift
// BAD: Query never stopped - memory leak
class HealthVC: UIViewController {
    var query: HKObserverQuery?
    override func viewDidLoad() {
        query = HKObserverQuery(...)
        healthStore.execute(query!)
    }  // Query continues forever
}

// GOOD: Stop in deinit
class HealthVC: UIViewController {
    var query: HKObserverQuery?
    override func viewDidLoad() {
        query = HKObserverQuery(...)
        healthStore.execute(query!)
    }
    deinit {
        if let query = query { healthStore.stop(query) }
    }
}
```

## Review Questions

1. Is the correct query type used for the use case?
2. Are date predicates used to bound query results?
3. Are UI updates dispatched to the main thread?
4. Is `HKObjectQueryNoLimit` used with appropriate predicates?
5. Are deleted objects handled in anchored queries?
6. Are anchors persisted separately per sample type?
7. Are long-running queries stopped when no longer needed?
8. Are correct statistics options used for the data type?
