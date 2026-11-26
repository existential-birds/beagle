# Swift Error Handling

Focus on Swift-specific error propagation, concurrency cancellation, and typed throws pitfalls.

## Critical Anti-Patterns

### 1. Swallowing `CancellationError` in Broad `catch` Blocks

Structured concurrency cancels child tasks by throwing `CancellationError`. A broad `catch` that turns all errors into user alerts or fallback states can display false "network error" UI when a user navigates away or `.task` restarts.

```swift
// BAD - shows error alert when SwiftUI .task cancels on view dismissal
func loadData() async {
    do {
        items = try await service.fetchItems()
    } catch {
        errorMessage = error.localizedDescription  // Fires on CancellationError!
    }
}

// GOOD - handle or ignore CancellationError separately
func loadData() async {
    do {
        items = try await service.fetchItems()
    } catch is CancellationError {
        return
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 2. Force Try (`try!`) on Runtime I/O or Decoding

Reserve `try!` strictly for static compile-time-verified resources (e.g., bundled fixtures in tests or hardcoded regexes). Flag `try!` on file reads, user data, Keychain, or JSON decoding.

```swift
// BAD - crashes in production if file is missing or corrupt
let data = try! Data(contentsOf: configURL)
let config = try! JSONDecoder().decode(Config.self, from: data)

// GOOD - propagate or recover with logging
do {
    let data = try Data(contentsOf: configURL)
    return try JSONDecoder().decode(Config.self, from: data)
} catch {
    logger.error("Failed to load config: \(error)")
    return .default
}
```

### 3. Silent `try?` or Empty `catch` Discarding Diagnostic Context

`try?` is valid when absence is an expected non-error outcome (e.g., optional cache lookup), **not** when failures indicate bugs, corrupt state, or need user/log visibility.

```swift
// BAD - swallows decode/write failure silently
try? saveUserSettings(settings)

// GOOD - log and surface failure where callers/users depend on persistence
do {
    try saveUserSettings(settings)
} catch {
    logger.error("Failed to save settings: \(error)")
}
```

### 4. Losing Underlying Error Context When Wrapping

```swift
// BAD - destroys root cause in logs and diagnostics
catch {
    throw ProfileError.loadFailed
}

// GOOD - preserve underlying error for logging and debugging
enum ProfileError: LocalizedError {
    case networkFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .networkFailed(let error):
            return "Unable to load profile: \(error.localizedDescription)"
        }
    }
}
```

### 5. Swift 6 Typed Throws (`throws(E)`) on Public Library Boundaries

Typed throws (`SE-0413`) enforce exact error types at compile time and enable shorthand `.case` throwing and exhaustive `catch` without a fallback clause. However, exposing `throws(ConcreteError)` on **public** module/API boundaries locks you into that concrete error type as a source- and ABI-breaking constraint if you later need to add new failure modes.

```swift
// GOOD - typed throws in internal/module-scoped or embedded code with closed failure domains
func parseHeader(_ bytes: ArraySlice<UInt8>) throws(HeaderError) -> Header {
    guard bytes.count >= 4 else { throw .truncated }
    // ...
}

// CAUTION - public APIs usually benefit from untyped `throws` (any Error) for evolution flexibility
public func syncAccount() async throws { ... }
```

## `throws` vs `Result` vs Typed Throws

| Mechanism | Best Fit |
|---|---|
| `throws` (`any Error`) | Public APIs, async/await flows, extensible domain boundaries |
| `throws(MyError)` | Internal/closed domains, embedded Swift, callers needing exhaustive `catch` |
| `Result<T, E>` | Storing delayed outcomes, bridging completion handlers (`withCheckedThrowingContinuation`) |

## Review Questions

1. Do broad `catch` blocks inside `async` functions or `.task` handlers separate `CancellationError` from real failures?
2. Are all `try!` usages backed by compile-time certainty (not runtime files or decoded payloads)?
3. Are `try?` and `catch` blocks preserving enough context to diagnose real failures?
4. When wrapping errors, is the underlying error preserved?
5. Is Swift 6 typed throws (`throws(E)`) avoided on evolving `public` module APIs unless the error contract is intentionally closed?
