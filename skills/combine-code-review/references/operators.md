# Combine Operators

## Key Operators by Category

### Transforming
| Operator | Purpose |
|----------|---------|
| `map` | Transform each value 1:1 |
| `tryMap` | Transform with throwing closure (erases error type) |
| `flatMap` | Transform to new publisher, flatten nested publishers |
| `compactMap` | Transform and filter out nil values |
| `scan` | Accumulate values over time (emits each step) |

### Combining
| Operator | Purpose |
|----------|---------|
| `merge` | Interleave values from publishers of same type |
| `combineLatest` | Emit tuple of latest values when any emits |
| `zip` | Pair values by index (waits for all to emit) |
| `switchToLatest` | Switch to latest inner publisher, cancel previous |

### Timing
| Operator | Purpose |
|----------|---------|
| `debounce` | Wait for pause in emissions |
| `throttle` | Limit rate of emissions |
| `delay` | Shift emissions forward in time |
| `timeout` | Fail if no value within time limit |

## map vs flatMap vs switchToLatest

| Scenario | Use |
|----------|-----|
| Transform value: `String` → `Int` | `map` |
| Transform to publisher: `URL` → `Publisher<Data>` | `flatMap` |
| Transform to publisher, cancel previous | `map` + `switchToLatest` |

```swift
// map: Simple transformation
publisher.map { $0.uppercased() }

// flatMap: Transformation produces a publisher
publisher.flatMap { url in
    URLSession.shared.dataTaskPublisher(for: url)
}

// switchToLatest: Cancel previous (search/autocomplete)
searchText
    .map { query in searchAPI(query) }
    .switchToLatest()  // Cancels previous request
```

## combineLatest vs merge vs zip

| Aspect | merge | combineLatest | zip |
|--------|-------|---------------|-----|
| **Output** | Same type | Tuple | Tuple |
| **Emits when** | Any emits | Any (after all emit once) | All emit new value |
| **Use for** | Multiple event sources | Form validation | Parallel requests |

```swift
// merge: Combine same-type streams
let allTaps = buttonA.merge(with: buttonB)

// combineLatest: React to any change (form validation)
Publishers.CombineLatest(emailValid, passwordValid)
    .map { $0 && $1 }

// zip: Wait for both (parallel requests)
Publishers.Zip(fetchUser, fetchPreferences)
```

## Critical Anti-Patterns

### 1. flatMap Instead of switchToLatest for Search

```swift
// BAD: All requests execute, results arrive out of order
searchText.flatMap { query in search(query) }

// GOOD: Cancel previous requests
searchText
    .map { query in search(query) }
    .switchToLatest()
```

### 2. Wrong Threading Operator

```swift
// BAD: subscribe(on:) doesn't affect where values received
URLSession.shared.dataTaskPublisher(for: url)
    .subscribe(on: DispatchQueue.main)  // WRONG!
    .sink { /* NOT on main thread */ }

// GOOD: Use receive(on:) for downstream
URLSession.shared.dataTaskPublisher(for: url)
    .receive(on: DispatchQueue.main)
    .sink { /* On main thread */ }
```

### 3. combineLatest with Publisher That Never Emits

```swift
// BUG: Won't emit until ALL publishers emit at least once
Publishers.CombineLatest(requiredField, optionalAction)
// If optionalAction never fires, stream never starts
```

### 4. Using tryMap Without mapError

```swift
// BAD: Erases error type to plain Error
publisher.tryMap { try decode($0) }

// GOOD: Restore specific error type
publisher.tryMap { try decode($0) }
    .mapError { $0 as? APIError ?? .unknown($0) }
```

## Review Questions

1. Is `flatMap` appropriate, or should it be `map + switchToLatest`?
2. Are `combineLatest` publishers guaranteed to emit at least once?
3. Is `receive(on:)` used before UI updates (not `subscribe(on:)`)?
4. Are try* operators followed by `mapError` for type safety?
5. Could `debounce` or `throttle` reduce unnecessary work?
