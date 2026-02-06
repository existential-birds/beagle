# Combine Publishers

## Built-in Publishers

| Publisher | Use Case |
|-----------|----------|
| `Just` | Single synchronous value, placeholders |
| `Future` | Converting callback-based APIs (executes once, caches result) |
| `Deferred` | Lazy publisher creation, wrap Future for retry support |
| `Empty` | No-op placeholder, completing immediately |
| `Fail` | Immediate error emission, testing error paths |
| `Sequence.publisher` | `[1,2,3].publisher` emits each element |
| `Timer.Publisher` | Periodic events (requires `autoconnect()`) |
| `DataTaskPublisher` | Network requests via URLSession |

## Subject Types

### PassthroughSubject - Use for Events

```swift
let buttonTaps = PassthroughSubject<Void, Never>()
buttonTaps.send(())  // Subscribers only notified if already subscribed
```

- No initial value required
- No `.value` property
- New subscribers receive only future values
- Best for: button taps, user actions, transient events

### CurrentValueSubject - Use for State

```swift
let loadingState = CurrentValueSubject<LoadingState, Never>(.idle)
print(loadingState.value)  // Can query current state
```

- Initial value required
- `.value` property for direct access
- New subscribers receive current value immediately
- Best for: settings, loading state, toggles

## Critical Anti-Patterns

### 1. Exposing Subjects Publicly

```swift
// BAD: External code can call loginSubject.send(...)
class AuthManager {
    let loginSubject = PassthroughSubject<User, Error>()
}

// GOOD: Expose as read-only publisher
class AuthManager {
    private let loginSubject = PassthroughSubject<User, Error>()
    var loginPublisher: AnyPublisher<User, Error> {
        loginSubject.eraseToAnyPublisher()
    }
}
```

### 2. Using Just for Arrays When Sequence Intended

```swift
// BAD: Emits entire array as one value
Just([1, 2, 3]).sink { print($0) }  // prints: [1, 2, 3]

// GOOD: Emits each element
[1, 2, 3].publisher.sink { print($0) }  // prints: 1, 2, 3
```

### 3. Future Without Deferred for Retry

```swift
// BAD: Retry reuses cached failure
Future { promise in networkCall(completion: promise) }
    .retry(3)  // Same cached result retried!

// GOOD: Wrap in Deferred
Deferred {
    Future { promise in networkCall(completion: promise) }
}.retry(3)  // New Future created each retry
```

### 4. Wrong Subject Type for Use Case

```swift
// BAD: PassthroughSubject for state (late subscribers miss value)
let isLoggedIn = PassthroughSubject<Bool, Never>()

// GOOD: CurrentValueSubject for state
let isLoggedIn = CurrentValueSubject<Bool, Never>(false)
```

## Review Questions

1. Are Subjects exposed publicly or converted to AnyPublisher?
2. Is the correct Subject type used (events vs state)?
3. Is Future used with retry without Deferred wrapper?
4. Are built-in publishers preferred over custom implementations?
5. Is `.value` access needed? (Requires CurrentValueSubject)
