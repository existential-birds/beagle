# URLSession Error Handling Reference

## Quick Reference

### URLError Codes

| Code | Name | Retryable | User Message |
|------|------|-----------|--------------|
| -1009 | `notConnectedToInternet` | No* | "You're offline" |
| -1001 | `timedOut` | Yes | "Request timed out" |
| -999 | `cancelled` | No | (Silent) |
| -1003 | `cannotFindHost` | Yes | "Unable to reach server" |
| -1004 | `cannotConnectToHost` | Yes | "Unable to connect" |
| -1005 | `networkConnectionLost` | Yes | "Connection lost" |
| -1200 | `secureConnectionFailed` | No | "Security error" |

*Wait for network to reconnect

### HTTP Status Codes

| Range | Category | Retryable | Handling |
|-------|----------|-----------|----------|
| 200-299 | Success | N/A | Process response |
| 400 | Bad Request | No | Show validation error |
| 401 | Unauthorized | No | Re-authenticate |
| 404 | Not Found | No | Show not found |
| 429 | Too Many Requests | Yes | Respect Retry-After |
| 500-599 | Server Error | Yes | Retry with backoff |

## Transport vs HTTP Errors

**Critical**: URLSession does NOT treat non-2xx status codes as errors automatically.

```swift
// Transport errors via error parameter
if let error = error as? URLError {
    switch error.code {
    case .notConnectedToInternet: // Device offline
    case .timedOut: // Request timed out
    case .cancelled: // User cancelled
    default: break
    }
}

// HTTP errors via status code (MUST check manually)
guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode) else {
    // Server returned error - data may contain error body
}
```

## Response Validation

```swift
func validateResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?) throws -> Data {
    // 1. Transport errors first
    if let error = error {
        throw NetworkError.transport(error)
    }
    // 2. Validate response type
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
    }
    // 3. Check status code
    guard (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.httpError(httpResponse.statusCode, data)
    }
    // 4. Validate data
    guard let data = data, !data.isEmpty else {
        throw NetworkError.noData
    }
    return data
}
```

## Retry Strategy

### Determining Retryability

```swift
extension URLError.Code {
    var isRetryable: Bool {
        switch self {
        case .timedOut, .cannotFindHost, .cannotConnectToHost,
             .networkConnectionLost, .dnsLookupFailed:
            return true
        case .notConnectedToInternet, .cancelled,
             .secureConnectionFailed, .userAuthenticationRequired:
            return false
        default:
            return false
        }
    }
}

extension Int {
    var isRetryableStatusCode: Bool {
        [408, 429, 500, 502, 503, 504].contains(self)
    }
}
```

### Exponential Backoff with Jitter

```swift
struct RetryConfiguration {
    let maxRetries: Int = 3
    let baseDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 30.0

    func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        let clamped = min(exponential, maxDelay)
        let jitter = Double.random(in: 0...(0.1 * clamped))
        return clamped + jitter
    }
}
```

### Retry-After Header

```swift
func retryDelay(from response: HTTPURLResponse, fallback: TimeInterval) -> TimeInterval {
    if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
       let seconds = Double(retryAfter) {
        return seconds
    }
    return fallback
}
```

## Network Conditions

### waitsForConnectivity (Recommended)

```swift
let config = URLSessionConfiguration.default
config.waitsForConnectivity = true  // Wait instead of failing
config.timeoutIntervalForResource = 300  // Don't use 7-day default

// Delegate for UI feedback
func urlSession(_ session: URLSession,
                taskIsWaitingForConnectivity task: URLSessionTask) {
    // Show "waiting for network" UI
}
```

**Important**: Don't pre-check network before requests - race condition.

## Critical Anti-Patterns

### 1. Silent Error Swallowing

```swift
// DANGEROUS
URLSession.shared.dataTask(with: request) { data, _, error in
    guard let data = data else { return }  // Error ignored!
}

// CORRECT
URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error { handleError(error); return }
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        handleHTTPError(response); return
    }
    guard let data = data else { handleNoData(); return }
}
```

### 2. Missing Status Code Validation

```swift
// DANGEROUS: Assumes nil error means success
let (data, _) = try await URLSession.shared.data(for: request)
return data  // Could be 404 error page!

// CORRECT
let (data, response) = try await URLSession.shared.data(for: request)
guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode) else {
    throw NetworkError.httpError
}
```

### 3. Retrying Non-Retryable Errors

```swift
// DANGEROUS: Retrying 401 won't help
for _ in 0..<3 {
    do { return try await fetch() }
    catch { continue }  // Retries ALL errors
}

// CORRECT
catch let error as URLError where error.code.isRetryable {
    continue  // Only retry network issues
}
```

### 4. Blocking Retry Without Backoff

```swift
// DANGEROUS: Hammers server
while true {
    do { return try await fetch() }
    catch { continue }  // Immediate retry
}

// CORRECT: Exponential backoff
for attempt in 0..<maxRetries {
    do { return try await fetch() }
    catch {
        let delay = baseDelay * pow(2.0, Double(attempt))
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}
```

### 5. Technical Errors to Users

```swift
// DANGEROUS
showAlert(error.localizedDescription)
// "Error Domain=NSURLErrorDomain Code=-1004..."

// CORRECT
showAlert(userFriendlyMessage(for: error))
// "Unable to connect. Please check your internet."
```

### 6. Ignoring Cancellation

```swift
// DANGEROUS: Shows error for user cancel
catch { showError(error) }

// CORRECT
catch let error as URLError where error.code == .cancelled {
    return  // Silent - user initiated
}
catch { showError(error) }
```

## Review Questions

### Error Handling
- [ ] Are both transport errors and HTTP status codes handled?
- [ ] Is there a centralized error handling strategy?
- [ ] Are error types mapped to user-friendly messages?

### Response Validation
- [ ] Is response cast to HTTPURLResponse?
- [ ] Are non-2xx status codes treated as errors?
- [ ] Are error response bodies parsed for messages?

### Retry Logic
- [ ] Are only appropriate errors retried (not 4xx)?
- [ ] Is exponential backoff with jitter implemented?
- [ ] Is there a maximum retry count?
- [ ] Is Retry-After header respected for 429/503?

### User Experience
- [ ] Are cancellation errors handled silently?
- [ ] Is there a retry option for recoverable errors?
- [ ] Are authentication errors handled separately?
