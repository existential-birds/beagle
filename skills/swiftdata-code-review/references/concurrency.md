# SwiftData Concurrency

## Best Practices

| Practice | Description |
|----------|-------------|
| @ModelActor for background work | Proper thread isolation for SwiftData |
| PersistentIdentifier for cross-actor | Model objects are NOT Sendable |
| Sendable DTOs for data exchange | Create separate types for transfer |
| Task.detached for background | Ensures actor runs off main thread |
| Explicit `save()` in Task | Autosave may not execute in time |
| @Query for display, @ModelActor for mutations | Separate concerns |

## @ModelActor Pattern

```swift
@ModelActor
actor DataHandler {
    func importItems(_ data: [ImportData]) throws {
        for item in data {
            modelContext.insert(Item(name: item.name))
        }
        try modelContext.save()
    }

    func updateItem(id: PersistentIdentifier, name: String) throws {
        guard let item = self[id, as: Item.self] else { return }
        item.name = name
        try modelContext.save()
    }
}
```

## Sendable DTO Pattern

```swift
struct ItemDTO: Sendable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let timestamp: Date
}

@ModelActor
actor DataService {
    func fetchItems() throws -> [ItemDTO] {
        try modelContext.fetch(FetchDescriptor<Item>())
            .map { ItemDTO(id: $0.persistentModelID, name: $0.name, timestamp: $0.timestamp) }
    }
}
```

## Background Actor Creation

```swift
// GOOD: Ensures background execution
Task.detached {
    let handler = DataHandler(modelContainer: container)
    try await handler.importLargeDataset(data)
}

// Factory method alternative
@ModelActor
actor DataService {
    static nonisolated func createBackground(container: ModelContainer) async -> DataService {
        await Task.detached { DataService(modelContainer: container) }.value
    }
}
```

## Critical Anti-Patterns

### Passing Model Objects Between Actors

```swift
// BAD: Model objects are not Sendable
func getItem(id: UUID) throws -> Item {  // Crash or undefined behavior
    try modelContext.fetch(...).first!
}
let item = try await dataHandler.getItem(id: someId)
item.name = "New"  // Wrong thread!

// GOOD: Return DTO or use identifier
func getItemDTO(id: UUID) throws -> ItemDTO { ... }
func updateItem(id: PersistentIdentifier, name: String) throws { ... }
```

### Creating Actor on Main Thread

```swift
// BAD: Actor runs on main thread
@MainActor
func setup() {
    let handler = DataHandler(modelContainer: container)
}

// GOOD: Create off main actor
func setup() async {
    await Task.detached {
        let handler = DataHandler(modelContainer: container)
    }.value
}
```

### Single Actor Bottleneck

```swift
// BAD: All operations serialize
Task { try await sharedHandler.heavyImport1() }
Task { try await sharedHandler.heavyImport2() }  // Waits for import1!

// GOOD: Separate actors for independent work
Task.detached {
    let handler1 = DataHandler(modelContainer: container)
    try await handler1.heavyImport1()
}
Task.detached {
    let handler2 = DataHandler(modelContainer: container)
    try await handler2.heavyImport2()
}
```

### Modifying After Actor Boundary

```swift
// BAD: Retaining models from background
let items = try await backgroundActor.fetchAllItems()  // [Item]
items[0].name = "Changed"  // CRASH - wrong context!

// GOOD: Use identifiers to load locally
let identifier = try await backgroundActor.getItemIdentifier()
await MainActor.run {
    let item = mainContext.model(for: identifier) as? Item
    item?.name = "Changed"
}
```

### Missing @MainActor on Observable

```swift
// BAD: UI updates may happen off main thread
@Observable
class ViewModel {
    var items: [Item] = []
    func load() async {
        items = await dataService.fetchItems()  // May update from background
    }
}

// GOOD: Explicit main actor isolation
@Observable @MainActor
class ViewModel {
    var items: [Item] = []
}
```

## Review Questions

- [ ] Is @ModelActor used for heavy data operations?
- [ ] Are model objects passed between actors? (They shouldn't be)
- [ ] Is Task.detached used for background actor creation?
- [ ] Is explicit `save()` called in Task contexts?
- [ ] Are ViewModels marked @Observable @MainActor?
- [ ] Are Sendable DTOs used for cross-actor data?
- [ ] Could a single actor become a bottleneck?
- [ ] Are PersistentIdentifiers used for cross-context references?
