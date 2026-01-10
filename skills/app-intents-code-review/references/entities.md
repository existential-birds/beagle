# Entities and Queries

## AppEntity Protocol

Represents domain objects for use in App Intents:

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

Best for: Enums, small fixed sets (<100 items)

## EntityPropertyQuery Protocol

For large datasets with property-based filtering:

```swift
struct BookQuery: EntityPropertyQuery {
    static var sortingOptions = SortingOptions {
        SortableBy(\BookEntity.$title)
        SortableBy(\BookEntity.$dateAdded)
    }

    static var properties = QueryProperties {
        Property(\BookEntity.$title) { EqualTo, Contains }
        Property(\BookEntity.$author) { EqualTo, Contains }
    }

    func entities(matching predicates: QueryPredicate<BookEntity>,
                  mode: ComparatorMode,
                  sortedBy: [EntitySortingOptions<BookEntity>],
                  limit: Int?) async throws -> [BookEntity] {
        // Build NSPredicate from QueryPredicate
    }
}
```

## iOS 18 Entity Features

**IndexedEntity**: Spotlight semantic search
```swift
struct BookEntity: AppEntity, IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet()
        attrs.displayName = title
        attrs.contentDescription = summary
        return attrs
    }
}
```

**URLRepresentable**: Deep linking
```swift
struct BookEntity: AppEntity, URLRepresentable {
    static var urlRepresentation: URLRepresentation {
        "myapp://book/\(.id)"
    }
}
```

## SwiftData Integration

```swift
// BAD: Passing model directly (not Sendable)
func perform() async throws -> some IntentResult {
    let book = fetchBook()  // @Model type
    processBook(book)  // Data race risk
}

// GOOD: Pass by ID, fetch in context
func perform() async throws -> some IntentResult {
    let bookID = persistentModelID
    let context = ModelContext(container)
    let book = context.model(for: bookID) as? Book
}
```

## Dependency Injection Limitation

`@Dependency` and `@AppDependency` **do not work** in Siri/Shortcuts context. Queries must be self-contained:

```swift
// BAD: Dependency injection in query
struct BookQuery: EntityQuery {
    @Dependency var database: Database  // nil in Siri

    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        database.books(for: identifiers)  // Crashes
    }
}

// GOOD: Self-contained query
struct BookQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        Database.shared.books(for: identifiers)  // Singleton access
    }
}
```

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
    Database.shared.recentBooks.prefix(10)
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
4. **Is the query self-contained?** `@Dependency` fails in Siri/Shortcuts context.
5. **Is `EnumerableEntityQuery` used only for small sets?** Large sets should use `EntityPropertyQuery`.
