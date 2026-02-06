# Swift Error Handling

## Critical Anti-Patterns

### 1. Force Try in Production Code

```swift
// BAD - crashes if file missing or JSON invalid
let data = try! Data(contentsOf: configURL)
let config = try! JSONDecoder().decode(Config.self, from: data)

// GOOD - handle failures
do {
    let data = try Data(contentsOf: configURL)
    let config = try JSONDecoder().decode(Config.self, from: data)
} catch {
    logger.error("Failed to load config: \(error)")
    return Config.default
}
```

### 2. Silencing Errors Without Logging

```swift
// BAD - error context lost
let user = try? fetchUser(id: userId)
if user == nil { showError("Something went wrong") }

// GOOD - log the actual error
do {
    let user = try fetchUser(id: userId)
    display(user)
} catch {
    logger.error("Failed to fetch user \(userId): \(error)")
    showError(error.localizedDescription)
}
```

### 3. Empty Catch Blocks

```swift
// BAD - user thinks save succeeded
do { try saveDocument() } catch { }

// GOOD - inform user of failure
do {
    try saveDocument()
    showSuccess("Document saved")
} catch {
    showError("Failed to save: \(error.localizedDescription)")
}
```

### 4. Generic Error Messages

```swift
// BAD - cryptic error display
enum NetworkError: Error {
    case requestFailed
}

// GOOD - LocalizedError with descriptions
enum NetworkError: LocalizedError {
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let code):
            return "Request failed with status \(code)"
        }
    }
}
```

### 5. Losing Error Context When Wrapping

```swift
// BAD - original error lost
catch { throw ProfileError.loadFailed }

// GOOD - preserve underlying error
enum ProfileError: LocalizedError {
    case networkFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkFailed(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

### 6. Completion Handler Not Called on All Paths

```swift
// BAD - completion never called on guard failure
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    guard let url = buildURL() else { return }  // Bug!
    // ...
}

// GOOD - always call completion
guard let url = buildURL() else {
    completion(.failure(NetworkError.invalidURL))
    return
}
```

## try, try?, try! Guidelines

| Variant | Use When |
|---------|----------|
| `try` | Need to handle specific errors with recovery logic |
| `try?` | Error details unimportant, just need success/failure |
| `try!` | Compile-time certainty only: hardcoded URLs, bundled assets |

```swift
// Acceptable try!
let url = URL(string: "https://api.example.com")!  // Hardcoded, verified

// Never try! with runtime data
let url = URL(string: userInput)!  // CRASH RISK
```

## Swift 6 Typed Throws

```swift
// Typed throws - compiler enforces error type
func readFile(at path: String) throws(FileError) -> Data {
    guard fileExists(path) else { throw .notFound }
    // ...
}

// Benefits: self-documenting API, shorthand .case syntax
// Avoid for: public APIs (locks you into error contract)
```

## Result Type vs throws

| Use `throws` | Use `Result` |
|--------------|--------------|
| Synchronous code | Completion handlers |
| async/await code | Storing error state |
| Complex recovery | Delaying handling |

## Review Questions

1. Are all `try!` usages backed by compile-time certainty?
2. Are errors logged with enough context to diagnose issues?
3. Do custom errors conform to `LocalizedError`?
4. Are completion handlers called on every code path?
5. Is the underlying error preserved when wrapping?
