# Combine Memory Management

## AnyCancellable Lifecycle

`AnyCancellable` is a type-erasing wrapper that **automatically calls `cancel()` when deallocated**.

**Critical behavior:** If not retained, the subscription cancels immediately. This often manifests as `NSURLErrorDomain -999` errors.

```swift
// BAD: Subscription cancels immediately
func fetchData() {
    publisher.sink { data in self.data = data }
    // AnyCancellable not stored - immediately released!
}

// GOOD: Store in Set
var cancellables = Set<AnyCancellable>()

func fetchData() {
    publisher.sink { [weak self] data in
        self?.data = data
    }.store(in: &cancellables)
}
```

## The Retain Cycle Pattern

Retain cycles occur when:
1. `self` owns the cancellable (via `cancellables` Set)
2. The cancellable owns the closure
3. The closure captures `self` strongly

```
self → cancellables → closure → self (CYCLE)
```

## Critical Anti-Patterns

### 1. Strong Self in sink()

```swift
// RETAIN CYCLE
publisher.sink { value in
    self.property = value  // Strong capture
}.store(in: &cancellables)

// FIXED
publisher.sink { [weak self] value in
    self?.property = value
}.store(in: &cancellables)
```

### 2. assign(to:on:) with self

`assign(to:on:)` **always** captures its target strongly. No weak option exists.

```swift
// RETAIN CYCLE - ALWAYS
publisher
    .assign(to: \.property, on: self)
    .store(in: &cancellables)

// FIX 1: Use sink with weak self
publisher.sink { [weak self] value in
    self?.property = value
}.store(in: &cancellables)

// FIX 2: Use assign(to:) with @Published (iOS 14+)
@Published var property: Value
publisher.assign(to: &$property)  // No AnyCancellable returned
```

### 3. Not Storing the Cancellable

```swift
// BUG: Subscription dies immediately
func subscribe() {
    publisher.sink { print($0) }  // Discarded!
}

// FIXED
var cancellables = Set<AnyCancellable>()
func subscribe() {
    publisher.sink { print($0) }
        .store(in: &cancellables)
}
```

### 4. Nested Closures Missing Weak Captures

```swift
// Each closure needs its own [weak self]
publisher
    .flatMap { [weak self] value in
        self?.transform(value) ?? Empty()
    }
    .sink { [weak self] result in  // Need [weak self] again!
        self?.handle(result)
    }
    .store(in: &cancellables)
```

### 5. Long-Lived Subscriptions Without Weak Self

```swift
// MEMORY LEAK: Timer keeps self alive forever
Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { _ in
        self.updateUI()  // Strong capture
    }
    .store(in: &cancellables)

// FIXED
Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { [weak self] _ in
        self?.updateUI()
    }
    .store(in: &cancellables)
```

## Single Cancellable Pattern

For auto-cancelling previous subscriptions (search debouncing):

```swift
private var searchCancellable: AnyCancellable?

func search(_ query: String) {
    // Previous subscription automatically cancelled
    searchCancellable = searchPublisher(query)
        .sink { [weak self] results in
            self?.results = results
        }
}
```

## Review Questions

1. Is every `sink()` and `assign()` result stored?
2. Does `sink()` use `[weak self]` when self owns the cancellable?
3. Is `assign(to:on:)` used with `self`? (Always a leak)
4. Are there nested closures missing weak captures?
5. Are long-lived subscriptions (timers, notifications) using weak self?
