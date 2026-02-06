# Async Testing

## Critical Anti-Patterns

### 1. Using confirmation for Completion Handlers

```swift
// BAD - Closure exits before callback fires
@Test func badCallbackTest() async {
    await confirmation { confirm in
        networkService.fetch { _ in
            confirm()  // Never reached in time!
        }
    }
}

// GOOD - Use withCheckedContinuation instead
@Test func goodCallbackTest() async {
    await withCheckedContinuation { continuation in
        networkService.fetch { result in
            #expect(result.isSuccess)
            continuation.resume()
        }
    }
}
```

### 2. Unsafe Counter Variables

```swift
// BAD - Counter variable causes Swift 6 concurrency error
@Test func badStreamTest() async {
    var count = 0  // Unsafe in concurrent context
    for await _ in generator {
        count += 1
    }
    #expect(count == 10)
}

// GOOD - Thread-safe confirmation
@Test func goodStreamTest() async {
    await confirmation(expectedCount: 10) { confirm in
        for await _ in generator {
            confirm()
        }
    }
}
```

### 3. Tasks Execute Immediately Assumption

```swift
// BAD - Task hasn't executed yet
@Test func badTaskTest() {
    sut.refreshData()  // Creates Task internally
    #expect(mockRepo.loadCallCount == 1)  // Still 0!
}

// GOOD - Wait for task completion
@Test func goodTaskTest() async {
    mockRepo.stubResponse = .success([])
    let exp = expectation(description: #function)
    mockRepo.didLoad = { exp.fulfill() }
    sut.refreshData()
    await fulfillment(of: [exp], timeout: 1)
    #expect(mockRepo.loadCallCount == 1)
}
```

### 4. Using sleep() in Tests

```swift
// BAD - Slow, flaky, arbitrary timing
@Test func badSleepTest() async throws {
    startLongOperation()
    try await Task.sleep(for: .seconds(2))  // Arbitrary delay
    #expect(operationCompleted)
}

// GOOD - Use proper async/await or confirmations
@Test func goodAsyncTest() async throws {
    let result = try await performOperation()
    #expect(result.isSuccess)
}
```

### 5. Blocking with DispatchSemaphore/DispatchGroup

```swift
// BAD - Risk of deadlock, especially on main thread
@Test func badBlockingTest() async {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await asyncOperation()
        semaphore.signal()
    }
    semaphore.wait()  // Deadlock risk!
}

// GOOD - Use structured async/await
@Test func goodAsyncTest() async {
    await asyncOperation()
    #expect(result.isSuccess)
}
```

## confirmation API Usage

The `confirmation` API verifies callbacks/events occur a specific number of times.

```swift
// Default: expects exactly one confirmation
await confirmation { confirm in
    for await event in eventStream {
        confirm()
    }
}

// Custom count
await confirmation(expectedCount: 10) { confirm in
    for await _ in generator {
        confirm()
    }
}

// Verify something never happens
await confirmation(expectedCount: 0) { confirm in
    // If confirm() is called, test fails
}
```

**Critical**: All `confirm()` calls MUST execute before the `confirmation` closure returns (eager evaluation). Unlike XCTest's `XCTestExpectation` with `fulfillment(of:timeout:)`, confirmations do not suspend waiting for future events.

For completion-handler APIs:
- **Option A**: Convert to async/await and `await` the async work inside the confirmation closure
- **Option B**: Use `withCheckedContinuation` (shown in Anti-Pattern #1 above)
- **Option C**: For callback-style tests that need waiting, use XCTest's `fulfillment(of:timeout:)` instead

## Time Limits

```swift
// Test-level time limit
@Test(.timeLimit(.minutes(1)))
func loadNames() async {
    let viewModel = ViewModel()
    await viewModel.loadNames()
    #expect(viewModel.names.isEmpty == false)
}

// Suite-level (shorter of suite/test wins)
@Suite(.timeLimit(.minutes(2)))
struct NetworkTests {
    @Test(.timeLimit(.minutes(1)))  // 1 minute wins
    func fastTest() async { }
}
```

## Best Practices

- **Use async/await directly** when available
- **Use `confirmation`** for async sequences and streams
- **Use `withCheckedContinuation`** for completion handler APIs
- **Store Task references** for testing unstructured concurrency
- **Use `withKnownIssue`** for flaky tests
- **Use `.timeLimit`** trait for tests with external dependencies

## Review Questions

1. Are completion handlers being tested with `withCheckedContinuation`, not `confirmation`?
2. Are async sequences tested with `confirmation(expectedCount:)`?
3. Are mutable counters in concurrent contexts replaced with confirmations?
4. Are unstructured Tasks being awaited before assertions?
5. Is `sleep()` being used instead of proper async patterns?
