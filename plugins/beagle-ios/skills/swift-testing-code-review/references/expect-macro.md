# #expect Macro

## Critical Anti-Patterns

### 1. Computing Booleans Outside #expect

```swift
// BAD - Loses expression capture and diagnostic context
let passed = user.age >= 18 && user.hasVerifiedEmail
#expect(passed)
// Failure shows: Expectation failed: passed

// GOOD - Full expression capture
#expect(user.age >= 18, "User must be adult")
#expect(user.hasVerifiedEmail, "Email verification required")
// Failure shows: (user.age → 16) >= 18
```

### 2. Overusing #require Instead of #expect

```swift
// BAD - Stops at first failure, hides other issues
@Test func testUserProfile() throws {
    let user = try #require(fetchUser())
    try #require(user.name == "Alice")  // Stops here if fails
    try #require(user.isActive)          // Never checked
}

// GOOD - #require only for preconditions, #expect for assertions
@Test func testUserProfile() throws {
    let user = try #require(fetchUser())  // Required to proceed
    #expect(user.name == "Alice")  // Soft check - continues
    #expect(user.isActive)          // Also checked
}
```

### 3. Mixing XCTest and Swift Testing

```swift
// BAD - Frameworks incompatible
@Test func testMixedFrameworks() {
    XCTAssertEqual(value, expected)  // WRONG
    #expect(otherValue == expected)
}

// GOOD - Use one framework per test
@Test func testWithSwiftTesting() {
    #expect(value == expected)
    #expect(otherValue == expected)
}
```

### 4. Generic Error Testing

```swift
// BAD - Overly generic, masks specific failures
#expect(throws: (any Error).self) { try validate(input) }

// GOOD - Specific error case
#expect(throws: ValidationError.invalidFormat) { try validate(input) }

// GOOD - Custom validation for associated values
#expect(performing: { try validate(input) }, throws: { error in
    guard let validationError = error as? ValidationError,
          validationError.code == 400 else { return false }
    return true
})
```

### 5. Force Unwrap After nil Check

```swift
// BAD - Assertion followed by force unwrap
#expect(optionalValue != nil)
let value = optionalValue!

// GOOD - Combine unwrap and assertion
let value = try #require(optionalValue)
```

## Best Practices

- **Embed expressions directly** in `#expect` for full diagnostic capture
- **Use `#expect`** for assertions (soft fail, continues), **`#require`** for preconditions (hard fail, stops)
- **Include descriptive messages** when failure reason isn't obvious
- **Test specific error cases** rather than generic `(any Error).self`
- **Implement `CustomTestStringConvertible`** for complex types to improve failure messages

## Migration from XCTest

| XCTest | Swift Testing |
|--------|---------------|
| `XCTAssertTrue(value)` | `#expect(value)` |
| `XCTAssertFalse(value)` | `#expect(!value)` |
| `XCTAssertNil(value)` | `#expect(value == nil)` |
| `XCTAssertNotNil(value)` | `#expect(value != nil)` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTUnwrap(optional)` | `try #require(optional)` |
| `XCTFail(message)` | `Issue.record(message)` |

## Review Questions

1. Are expressions embedded directly in `#expect` for full capture?
2. Is `#require` used only for essential preconditions, not all assertions?
3. Are error tests checking specific error types, not generic `(any Error).self`?
4. Do complex types implement `CustomTestStringConvertible`?
5. Are assertion messages provided when failure reason isn't self-evident?
