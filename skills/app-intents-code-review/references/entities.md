# Entities and Queries

## AppEntity Protocol

Represents domain objects for use in App Intents. `AppEntity` inherits `Sendable`, so stored properties and `@Property` types must be `Sendable`:

```swift
struct BookEntity: AppEntity, Identifiable {
    var id: UUID  // Must be stable and persistent

    @Property(title: "Title")
    var title: String

    @Property(title: "Author")
    var author: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(author)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"
    static var defaultQuery = BookQuery()
}
```

| Requirement | Purpose |
|-------------|---------|
| `id` | Stable identifier for persistence across sessions |
| `displayRepresentation` | How entity appears in Siri/Shortcuts UI |
| `typeDisplayRepresentation` | Human-readable type name ("Book", "Task") |
| `defaultQuery` | Associated query for lookups |

## EntityQuery Protocol

Basic lookup by identifier:

```swift
struct BookQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        identifiers.compactMap { Database.shared.book(for: $0) }
    }
}
```

## EntityStringQuery Protocol

Required for Siri voice input with free-form search:

```swift
struct BookQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        identifiers.compactMap { Database.shared.book(for: $0) }
    }

    func suggestedEntities() async throws -> [BookEntity] {
        Database.shared.recentBooks  // Shown in picker UI
    }

    func entities(matching string: String) async throws -> [BookEntity] {
        Database.shared.books.filter { $0.title.localizedCaseInsensitiveContains(string) }
    }
}
```

**Critical**: Using plain `EntityQuery` with Siri causes infinite parameter request loops. Use `EntityStringQuery` for voice-driven disambiguation.

## EnumerableEntityQuery Protocol (iOS 17+)

For small datasets, return all entities and let system filter:

```swift
struct ShelfQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [ShelfEntity] {
        Shelf.allCases.map { ShelfEntity($0) }
    }
}
```

Best for: Enums, small fixed sets (<100 items).

## EntityPropertyQuery Protocol

For large datasets with property-based filtering (commonly surfaced via "Find" actions in Shortcuts):

```swift
struct BookQuery: EntityPropertyQuery {
    typealias Entity = BookEntity

    static var sortingOptions = SortingOptions {
        SortableBy(\BookEntity.$title)
        SortableBy(\BookEntity.$dateAdded)
    }

    static var properties = QueryProperties {
        Property(\BookEntity.$title) {
            EqualToComparator { value in
                NSPredicate(format: "title == %@", value)
            }
            ContainsComparator { value in
                NSPredicate(format: "title CONTAINS[c] %@", value)
            }
        }
        Property(\BookEntity.$author) {
            EqualToComparator { value in
                NSPredicate(format: "author == %@", value)
            }
        }
    }

    func entities(
        matching comparators: [NSPredicate],
        mode: ComparatorMode,
        sortedBy: [Sort<BookEntity>],
        limit: Int?
    ) async throws -> [BookEntity] {
        Database.shared.fetchBooks(
            matching: comparators,
            matchAll: mode == .and,
            sorts: sortedBy,
            limit: limit
        )
    }
}
```

## iOS 18 Entity Features

**IndexedEntity**: Spotlight semantic search. Map properties to `CSSearchableItemAttributeSet` keys with `@Property(indexingKey:)` or `@ComputedProperty(indexingKey:)` (use `attributeSet` only when supplying additional Core Spotlight metadata):

```swift
import CoreSpotlight

struct BookEntity: AppEntity, IndexedEntity {
    var id: UUID

    @Property(title: "Title", indexingKey: \.title)
    var title: String

    var summary: String

    @ComputedProperty(indexingKey: \.contentDescription)
    var spotlightDescription: String {
        summary
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"
    static var defaultQuery = BookQuery()
}
```

**URLRepresentableEntity**: Universal Links (`https://...` required; custom URL schemes are not supported):

```swift
struct BookEntity: AppEntity, URLRepresentableEntity {
    var id: UUID

    @Property(title: "Title")
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"
    static var defaultQuery = BookQuery()

    static var urlRepresentation: URLRepresentation {
        "https://example.com/book/\(.id)"
    }
}
```

## SwiftData Integration

`@Model` classes are not `Sendable`. Pass `PersistentIdentifier` (`persistentModelID`) and fetch inside a fresh `ModelContext`:

```swift
// BAD: Passing model directly (not Sendable)
func perform() async throws -> some IntentResult {
    let book = fetchBook()  // @Model type
    processBook(book)  // Data race risk
}

// GOOD: Pass Sendable identifier, fetch in context
func perform() async throws -> some IntentResult {
    let bookID = book.persistentModelID
    let context = ModelContext(container)
    let book = context.model(for: bookID) as? Book
    // ...
    return .result()
}
```

## Dependency Injection (`@Dependency` & `AppDependencyManager`)

`@Dependency` works in both `AppIntent` and `EntityQuery` **only if** the dependency is registered early in `App.init()` (or your App Intents extension entry point) via `AppDependencyManager.shared.add(dependency:)`. Accessing an unregistered `@Dependency` traps at runtime.

```swift
// BAD: Using @Dependency without registering in AppDependencyManager
struct BookQuery: EntityQuery {
    @Dependency var database: Database  // Traps if never registered

    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        database.books(for: identifiers)
    }
}

// GOOD: Register dependency in App.init() (runs even on background Siri launch)
@main
struct LibraryApp: App {
    let database = Database()

    init() {
        AppDependencyManager.shared.add(dependency: database)
        LibraryAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct BookQuery: EntityQuery {
    @Dependency var database: Database

    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        database.books(for: identifiers)
    }
}
```

If intents run inside a separate App Intents extension process, register dependencies in the extension entry point as well and share persistent state via an App Group container.

## Critical Anti-Patterns

```swift
// BAD: Plain EntityQuery with Siri voice input
struct BookQuery: EntityQuery { ... }  // Infinite prompt loop

// GOOD: EntityStringQuery for voice input
struct BookQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [BookEntity] { ... }
}
```

```swift
// BAD: Empty suggested entities
func suggestedEntities() async throws -> [BookEntity] { [] }

// GOOD: Provide reasonable defaults
func suggestedEntities() async throws -> [BookEntity] {
    Array(Database.shared.recentBooks.prefix(10))
}
```

```swift
// BAD: Non-persistent ID
struct BookEntity: AppEntity {
    var id = UUID()  // New ID each time!
}

// GOOD: Stable ID from data source
struct BookEntity: AppEntity {
    let id: UUID  // From database record
}
```

## Review Questions

1. **Is `EntityStringQuery` used for Siri voice input?** Plain `EntityQuery` causes infinite loops.
2. **Does `suggestedEntities()` return useful defaults?** Empty results break disambiguation.
3. **Are entity IDs stable and persistent?** New IDs each instantiation break continuity.
4. **Are `@Dependency` properties registered via `AppDependencyManager.shared.add(dependency:)` in `App.init()`?** Unregistered dependencies crash when invoked by Siri/Shortcuts.
5. **Is `EnumerableEntityQuery` used only for small sets?** Large sets should use `EntityPropertyQuery`.
