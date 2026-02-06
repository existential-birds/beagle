# URLSession Async/Await Reference

> Minimum deployment: iOS 15+, macOS 12+

## Quick Reference

### Core Async Methods

| Method | Returns | Use Case |
|--------|---------|----------|
| `data(from: URL)` | `(Data, URLResponse)` | Simple GET requests |
| `data(for: URLRequest)` | `(Data, URLResponse)` | Configured requests (POST, headers) |
| `download(from: URL)` | `(URL, URLResponse)` | Large files to disk |
| `download(for: URLRequest)` | `(URL, URLResponse)` | Large files with custom request |
| `upload(for: URLRequest, from: Data)` | `(Data, URLResponse)` | Upload data in memory |
| `upload(for: URLRequest, fromFile: URL)` | `(Data, URLResponse)` | Upload file from disk |
| `bytes(from: URL)` | `(AsyncBytes, URLResponse)` | Streaming response body |

## Data Tasks

```swift
// Basic GET
func fetchData(from url: URL) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }
    return data
}

// POST with URLRequest
func postData<T: Encodable>(_ body: T, to url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(body)
    let (data, response) = try await URLSession.shared.data(for: request)
    // Validate response...
    return data
}
```

## Download Tasks

```swift
func downloadFile(from url: URL, to destination: URL) async throws {
    let (tempURL, response) = try await URLSession.shared.download(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }
    // CRITICAL: Move or delete the file - it is NOT auto-deleted
    try FileManager.default.moveItem(at: tempURL, to: destination)
}
```

**Key difference**: The async/await download API does NOT automatically delete temporary files.

## Streaming with AsyncBytes

```swift
// Line-by-line processing
func streamLines(from url: URL) async throws {
    let (bytes, _) = try await URLSession.shared.bytes(from: url)
    for try await line in bytes.lines {
        processLine(line)
    }
}

// Server-Sent Events
func subscribeToEvents(url: URL) async throws {
    let (bytes, _) = try await URLSession.shared.bytes(from: url)
    for try await line in bytes.lines {
        if line.hasPrefix("data: ") {
            let jsonString = String(line.dropFirst(6))
            // Parse and handle event
        }
    }
}
```

## Task Cancellation

Task cancellation **automatically propagates** to URLSession requests.

```swift
class DataLoader {
    private var loadTask: Task<Data, Error>?

    func load(from url: URL) {
        loadTask?.cancel()  // Cancel previous request
        loadTask = Task {
            try await URLSession.shared.data(from: url).0
        }
    }
}
```

SwiftUI's `.task` modifier automatically cancels when the view disappears.

## Memory Management

Tasks implicitly capture `self` strongly. Use `[weak self]` for long-running tasks:

```swift
downloadTask = Task { [weak self] in
    guard let url = self?.downloadURL else { return }
    let (data, _) = try await URLSession.shared.data(from: url)
    self?.processData(data)
}
```

## Critical Anti-Patterns

### 1. Not Checking HTTP Status Codes

```swift
// BAD: 404 does not throw an error
let (data, _) = try await URLSession.shared.data(from: url)
let decoded = try JSONDecoder().decode(Model.self, from: data)  // Crashes on error HTML

// GOOD: Validate response
let (data, response) = try await URLSession.shared.data(from: url)
guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode) else {
    throw NetworkError.serverError
}
```

### 2. Forgetting to Delete Downloaded Files

```swift
// BAD: Temporary file wastes storage
let (tempURL, _) = try await URLSession.shared.download(from: url)
// File is never moved or deleted

// GOOD: Always handle temporary file
let (tempURL, _) = try await URLSession.shared.download(from: url)
defer { try? FileManager.default.removeItem(at: tempURL) }
let data = try Data(contentsOf: tempURL)
```

### 3. Upload Without HTTP Method

```swift
// BAD: GET cannot have a body
var request = URLRequest(url: url)
try await URLSession.shared.upload(for: request, from: data)  // Fails

// GOOD: Set HTTP method
request.httpMethod = "POST"
try await URLSession.shared.upload(for: request, from: data)
```

### 4. Storing Tasks Without Cancellation

```swift
// BAD: Tasks accumulate
func search(query: String) {
    Task { let results = try await performSearch(query) }
}

// GOOD: Cancel previous task
private var searchTask: Task<Void, Never>?
func search(query: String) {
    searchTask?.cancel()
    searchTask = Task {
        guard !Task.isCancelled else { return }
        let results = try? await performSearch(query)
    }
}
```

### 5. Strong Self in Infinite Loops

```swift
// BAD: Permanent memory leak
listenerTask = Task {
    for try await line in bytes.lines {
        self.handleEvent(line)  // Never deallocates
    }
}

// GOOD: Weak self
listenerTask = Task { [weak self] in
    for try await line in bytes.lines {
        guard let self else { return }
        self.handleEvent(line)
    }
}
```

## Review Questions

- [ ] Are HTTP status codes validated (not just assuming success)?
- [ ] Are downloaded files moved/deleted after use?
- [ ] Are upload requests setting HTTP method (POST/PUT)?
- [ ] Are long-running tasks using `[weak self]`?
- [ ] Are stored Task references cancelled when appropriate?
- [ ] Is cancellation handled in `viewWillDisappear`?
- [ ] Is SwiftUI's `.task` modifier used instead of manual Task management?
- [ ] For streaming, is response status checked before iterating?
