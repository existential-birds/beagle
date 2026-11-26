---
name: swiftdata-code-review
description: "Reviews SwiftData code for model design, queries, concurrency, and migrations. Use when reviewing .swift files with import SwiftData, @Model, @Query, @ModelActor, or VersionedSchema."
---

# SwiftData Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| `@Model`, `@Attribute`, `#Unique`, `@Relationship`, delete rules | [references/model-design.md](references/model-design.md) |
| `@Query`, `#Predicate`, `FetchDescriptor`, `#Index` | [references/queries.md](references/queries.md) |
| `@ModelActor`, `ModelContext`, background operations, DTOs | [references/concurrency.md](references/concurrency.md) |
| `VersionedSchema`, `MigrationStage`, lightweight/custom | [references/migrations.md](references/migrations.md) |

## Hard gates (before reporting findings)

Run in order; do not assert an issue until the gate for that issue passes.

1. **Scope — pass when:** You have the target `.swift` path(s) and confirmed SwiftData surface in scope (e.g. `import SwiftData`, `@Model`, `@Query`, `@ModelActor`, `VersionedSchema`, or migration types). If none apply, stop or narrow scope with one sentence.
2. **Reference — pass when:** For each checklist area you evaluate (models, queries, concurrency, migrations), you opened the matching `references/*.md` from the Quick Reference table **or** wrote `N/A: no <area> in this review` with a one-line reason.
3. **Evidence & protocol — pass when:** Every finding satisfies `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) and uses the `[FILE:LINE] ISSUE_TITLE` header (line range allowed) from the file you read; no finding without a cite.
4. **Report — pass when:** Findings list cites first (or inline) using `[FILE:LINE] ISSUE_TITLE`, then severity or checklist grouping—no uncited assertions.

## Review Checklist

- [ ] Models marked `final` on iOS 17–18 (or when inheritance is not intended; iOS 26+ supports `@Model` subclassing)
- [ ] `@Relationship` decorator on ONE side only (not both)
- [ ] Delete rules explicitly set (not relying on default `.nullify`)
- [ ] Relationships initialized to empty arrays (`= []`), not default model objects
- [ ] No `@Attribute(.unique)` or `#Unique` (iOS 18+) if CloudKit sync is enabled
- [ ] Batch operations used for bulk inserts (`append(contentsOf:)`)
- [ ] `@Query` not loading thousands of items on main thread
- [ ] External values in predicates captured in local variables (including inside `init()`)
- [ ] Scalar comparisons in predicates (not object references)
- [ ] `@ModelActor` used for background operations (created off `@MainActor`)
- [ ] `PersistentIdentifier` or `Sendable` DTOs used to pass data between actors (never `@Model` instances)
- [ ] `VersionedSchema` defined for each shipped version and `MigrationPlan` passed to `ModelContainer`

## When to Load References

- Reviewing `@Model`, `#Unique`, or relationships -> [references/model-design.md](references/model-design.md)
- Reviewing `@Query`, `#Predicate`, or `#Index` -> [references/queries.md](references/queries.md)
- Reviewing `@ModelActor` or background work -> [references/concurrency.md](references/concurrency.md)
- Reviewing schema changes or migrations -> [references/migrations.md](references/migrations.md)

## Review Questions

1. Could this relationship assignment cause NULL foreign keys?
2. Is `@Relationship` on both sides creating circular references?
3. Could this `@Query` block the main thread with large datasets?
4. Are `@Model` objects being passed across actor boundaries instead of `PersistentIdentifier` or `Sendable` DTOs?
5. Would schema changes require a `VersionedSchema` and `SchemaMigrationPlan`?
