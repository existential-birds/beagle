# SwiftData Model Design

## Best Practices

| Practice | Description |
|----------|-------------|
| Mark models `final` | Subclassing causes runtime crashes |
| Explicit initializers | Required even with default values |
| `var` for relationships | `let` causes runtime crashes |
| Avoid `description` property | Reserved word; use `details` or `content` |
| @Relationship on ONE side | Both sides causes circular reference errors |
| Explicit delete rules | Don't rely on default `.nullify` |
| Optional relationships | Non-optional with `.nullify` crashes |
| Empty array init | `= []` not default objects |
| Batch operations | `append(contentsOf:)` not individual `append()` |

## @Attribute Options

| Option | When to Use |
|--------|-------------|
| `.unique` | Natural identifiers (NOT with CloudKit) |
| `.externalStorage` | Large binary data (images, files) |
| `.spotlight` | User-searchable text content |
| `.transformable` | Custom types needing serialization |
| `.allowsCloudEncryption` | Sensitive synced data |
| `.transient` | Computed/cached values |

## Delete Rules

```swift
@Relationship(deleteRule: .cascade)    // Deletes children (owned relationships)
@Relationship(deleteRule: .nullify)    // Sets to nil (default, fragile)
@Relationship(deleteRule: .deny)       // Prevents deletion if children exist
@Relationship(deleteRule: .noAction)   // Does nothing (dangerous!)
```

## Critical Anti-Patterns

### Decorating Both Sides of Relationship

```swift
// BAD: Circular reference error
@Model class Student {
    @Relationship(inverse: \TestResult.student) var testResults: [TestResult]
}
@Model class TestResult {
    @Relationship(inverse: \Student.testResults) var student: Student?
}

// GOOD: @Relationship on one side only
@Model class Student {
    @Relationship(deleteRule: .cascade, inverse: \TestResult.student)
    var testResults: [TestResult] = []
}
@Model class TestResult {
    var student: Student?  // No decorator
}
```

### Assignment in Initializer

```swift
// BAD: Foreign keys become NULL
init(floors: [Floor]) {
    self.floors = floors  // Bypasses tracking!
}

// GOOD: Use append
init(floors: [Floor]) {
    self.floors.append(contentsOf: floors)
}
```

### Default Values for Relationships

```swift
// BAD: Runtime crash
var tag: Tag = Tag(name: "default")

// GOOD: Optional or set after insertion
var tag: Tag?
```

### Individual Appends in Loop

```swift
// BAD: 700x slower than Core Data
for i in 0..<1000 {
    item.tags.append(Tag(name: "\(i)"))
}

// GOOD: Batch operation
var tags = (0..<1000).map { Tag(name: "\($0)") }
item.tags.append(contentsOf: tags)
```

### Arrays for Searchable Data

```swift
// BAD: Stored as blob, not searchable
var tags: [String]

// GOOD: Relationship model
@Relationship(deleteRule: .cascade) var tags: [Tag] = []
```

### Unique with CloudKit

```swift
// BAD: Breaks CloudKit sync
@Attribute(.unique) var email: String

// GOOD: Handle uniqueness programmatically
var email: String
```

## Review Questions

- [ ] Is the model marked `final`?
- [ ] Does it have an explicit initializer?
- [ ] Are relationships `var`, not `let`?
- [ ] Is @Relationship on only ONE side of bidirectional relationships?
- [ ] Does delete rule match optionality?
- [ ] Are relationships initialized to `= []`?
- [ ] Are batch operations used for bulk additions?
- [ ] If using CloudKit, are there any `.unique` attributes?
