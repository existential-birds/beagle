# Combine Error Handling

## Error Types in Combine

Every publisher declares `Publisher<Output, Failure>`. Unlike other reactive frameworks, Combine enforces error types at compile time.

### The `Never` Type
- `Failure == Never` means the publisher can never fail
- Required for `assign(to:on:)` - must convert failable publishers first
- Created by `replaceError(with:)` or `catch` with infallible fallback

### Converting Error Types
```swift
// setFailureType: Never → CustomError
Just("Hello")
    .setFailureType(to: APIError.self)

// mapError: URLError → APIError
urlSession.dataTaskPublisher(for: url)
    .mapError { .networkError($0) }
```

## try* Operators

The `try`-prefixed operators allow throwing but **erase error type to `Swift.Error`**.

| Operator | Preserves Failure Type | Can Throw |
|----------|----------------------|-----------|
| `map` | Yes | No |
| `tryMap` | No (erases to `Error`) | Yes |
| `filter` | Yes | No |
| `tryFilter` | No (erases to `Error`) | Yes |

**Always follow tryMap with mapError:**
```swift
publisher
    .tryMap { try JSONDecoder().decode(User.self, from: $0) }
    .mapError { $0 as? APIError ?? .unknown($0) }
```

## catch vs replaceError

| Aspect | `catch` | `replaceError(with:)` |
|--------|---------|----------------------|
| Returns | New publisher | Single value |
| Can inspect error | Yes | No |
| Post-error values | Multiple possible | One then completes |
| Result Failure type | Depends on fallback | `Never` |

```swift
// replaceError: Simple fallback value
imagePublisher
    .replaceError(with: placeholderImage)

// catch: Inspect error, provide fallback publisher
primaryAPI
    .catch { error -> AnyPublisher<Data, Never> in
        if case .notFound = error {
            return fallbackAPI.replaceError(with: Data())
        }
        return Just(Data()).eraseToAnyPublisher()
    }
```

## Critical Anti-Patterns

### 1. Error Handling in Main Chain Kills Publisher

```swift
// BAD: Main chain dies after first error
searchText
    .flatMap { query in networkRequest(query) }
    .replaceError(with: [])  // Publisher dead after one error!
    .sink { results in ... }

// GOOD: Handle errors inside flatMap
searchText
    .flatMap { query in
        networkRequest(query)
            .replaceError(with: [])  // Inner publisher handles error
    }
    .sink { results in ... }  // Main chain stays alive
```

### 2. Using tryMap Without mapError

```swift
// BAD: Loses specific error type
publisher.tryMap { try decode($0) }
// Failure is now plain Error

// GOOD: Restore error type
publisher.tryMap { try decode($0) }
    .mapError { $0 as? APIError ?? .unknown($0) }
```

### 3. assertNoFailure in Production

```swift
// BAD: Crashes app on network error
networkPublisher
    .assertNoFailure()  // Fatal error!

// GOOD: Handle expected errors
networkPublisher
    .catch { _ in Just(defaultValue) }
```

### 4. assign(to:on:) with Failable Publishers

```swift
// COMPILE ERROR: Failure must be Never
networkPublisher  // Failure: URLError
    .assign(to: \.data, on: viewModel)

// FIXED: Handle errors first
networkPublisher
    .replaceError(with: defaultData)  // Now Failure is Never
    .assign(to: \.data, on: viewModel)
```

### 5. Not Handling Errors Before Long-Lived Subscriptions

```swift
// BAD: First error kills subscription permanently
dataPublisher
    .receive(on: DispatchQueue.main)
    .assign(to: \.items, on: viewModel)  // Dead after first error

// GOOD: Error handling preserves subscription
dataPublisher
    .catch { _ in Just([]) }
    .receive(on: DispatchQueue.main)
    .assign(to: \.items, on: viewModel)
```

## Review Questions

1. Is error type preserved through the pipeline? (Check for naked tryMap)
2. Will this publisher survive its first error? (Check where catch/replaceError is)
3. Is `assertNoFailure` used for expected errors? (Should only be programming errors)
4. Are error types unified at API boundaries with mapError?
5. Is the publisher infallible (`Failure == Never`) before assign(to:on:)?
