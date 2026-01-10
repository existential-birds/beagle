# Swift Concurrency

## Critical Anti-Patterns

### 1. Sequential Execution When Concurrent Is Possible

```swift
// BAD - sequential awaits on independent operations
let user = await fetchUser()
let avatar = await fetchAvatar(for: user.id)      // Waits unnecessarily
let prefs = await fetchPreferences(for: user.id)  // Waits unnecessarily

// GOOD - async let for independent operations
let user = await fetchUser()
async let avatar = fetchAvatar(for: user.id)
async let prefs = fetchPreferences(for: user.id)
return Profile(user: user, avatar: try await avatar, prefs: try await prefs)
```

### 2. Memory Leaks from Task Self-Capture

```swift
// BAD - self captured indefinitely in async sequence
Task {
    for await notification in stream {
        handleNotification(notification)  // implicit self
    }
}

// GOOD - weak self with guard inside the loop
Task { [weak self] in
    for await notification in stream {
        guard let self else { return }
        self.handleNotification(notification)
    }
}
```

### 3. Actor Reentrancy Bugs

```swift
// BAD - state check before await, mutation after
actor BankAccount {
    var balance: Double = 1000
    func withdraw(_ amount: Double) async -> Bool {
        guard balance >= amount else { return false }
        await recordTransaction(amount)  // state can change here!
        balance -= amount  // may go negative
        return true
    }
}

// GOOD - mutate state before await
func withdraw(_ amount: Double) async -> Bool {
    guard balance >= amount else { return false }
    balance -= amount  // safe - done before suspension
    await recordTransaction(amount)
    return true
}
```

### 4. Stateless Actors

```swift
// BAD - actor with nothing to protect
actor NetworkService {
    func fetchData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

// GOOD - use enum or struct for stateless operations
enum NetworkService {
    static func fetchData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}
```

### 5. Ignoring Task Cancellation

```swift
// BAD - long loop ignores cancellation
for item in items {
    await process(item)
}

// GOOD - check cancellation
for item in items {
    try Task.checkCancellation()
    await process(item)
}
```

### 6. Non-Sendable Types Across Actors

```swift
// BAD - mutable class crossing boundaries
class Session { var token: String? }

// GOOD - immutable struct
struct Session: Sendable { let token: String }

// GOOD - @unchecked with actual lock
final class Session: @unchecked Sendable {
    private let lock = NSLock()
    private var _token: String?
    var token: String? {
        get { lock.withLock { _token } }
        set { lock.withLock { _token = newValue } }
    }
}
```

### 7. Errors Silently Ignored in Tasks

```swift
// BAD - error lost
Task { try await database.save(data) }

// GOOD - handle explicitly
Task {
    do { try await database.save(data) }
    catch { logger.error("Save failed: \(error)") }
}
```

## Best Practices

- **Use `async let`** for 2-3 independent operations
- **Use `TaskGroup`** for dynamic number of concurrent tasks with result aggregation
- **Apply `@MainActor` at type level** for ViewModels, not scattered `MainActor.run`
- **Use `.task` modifier** in SwiftUI instead of `Task` in `onAppear`
- **Use `nonisolated`** for pure functions in @MainActor types
- **Limit TaskGroup concurrency** with iterator pattern for large workloads

## Review Questions

1. Are independent async operations running concurrently?
2. Could actor state change across suspension points (reentrancy)?
3. Is `@unchecked Sendable` backed by actual synchronization?
4. Are long-running Tasks checking `Task.isCancelled`?
5. Are errors in Task closures being handled or silently lost?
