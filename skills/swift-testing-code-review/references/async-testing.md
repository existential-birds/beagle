# Async Testing

## Critical Anti-Patterns

### 1. Using `confirmation` for Completion Handlers

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
    let result = await withCheckedContinuation { continuation in
        networkService.fetch { result in
            continuation.resume(returning: result)
        }
    }
    #expect(result.isSuccess)
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

### 3. Assuming Unstructured Tasks Execute Immediately (or Mixing XCTest Expectations)

Never use `XCTestExpectation` / `fulfillment(of:timeout:)` inside a Swift Testing `@Test` function—use `withCheckedContinuation` or expose/await the underlying async method or `Task`.

```swift
// BAD - Task hasn't executed yet (and XCTest expectation/fulfillment is invalid in @Test)
@Test func badTaskTest() {
    sut.refreshData()  // Creates Task internally
    #expect(mockRepo.loadCallCount == 1)  // Still 0!
}

// GOOD - Await completion via continuation (or await the returned Task directly)
@Test func goodTaskTest() async {
    mockRepo.stubResponse = .success([])
    await withCheckedContinuation { continuation in
        mockRepo.didLoad = { continuation.resume() }
        sut.refreshData()
    }
    #expect(mockRepo.loadCallCount == 1)
}
```

### 4. Using `sleep()` in Tests

```swift
// BAD - Slow, flaky, arbitrary timing
@Test func badSleepTest() async throws {
    startLongOperation()
    try await Task.sleep(for: .seconds(2))  // Arbitrary delay
    #expect(operationCompleted)
}

// GOOD - Await structured async work directly
@Test func goodAsyncTest() async throws {
    let result = try await performOperation()
    #expect(result.isSuccess)
}
```

### 5. Blocking with `DispatchSemaphore`/`DispatchGroup`

```swift
// BAD - Risk of deadlock, especially on cooperative thread pool / main thread
@Test func badBlockingTest() async {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await asyncOperation()
        semaphore.signal()
    }
    semaphore.wait()  // Deadlock risk!
}

// GOOD - Use structured async/await
@Test func goodStructuredAsyncTest() async {
    let result = await asyncOperation()
    #expect(result.isSuccess)
}
```

## `confirmation` API Usage

The `confirmation` API verifies callbacks/events occur a specific number of times while the closure is running.

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

**Critical**: All `confirm()` calls MUST execute before the `confirmation` closure returns (eager evaluation). Confirmations do not suspend waiting for future events.

For completion-handler APIs:
- **Option A**: Wrap in an `async` helper or `await` the async work inside the `confirmation` closure
- **Option B**: Use `withCheckedContinuation` / `withCheckedThrowingContinuation` (shown in Anti-Pattern #1)
- **Option C**: If an API genuinely requires `XCTestExpectation` / `fulfillment(of:timeout:)`, keep that test in an `XCTestCase` rather than mixing it into `@Test`

## Exit Tests (`#expect(processExitsWith:)`, Swift 6.2+)

Use exit tests to verify `precondition`, `assertionFailure`, or `fatalError` without crashing the test runner—Swift Testing runs the closure inside an isolated child process.

```swift
@Test func preconditionFailsOnInvalidIndex() async {
    await #expect(processExitsWith: .failure) {
        precondition(false, "Index out of range")
    }
}
```

*(Note: Exit tests require a host OS that supports spawning child processes—available on macOS, Linux, and Windows; not supported on iOS/watchOS/tvOS/visionOS simulators or devices.)*

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
- **Use `confirmation`** for `AsyncSequence` streams and synchronous callbacks
- **Use `withCheckedContinuation`** for asynchronous completion-handler APIs
- **Use `#expect(processExitsWith:)`** (Swift 6.2+) for fatal precondition checks on supported platforms
- **Use `withKnownIssue`** for known flaky/unfixed behavior
- **Use `.timeLimit`** trait for tests with external or slow async operations

## Review Questions

1. Are completion handlers being tested with `withCheckedContinuation`, not `confirmation` or `XCTestExpectation`?
2. Are async sequences tested with `confirmation(expectedCount:)`?
3. Are mutable counters in concurrent contexts replaced with `confirmation`?
4. Are unstructured `Task`s awaited before assertions?
5. Is `Task.sleep` being used instead of proper async synchronization?
