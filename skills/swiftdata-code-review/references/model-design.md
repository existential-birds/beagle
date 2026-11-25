# SwiftData Model Design

## Best Practices

| Practice | Description |
|----------|-------------|
| Mark models `final` on iOS 17–18 | Subclassing `@Model` is unsupported on iOS 17–18 (crashes at runtime); iOS 26+ supports `@Model` inheritance, so still default to `final` unless inheritance is intended |
| Explicit initializers | Required if any stored property lacks a default value; optional when all properties have defaults, though explicit `init` avoids `@Model` macro ambiguities |
| `var` for relationships | `let` causes runtime crashes |
| Avoid `description` property | Conflicts with `CustomStringConvertible` / backing metadata; use `details` or `summary` |
| `@Relationship` on ONE side | Decorating both sides causes circular reference errors |
| Explicit delete rules | Don't rely on implicit default `.nullify` |
| Optional relationships | Non-optional to-one relationship with `.nullify` crashes on deletion |
| Empty array init | `= []` not default model objects |
| Batch operations | `append(contentsOf:)` not individual `append()` in loops |

## `@Attribute` Options & `#Unique`

| Option / Macro | When to Use |
|----------------|-------------|
| `@Attribute(.unique)` | Single-property natural identifier (NOT compatible with CloudKit) |
| `#Unique<Model>([\.a, \.b])` | iOS 18+ compound uniqueness constraint across multiple properties (NOT compatible with CloudKit) |
| `@Attribute(.externalStorage)` | Large binary data (images, files) |
| `@Attribute(.spotlight)` | User-searchable text content |
| `@Attribute(.transformable)` | Custom types needing `ValueTransformer` serialization |
| `@Attribute(.allowsCloudEncryption)` | Sensitive synced data |
| `@Attribute(.transient)` | Computed/cached values not persisted |

```swift
// iOS 18+ compound uniqueness constraint
@Model
final class User {
    #Unique<User>([\.email], [\.orgID, \.handle])
    var email: String
    var orgID: String
    var handle: String

    init(email: String, orgID: String, handle: String) {
        self.email = email
        self.orgID = orgID
        self.handle = handle
    }
}
```

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
@Model final class Student {
    @Relationship(inverse: \TestResult.student) var testResults: [TestResult] = []
}
@Model final class TestResult {
    @Relationship(inverse: \Student.testResults) var student: Student?
}

// GOOD: @Relationship on one side only
@Model final class Student {
    @Relationship(deleteRule: .cascade, inverse: \TestResult.student)
    var testResults: [TestResult] = []
}
@Model final class TestResult {
    var student: Student?  // No decorator
}
```

### Assignment in Initializer

```swift
// BAD: Foreign keys become NULL
init(floors: [Floor]) {
    self.floors = floors  // Bypasses tracking!
}

// GOOD: Use append after initialization/insertion
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
let tags = (0..<1000).map { Tag(name: "\($0)") }
item.tags.append(contentsOf: tags)
```

### Arrays for Searchable Data

```swift
// BAD: Stored as blob, not queryable via #Predicate
var tags: [String]

// GOOD: Relationship model
@Relationship(deleteRule: .cascade) var tags: [Tag] = []
```

### Unique Constraints with CloudKit

```swift
// BAD: Breaks CloudKit sync (applies to both @Attribute(.unique) and #Unique)
@Attribute(.unique) var email: String

// GOOD: Handle uniqueness programmatically when syncing with CloudKit
var email: String
```

## Review Questions

- [ ] Is the model marked `final` (required on iOS 17–18; recommended default unless iOS 26+ inheritance is intended)?
- [ ] Do properties without defaults have an explicit initializer?
- [ ] Are relationships `var`, not `let`?
- [ ] Is `@Relationship` on only ONE side of bidirectional relationships?
- [ ] Does delete rule match optionality?
- [ ] Are to-many relationships initialized to `= []`?
- [ ] Are batch operations used for bulk additions?
- [ ] If using CloudKit, are `.unique` and `#Unique` avoided?
