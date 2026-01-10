# Parameters

## @Parameter Property Wrapper

Declares user-configurable inputs:

```swift
struct OpenBook: AppIntent {
    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(title: "Page", default: 1)
    var page: Int

    @Parameter(title: "Read Aloud")
    var readAloud: Bool?  // Optional = not required
}
```

| Option | Purpose |
|--------|---------|
| `title` | Localized display name (required) |
| `default` | Default value for parameter |
| `description` | Help text for parameter |
| `requestValueDialog` | Prompt when requesting value |

## Supported Types

- **Primitives**: `Int`, `Double`, `Bool`, `String`, `Date`, `URL`
- **Collections**: `[T]` where T is supported
- **Enums**: Must conform to `AppEnum`
- **Entities**: Must conform to `AppEntity`
- **Files**: `IntentFile` for file handling

## AppEnum for Fixed Values

```swift
enum Priority: String, AppEnum {
    case low, medium, high

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"
    static var caseDisplayRepresentations: [Priority: DisplayRepresentation] = [
        .low: "Low",
        .medium: "Medium",
        .high: "High"
    ]
}
```

## ParameterSummary

Natural language description with embedded parameters:

```swift
static var parameterSummary: some ParameterSummary {
    Summary("Open \(\.$book) at page \(\.$page)")
}
```

iOS 17+: Conditional summaries based on widget family:
```swift
static var parameterSummary: some ParameterSummary {
    When(\.$includeDetails, .equalTo, true) {
        Summary("Show \(\.$book) with details")
    } otherwise: {
        Summary("Show \(\.$book)")
    }
}
```

## Dynamic Options

Provide runtime-computed options:

```swift
struct BookParameter: DynamicOptionsProvider {
    func results() async throws -> [BookEntity] {
        Database.shared.availableBooks
    }

    func defaultResult() async -> BookEntity? {
        Database.shared.lastOpenedBook
    }
}

@Parameter(title: "Book", optionsProvider: BookParameter())
var book: BookEntity
```

## @IntentParameterDependency (iOS 17+)

Access other parameters in options provider:

```swift
struct ChapterParameter: DynamicOptionsProvider {
    @IntentParameterDependency<OpenBook>(\.book)
    var bookDependency

    func results() async throws -> [ChapterEntity] {
        guard let book = bookDependency?.book else { return [] }
        return book.chapters
    }
}
```

**Warning**: `@IntentParameterDependency` crashes on iOS 16. Guard with availability:
```swift
if #available(iOS 17, *) {
    // Use dependency
}
```

## User Interaction

Request values or disambiguation during `perform()`:

```swift
func perform() async throws -> some IntentResult {
    // Request missing value
    let book = try await $book.requestValue("Which book?")

    // Disambiguation from options
    let chapter = try await $chapter.requestDisambiguation(
        among: book.chapters,
        dialog: "Which chapter?"
    )

    // Confirmation
    let confirmed = try await $book.requestConfirmation(
        for: book,
        dialog: "Open \(book.title)?"
    )
}
```

**Note**: User cancellation throws an error - handle gracefully.

## Validation

Validate parameters before use:

```swift
func perform() async throws -> some IntentResult {
    guard page > 0 && page <= book.pageCount else {
        throw BookIntentError.invalidPage
    }
    // ...
}
```

For complex validation, use `requestValue()` with specific prompts.

## Critical Anti-Patterns

```swift
// BAD: Non-optional parameter without default
@Parameter(title: "Count")
var count: Int  // Required with no default - user must always provide

// GOOD: Optional or has default
@Parameter(title: "Count", default: 10)
var count: Int
```

```swift
// BAD: @IntentParameterDependency on iOS 16 target
@IntentParameterDependency<MyIntent>(\.param)
var dependency  // Crashes on iOS 16

// GOOD: Guard with availability
@available(iOS 17, *)
@IntentParameterDependency<MyIntent>(\.param)
var dependency
```

```swift
// BAD: Ignoring requestConfirmation cancellation
func perform() async throws -> some IntentResult {
    try await $action.requestConfirmation(for: action)  // Throws on cancel
    performAction()  // Runs even if canceled?
}

// GOOD: Handle cancellation
func perform() async throws -> some IntentResult {
    do {
        try await $action.requestConfirmation(for: action)
        performAction()
    } catch {
        // User canceled - graceful exit
        return .result()
    }
}
```

```swift
// BAD: Missing defaultResult in DynamicOptionsProvider
struct BookParameter: DynamicOptionsProvider {
    func results() async throws -> [BookEntity] { ... }
    // No defaultResult - non-optional params fail without explicit selection
}

// GOOD: Provide default
struct BookParameter: DynamicOptionsProvider {
    func results() async throws -> [BookEntity] { ... }
    func defaultResult() async -> BookEntity? {
        Database.shared.lastOpenedBook
    }
}
```

## Review Questions

1. **Do non-optional parameters have defaults or use `requestValue()`?**
2. **Is `@IntentParameterDependency` guarded for iOS 17+?** Crashes on iOS 16.
3. **Are user cancellations from `requestConfirmation` handled?** They throw errors.
4. **Does `DynamicOptionsProvider` implement `defaultResult()`?** Required for non-optional params.
5. **Are parameter summaries written as natural sentences?**
