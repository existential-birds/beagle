# SwiftData Queries

## Best Practices

| Practice | Description |
|----------|-------------|
| Local variables for external values | Copy `Date.now` before using in predicate |
| Compare scalars, not objects | Use `id` (UUID), not object references |
| Restrictive checks first | Most selective conditions first |
| `localizedStandardContains()` | Case-insensitive text search |
| `starts(with:)` | `hasPrefix()` is NOT supported |
| `fetchCount()` for counts | Never fetch array just for `.count` |
| `fetchLimit`/`fetchOffset` | Pagination for large datasets |
| #Index for filtered properties | iOS 18+ performance optimization |

## @Query Patterns

```swift
// Static query
@Query var items: [Item]

// Sorted query
@Query(sort: \Item.timestamp, order: .reverse) var items: [Item]

// Multi-field sort
@Query(sort: [SortDescriptor(\Item.priority, order: .reverse),
              SortDescriptor(\Item.name)]) var items: [Item]

// Dynamic filtering in init
init(showCompleted: Bool) {
    let completed = showCompleted  // Capture external value
    _items = Query(filter: #Predicate<Item> { item in
        completed || !item.isCompleted
    })
}
```

## FetchDescriptor Patterns

```swift
var descriptor = FetchDescriptor<Item>(
    predicate: #Predicate { $0.createdAt > cutoffDate },
    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
)
descriptor.fetchLimit = 50
descriptor.fetchOffset = page * 50
descriptor.propertiesToFetch = [\.id, \.title]

let count = try context.fetchCount(descriptor)  // Count without fetching
let items = try context.fetch(descriptor)
```

## #Index (iOS 18+)

```swift
@Model final class Order {
    #Index<Order>(
        [\.status],              // Filter by status
        [\.createdAt],           // Sort by date
        [\.status, \.createdAt]  // Compound index
    )
    var status: String
    var createdAt: Date
}
```

## Critical Anti-Patterns

### External Values Directly in @Query

```swift
// BAD: Date.now evaluated at macro expansion
@Query(filter: #Predicate<Event> { $0.date > Date.now })
var events: [Event]

// GOOD: Capture in local variable
static var now: Date { Date.now }
@Query(filter: #Predicate<Event> { $0.date > now })
var events: [Event]
```

### Object Comparison in Predicate

```swift
// BAD: Runtime crash
let predicate = #Predicate<Post> { $0.author == selectedUser }

// GOOD: Compare identifier
let userId = selectedUser.id
let predicate = #Predicate<Post> { $0.author.id == userId }
```

### Unsupported String Methods

```swift
// BAD: These crash
item.name.hasPrefix("A")     // Use starts(with:)
item.name.hasSuffix("z")     // Not supported
item.name.uppercased()       // Not translatable

// GOOD: Supported methods
item.name.starts(with: "A")
item.name.localizedStandardContains("test")
```

### Wrong Boolean Comparison

```swift
// BAD: Runtime crash
#Predicate<Movie> { $0.cast.isEmpty == false }

// GOOD: Negation operator
#Predicate<Movie> { !$0.cast.isEmpty }
```

### Fetching Just to Count

```swift
// BAD: Loads all objects into memory
let count = try context.fetch(FetchDescriptor<Item>()).count

// GOOD: Dedicated count method
let count = try context.fetchCount(FetchDescriptor<Item>())
```

### Heavy @Query on Main Thread

```swift
// BAD: Freezes UI
@Query var allPhotos: [Photo]  // 10,000+ items

// GOOD: Pagination in view model
var descriptor = FetchDescriptor<Photo>()
descriptor.fetchLimit = 50
descriptor.fetchOffset = offset
```

## Review Questions

- [ ] Is @Query loading only what the view needs?
- [ ] Are external values captured in local variables?
- [ ] Are comparisons using scalars, not object references?
- [ ] Are string methods limited to supported ones?
- [ ] Is `!isEmpty` used instead of `isEmpty == false`?
- [ ] Is `fetchCount()` used instead of fetching for counts?
- [ ] Are `fetchLimit`/`fetchOffset` used for pagination?
- [ ] Are frequently filtered properties indexed (iOS 18+)?
