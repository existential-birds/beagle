# Intent Structure

## AppIntent Protocol

Required conformance for all App Intents:

```swift
struct OpenCurrentlyReading: AppIntent {
    static var title: LocalizedStringResource = "Open Currently Reading"
    static var openAppWhenRun: Bool = true  // Optional: default false

    @MainActor
    func perform() async throws -> some IntentResult {
        Navigator.shared.openShelf(.currentlyReading)
        return .result()
    }
}
```

| Property | Required | Default | Purpose |
|----------|----------|---------|---------|
| `title` | Yes | - | Localized display name |
| `openAppWhenRun` | No | `false` | Launch app before execution |
| `isDiscoverable` | No | `true` | Show in Shortcuts app (iOS 17+) |

## Return Types

`perform()` returns `some IntentResult` with optional protocol conformances:

| Protocol | Purpose | Example |
|----------|---------|---------|
| `ReturnsValue<T>` | Pass data to next intent | `.result(value: book)` |
| `ProvidesDialog` | Siri voice/text response | `.result(dialog: "Done!")` |
| `ShowsSnippetView` | SwiftUI visual feedback | `.result(view: SuccessView())` |
| `OpensIntent` | Chain to another intent | `.result(opensIntent: NextIntent())` |

```swift
// Combined return type
func perform() async throws -> some IntentResult & ReturnsValue<BookEntity> & ProvidesDialog {
    return .result(value: book, dialog: "Added \(book.title) to Library!")
}
```

## Threading

- `perform()` runs on arbitrary background queue by default
- Mark with `@MainActor` for UI operations or main thread access
- Long operations must complete within ~30 seconds or time out

## Error Handling

Custom errors must provide localized messages:

```swift
enum BookIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notFound
    case networkError(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound: return "Book not found"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}
```

Use `AppIntentError` for standard cases:
- `.insufficientAccount` - Needs sign-in
- `.entityNotFound` - Entity missing
- `.needsValue` - Parameter required

## iOS 17+ Protocols

**ForegroundContinuableIntent**: Continue in app with custom UI
```swift
throw needsToContinueInForegroundError()  // Stop and require user action
try await requestToContinueInForeground()  // Continue with user input
```

**ProgressReportingIntent**: Long-running operations
```swift
func perform() async throws -> some IntentResult {
    progress.totalUnitCount = 100
    for i in 0..<100 {
        progress.completedUnitCount = Int64(i)
        // ... work
    }
    return .result()
}
```

## Critical Anti-Patterns

```swift
// BAD: Heavy work without timeout consideration
func perform() async throws -> some IntentResult {
    let data = try await downloadLargeFile()  // May exceed 30s limit
    return .result()
}

// GOOD: Open app for long operations
static var openAppWhenRun = true
func perform() async throws -> some IntentResult {
    // App handles long operation with proper UI
}
```

```swift
// BAD: Generic error without localization
throw NSError(domain: "app", code: 1, userInfo: nil)

// GOOD: Localized error message
throw BookIntentError.notFound
```

```swift
// BAD: UI work without @MainActor
func perform() async throws -> some IntentResult {
    UIApplication.shared.open(url)  // Crashes
}

// GOOD: Mark for main thread
@MainActor
func perform() async throws -> some IntentResult {
    UIApplication.shared.open(url)
}
```

## Review Questions

1. **Does `perform()` complete within 30 seconds?** Long downloads/processing should open app.
2. **Is `@MainActor` used for UI operations?** Intents run on background queues by default.
3. **Do custom errors provide localized messages?** Raw `Error` gives poor Siri feedback.
4. **Is `openAppWhenRun` set appropriately?** Background-capable intents should stay `false`.
5. **Is `isDiscoverable = false` for internal intents?** Widget-only intents shouldn't clutter Shortcuts.
