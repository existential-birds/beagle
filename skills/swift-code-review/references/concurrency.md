# Swift Concurrency

## Swift 6.2 Approachable Concurrency

Check `Package.swift` `swiftSettings` and Xcode target build settings before flagging isolation annotations—Swift 6.2 introduces three major opt-in/default behaviors:

| Proposal / Setting | Behavior | Review Implication |
|---|---|---|
| `SE-0466` (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) | Unannotated types and functions in the module default to `@MainActor` | Do **not** flag ViewModels/views for missing `@MainActor` when default isolation is `MainActor` |
| `SE-0461` (`NonisolatedNonsendingByDefault` / `nonisolated(nonsending)` / `@concurrent`) | `nonisolated async` functions inherit the caller's actor instead of hopping to the global concurrent executor; `@concurrent` explicitly hops to the global cooperative pool | Heavy CPU/blocking work in `nonisolated async` helpers now stays on `MainActor` if called from UI unless marked `@concurrent` |
| `SE-0470` (`InferIsolatedConformances` / Global-Actor Isolated Conformances) | Allows protocols like `Equatable` or `Hashable` to be conformed on a global actor (e.g., `@MainActor Equatable`) | Don't flag global-actor isolated protocol conformances as invalid when `SE-0470` / `InferIsolatedConformances` is active |

```swift
// BAD (under Swift 6.2 NonisolatedNonsendingByDefault):
// Called from @MainActor, this runs on the main actor despite being nonisolated!
nonisolated func parseLargeJSON(_ data: Data) async throws -> [Record] {
    try JSONDecoder().decode([Record].self, from: data)
}

// GOOD: Explicitly offload CPU-heavy work to the global concurrent executor
@concurrent
func parseLargeJSON(_ data: Data) async throws -> [Record] {
    try JSONDecoder().decode([Record].self, from: data)
}
```

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

// GOOD - check cancellation (throws CancellationError in throwing functions)
for item in items {
    try Task.checkCancellation()
    await process(item)
}

// GOOD - non-throwing early exit
for item in items {
    guard !Task.isCancelled else { return }
    await process(item)
}
```

### 6. Non-Sendable Types Across Actors

```swift
// BAD - mutable class crossing boundaries
class Session { var token: String? }

// GOOD - immutable struct
struct Session: Sendable { let token: String }

// GOOD - @unchecked with actual synchronization (e.g. Synchronization.Mutex on iOS 18+ / macOS 15+, or NSLock)
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

// GOOD - handle explicitly (and preserve CancellationError awareness)
Task {
    do {
        try await database.save(data)
    } catch is CancellationError {
        return
    } catch {
        logger.error("Save failed: \(error)")
    }
}
```

## Best Practices

- **Use `async let`** for 2-3 independent operations; **`TaskGroup`** for dynamic concurrent fan-out
- **Limit `TaskGroup` concurrency** (batch/windowed pattern) for large workloads so you don't exhaust connections or memory
- **Apply `@MainActor` at type level** for ViewModels (unless the target enables `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), rather than scattered `MainActor.run`
- **Use `@concurrent`** (Swift 6.2+) to offload CPU-bound async work off the caller's actor
- **Use `.task` modifier** in SwiftUI instead of unstructured `Task` in `onAppear`

## Review Questions

1. Are independent async operations running concurrently?
2. Could actor state change across suspension points (reentrancy)?
3. Under Swift 6.2 `NonisolatedNonsendingByDefault`, is heavy CPU work marked `@concurrent`?
4. Is `@unchecked Sendable` backed by actual synchronization (`Mutex`, `NSLock`, or serial queue)?
5. Are long-running `Task` loops checking `Task.checkCancellation()` / `Task.isCancelled`?
6. Are errors in `Task` closures handled instead of silently discarded?
