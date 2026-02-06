# Parameterized Tests

## Critical Anti-Patterns

### 1. Accidental Cartesian Product

```swift
// BAD - Creates 25 tests (5x5) when you need 5 pairs
@Test(arguments: [18, 30, 50, 70, 80], [77.0, 73, 65, 61, 55])
func verifyNormalHeartRate(age: Int, bpm: Double) { }

// GOOD - Creates exactly 5 paired tests with zip
@Test(arguments: zip([18, 30, 50, 70, 80], [77.0, 73, 65, 61, 55]))
func verifyNormalHeartRate(age: Int, bpm: Double) { }
```

### 2. Logic Mirroring Implementation

```swift
// BAD - Test logic mirrors implementation, masks bugs
@Test(arguments: Day.allCases)
func greeting(day: Day) {
    #expect(greeting(of: day) == "Happy \(day.rawValue)!")
}

// GOOD - Explicit expected values
@Test(arguments: [
    (Day.monday, "Happy Monday!"),
    (Day.tuesday, "Happy Tuesday!")
])
func greeting(day: Day, expected: String) {
    #expect(greeting(of: day) == expected)
}
```

### 3. Silent Drops with zip()

```swift
// BAD - If arrays have different lengths, extras are silently dropped
@Test(arguments: zip(Ingredient.allCases, Dish.allCases))
func cook(_ ingredient: Ingredient, into dish: Dish) { }
// If Ingredient has 5 cases but Dish has 4, one ingredient goes untested!

// GOOD - Explicit array ensures complete coverage
@Test(arguments: [
    (Ingredient.rice, Dish.onigiri),
    (Ingredient.potato, Dish.fries),
    (Ingredient.tomato, Dish.salad)
])
func cook(_ ingredient: Ingredient, into dish: Dish) { }
```

### 4. CaseIterable Order Dependency

```swift
// BAD - Breaks if enum cases are reordered
@Test(arguments: zip(Status.allCases, ["P", "A", "C"]))
func statusCode(status: Status, code: String) { }

// GOOD - Explicit mapping immune to reordering
@Test(arguments: [
    (Status.pending, "P"),
    (Status.active, "A"),
    (Status.completed, "C")
])
func statusCode(status: Status, code: String) { }
```

### 5. For-Loops Instead of Parameterized Tests

```swift
// BAD - Stops at first failure, unclear which value failed
@Test func doesNotContainNuts() throws {
    for flavor in [Flavor.vanilla, .chocolate] {
        try #require(!flavor.containsNuts)
    }
}

// GOOD - Each value is independent test case
@Test(arguments: [Flavor.vanilla, .chocolate])
func doesNotContainNuts(flavor: Flavor) throws {
    try #require(!flavor.containsNuts)
}
```

### 6. Missing .serialized for Shared Resources

```swift
// BAD - Random failures when server limits connections
@Test(arguments: [1, 2, 3, 4, 5])
func uploadFile(id: Int) async {
    await server.upload(fileId: id)
}

// GOOD - Sequential execution for resource-constrained tests
@Test(.serialized, arguments: [1, 2, 3, 4, 5])
func uploadFile(id: Int) async {
    await server.upload(fileId: id)
}
```

## Best Practices

- **Use explicit tuple arrays** over `zip(allCases, allCases)` for clarity
- **Use `zip()`** only when intentionally pairing two sequences
- **Prefer `#expect`** over `#require` in parameterized tests to see all failures
- **Implement `CustomTestStringConvertible`** for readable test names
- **Use `.serialized`** when tests share limited resources

## Available Traits

| Trait | Purpose |
|-------|---------|
| `.disabled(_:)` | Skip with explanation |
| `.disabled(if:_:)` | Conditional skip |
| `.enabled(if:)` | Execute only when condition met |
| `.bug(_:)` | Link to bug tracker |
| `.timeLimit(_:)` | Set max runtime (per test case) |
| `.serialized` | Force sequential execution |
| `.tags(_:)` | Classify for selective execution |

## Review Questions

1. Are multi-argument tests using `zip()` for pairs, or accidentally creating Cartesian products?
2. Do parameterized tests use explicit expected values, or mirror implementation logic?
3. Could unequal-length `zip()` silently drop test cases?
4. Are tests that access shared resources using `.serialized`?
5. Is `CustomTestStringConvertible` implemented for complex parameter types?
