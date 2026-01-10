# SwiftData Migrations

## Best Practices

| Practice | Description |
|----------|-------------|
| VersionedSchema from start | Even before shipping, makes future migrations easier |
| Semantic versioning | `Schema.Version(1, 0, 0)` format |
| Typealias for latest | `typealias User = UsersSchemaV2.User` |
| Enums for schema versions | Won't be instantiated directly |
| Stages for ALL versions | Even lightweight ones |
| Chronological order | In `SchemaMigrationPlan.schemas` |
| `@Attribute(originalName:)` | When renaming properties to preserve data |
| Keep originalName annotation | For future installs from old versions |

## VersionedSchema Setup

```swift
enum UsersSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] { [User.self] }

    @Model
    class User {
        var name: String
        init(name: String) { self.name = name }
    }
}

enum UsersSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] { [User.self] }

    @Model
    class User {
        @Attribute(originalName: "name") var fullName: String  // Renamed
        @Attribute(.unique) var email: String  // Added
        init(fullName: String, email: String) { ... }
    }
}

typealias User = UsersSchemaV2.User
```

## Migration Plan

```swift
enum UsersMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [UsersSchemaV1.self, UsersSchemaV2.self]
    }

    static var stages: [MigrationStage] { [migrateV1toV2] }

    // Custom: clean duplicates before adding .unique
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: UsersSchemaV1.self,
        toVersion: UsersSchemaV2.self,
        willMigrate: { context in
            let users = try context.fetch(FetchDescriptor<UsersSchemaV1.User>())
            var seen = Set<String>()
            for user in users where seen.contains(user.email) {
                context.delete(user)
            }
            try context.save()
        },
        didMigrate: nil
    )

    // Lightweight: simple changes
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: UsersSchemaV2.self,
        toVersion: UsersSchemaV3.self
    )
}
```

## ModelContainer Configuration

```swift
let container = try ModelContainer(
    for: User.self,
    migrationPlan: UsersMigrationPlan.self
)
```

## Critical Anti-Patterns

### Renaming Without originalName

```swift
// BAD: Data LOST
var fullName: String  // Was "name", no mapping

// GOOD: Data preserved
@Attribute(originalName: "name") var fullName: String
```

### Adding .unique to Duplicated Data

```swift
// BAD: Crash if duplicates exist
@Attribute(.unique) var email: String

// GOOD: Clean duplicates in willMigrate first
willMigrate: { context in
    // Remove duplicates before schema applies .unique
}
```

### Custom Migrations with CloudKit

```swift
// BAD: Crashes with CloudKit
MigrationStage.custom(willMigrate: { ... }, didMigrate: { ... })

// GOOD: Lightweight only for CloudKit apps
MigrationStage.lightweight(fromVersion:, toVersion:)
// Handle complex logic in app initialization
```

### Wrong Schema in Migration Closure

```swift
// BAD: V2 not available in willMigrate
willMigrate: { context in
    try context.fetch(FetchDescriptor<SchemaV2.User>())  // WRONG
}

// GOOD: V1 in willMigrate, V2 in didMigrate
willMigrate: { context in
    try context.fetch(FetchDescriptor<SchemaV1.User>())  // Correct
}
didMigrate: { context in
    try context.fetch(FetchDescriptor<SchemaV2.User>())  // Correct
}
```

### Missing MigrationPlan

```swift
// BAD: Migration not applied
let container = try ModelContainer(for: User.self)

// GOOD: Migration plan specified
let container = try ModelContainer(
    for: User.self,
    migrationPlan: UsersMigrationPlan.self
)
```

## Lightweight vs Custom

**Lightweight migrations support:**
- Adding properties with default values
- Renaming with `@Attribute(originalName:)`
- Deleting properties
- Adjusting delete rules

**Custom migrations needed for:**
- Data transformation
- Deduplication before `.unique`
- Complex relationship changes
- Default value calculation from existing data

## Review Questions

- [ ] Is every shipped schema wrapped in VersionedSchema?
- [ ] Does each schema have a unique versionIdentifier?
- [ ] Are schemas listed in chronological order?
- [ ] Is there a MigrationStage for each version transition?
- [ ] Is MigrationPlan passed to ModelContainer?
- [ ] Do renamed properties use `@Attribute(originalName:)`?
- [ ] If adding `.unique`, are duplicates handled in willMigrate?
- [ ] Does willMigrate only access old schema models?
- [ ] Is CloudKit enabled? (Custom migrations will crash)
- [ ] Is `context.save()` called in migration closures?
