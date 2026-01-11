# Test Organization

## Critical Anti-Patterns

### 1. Expecting State Persistence Between Tests

```swift
// BAD - Each test gets fresh instance, state doesn't persist
@Suite(.serialized)
struct StatefulTests {
    var value = 0

    @Test mutating func step1() { value = 42 }
    @Test func step2() { #expect(value == 42) }  // Fails! Fresh instance
}

// GOOD - Use init() for setup
struct Tests {
    let value: Int
    init() { value = 42 }
    @Test func verify() { #expect(value == 42) }
}

// GOOD - Combine into one test for dependent steps
@Test func completeFlow() {
    var value = 0
    value = 42
    #expect(value == 42)
}
```

### 2. Serializing Everything

```swift
// BAD - Slow, defeats parallelism
@Suite(.serialized)
struct AllTests {
    // 200 tests that could run in parallel
}

// GOOD - Only serialize what needs it
struct AllTests {
    struct FastTests { }  // Parallel by default
    @Suite(.serialized) struct DatabaseTests { }  // Only these
}
```

### 3. Incorrect Nested Serialization

```swift
// BAD - Suites run in parallel with each other!
@Suite(.serialized) struct Suite1 { @Test func a() {} }
@Suite(.serialized) struct Suite2 { @Test func b() {} }

// GOOD - Nested under parent
@Suite(.serialized) struct DatabaseSuites {
    @Suite struct Suite1 { @Test func a() {} }
    @Suite struct Suite2 { @Test func b() {} }  // Waits for Suite1
}
```

### 4. Using Static State for Sharing

```swift
// BAD - Race conditions with parallel tests
struct UnsafeTests {
    static var shared = ""

    @Test func create() { Self.shared = "value" }
    @Test func check() { #expect(Self.shared == "value") }  // Race!
}

// GOOD - Fresh instance per test
final class SafeTests {
    let database: Database
    init() throws { database = try Database(path: UUID().uuidString) }
    deinit { try? database.cleanup() }

    @Test func query() { }  // Own database instance
}
```

### 5. Silent Test Skip Without Explanation

```swift
// BAD - No explanation why disabled
@Test(.disabled())
func flakyTest() {}

// GOOD - Reason and bug link
@Test(.disabled("Waiting for backend fix"), .bug("PROJ-123"))
func flakyTest() {}
```

## @Suite Fundamentals

Any type containing `@Test` functions is implicitly a suite. Use explicit `@Suite` for:
- Display names: `@Suite("User Validation Tests")`
- Traits: `@Suite(.serialized)`
- Nested organization

```swift
@Suite("Dessert Tests")
struct DessertTests {
    @Suite struct WarmDesserts {
        @Test func applePieCrustLayers() { }
    }
    @Suite struct ColdDesserts {
        @Test func cheesecakeBakingStrategy() { }
    }
}
```

**Supported types**: `struct` (preferred), `class` (for `deinit` teardown), `actor`
**NOT supported**: `enum` (cannot contain tests directly)

## Tags

Declare tags as extensions on `Tag`:

```swift
extension Tag {
    @Tag static var unitTests: Self
    @Tag static var integrationTests: Self
    @Tag static var networking: Self
}
```

Apply to tests or suites (traits cascade to nested items):

```swift
@Suite(.tags(.database))
struct DatabaseTests {
    @Test func testInsert() { }  // Inherits .database
    @Test(.tags(.critical)) func testTransaction() { }  // .database + .critical
}
```

## Parallel Execution

Swift Testing runs all tests in parallel by default. Key implications:

- Each `@Test` gets its own fresh suite instance
- Global/static state causes race conditions
- Use `.serialized` only when necessary (shared resources, external services)

## Lifecycle

```swift
final class DatabaseServiceTests {
    let sut: DatabaseService
    let tempDirectory: URL

    init() throws {  // Setup - runs before EACH test
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        self.sut = DatabaseService(database: TestDatabase(storageURL: tempDirectory))
    }

    deinit {  // Teardown - runs after EACH test (requires class)
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}
```

## Review Questions

1. Are tests assuming state persists between test functions?
2. Is `.serialized` applied only where necessary, not everywhere?
3. Are sibling `.serialized` suites nested under a parent if they must be mutually exclusive?
4. Is static/global state avoided in tests?
5. Do disabled tests have explanations and bug links?
