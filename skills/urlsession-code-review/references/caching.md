# URLSession Caching and Configuration Reference

## Quick Reference

### URLSessionConfiguration Types

| Type | Persistence | Use Case |
|------|-------------|----------|
| `.default` | Disk cache, cookies | Normal networking |
| `.ephemeral` | Memory only | Privacy-sensitive |
| `.background(withIdentifier:)` | System-managed | Large transfers |

### Cache Policies

| Policy | Behavior | When to Use |
|--------|----------|-------------|
| `.useProtocolCachePolicy` | Follows HTTP headers | Default |
| `.reloadIgnoringLocalCacheData` | Always fetch fresh | Fresh data required |
| `.returnCacheDataElseLoad` | Cache first | Offline-first |
| `.returnCacheDataDontLoad` | Cache only | Strict offline |

### Timeout Defaults

| Property | Default | Typical Setting |
|----------|---------|-----------------|
| `timeoutIntervalForRequest` | 60s | 30-60s |
| `timeoutIntervalForResource` | **7 days** | 2-5 minutes |

### URLCache Sizing

| Type | Default | Recommended |
|------|---------|-------------|
| Memory | 512 KB | 20 MB |
| Disk | 10 MB | 100 MB |

## URLCache Configuration

```swift
// Default cache is too small - configure early in app lifecycle
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    URLCache.shared = URLCache(
        memoryCapacity: 20 * 1024 * 1024,  // 20 MB
        diskCapacity: 100 * 1024 * 1024,    // 100 MB
        directory: nil
    )
    return true
}
```

**Cache rules**: Response must be <= 5% of disk cache size to be cached.

## Session Configuration

### Default Configuration

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30.0
config.timeoutIntervalForResource = 300.0  // Not 7 days!
config.waitsForConnectivity = true
let session = URLSession(configuration: config)
```

### Ephemeral (Privacy Mode)

```swift
// No disk persistence - RAM only
let session = URLSession(configuration: .ephemeral)
```

### Background Configuration

```swift
let config = URLSessionConfiguration.background(
    withIdentifier: "com.yourapp.backgroundSession"
)
config.isDiscretionary = false  // Start immediately
config.sessionSendsLaunchEvents = true
let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
```

## Background Session Implementation

### AppDelegate Handler (Required)

```swift
var backgroundCompletionHandler: (() -> Void)?

func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    backgroundCompletionHandler = completionHandler
}
```

### Delegate Methods

```swift
func urlSession(_ session: URLSession,
                downloadTask: URLSessionDownloadTask,
                didFinishDownloadingTo location: URL) {
    // Move file immediately - location deleted after method returns
    try? FileManager.default.moveItem(at: location, to: permanentURL)
}

func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
        self.backgroundCompletionHandler?()
        self.backgroundCompletionHandler = nil
    }
}
```

## Connection Pooling

```swift
// CORRECT: Reuse sessions for HTTP/2 multiplexing
class NetworkService {
    static let shared = NetworkService()
    private let session = URLSession(configuration: .default)
}

// ANTI-PATTERN: New session per request - loses pooling
func badFetch(_ url: URL) async throws -> Data {
    let session = URLSession(configuration: .default)  // Bad!
    return try await session.data(from: url).0
}
```

## Critical Anti-Patterns

### 1. Memory Leak from Strong Delegate

```swift
// BUG: URLSession retains delegate forever
class LeakyManager {
    var session: URLSession!
    init() {
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    // deinit never called - memory leak
}

// CORRECT: Invalidate session
deinit {
    session.finishTasksAndInvalidate()
}
```

### 2. Background Session Identifier Conflicts

```swift
// BUG: Same identifier in app and extension
// Main app
let config = URLSessionConfiguration.background(withIdentifier: "downloads")
// Extension (CONFLICT!)
let config = URLSessionConfiguration.background(withIdentifier: "downloads")

// CORRECT: Unique per process
"com.yourapp.main.downloads"
"com.yourapp.extension.downloads"
```

### 3. Data-Based Background Uploads

```swift
// BUG: Data uploads don't persist in background
backgroundSession.uploadTask(with: request, from: data)  // Fails!

// CORRECT: File-based uploads
let fileURL = saveDataToFile(data)
backgroundSession.uploadTask(with: request, fromFile: fileURL)
```

### 4. Completion Handlers in Background Sessions

```swift
// BUG: Completion handlers not called
backgroundSession.dataTask(with: url) { data, _, _ in
    // Never executed!
}

// CORRECT: Use delegate methods only
```

### 5. Inadequate Cache Size

```swift
// BUG: Default 512KB memory, 10MB disk - too small
let session = URLSession.shared

// CORRECT: Configure adequate cache
URLCache.shared = URLCache(
    memoryCapacity: 20 * 1024 * 1024,
    diskCapacity: 100 * 1024 * 1024,
    directory: nil
)
```

### 6. Battery Drain from Immediate Transfers

```swift
// ANTI-PATTERN: Non-urgent but immediate
config.isDiscretionary = false  // Immediate regardless of conditions

// CORRECT: Let system optimize
config.isDiscretionary = true  // Waits for WiFi, charging
```

### 7. Missing Background Event Handler

```swift
// BUG: No handleEventsForBackgroundURLSession
class IncompleteAppDelegate: UIResponder, UIApplicationDelegate {
    // App never notified of completion
}
```

### 8. Unresumed Tasks

```swift
// BUG: Task created but never resumed
task = session.dataTask(with: url) { ... }
// MISSING: task.resume()
// Completion handler retained indefinitely

// CORRECT
task.resume()  // Always call
```

## Review Questions

### Cache
- [ ] Is URLCache configured with adequate capacity?
- [ ] Is cache configured before network calls?
- [ ] Is ephemeral config used for sensitive data?

### Session Management
- [ ] Are sessions reused (not created per request)?
- [ ] Is session invalidated when done?
- [ ] Are timeouts configured (not 7-day default)?

### Background Sessions
- [ ] Is identifier unique (especially with extensions)?
- [ ] Is `handleEventsForBackgroundURLSession` implemented?
- [ ] Is `urlSessionDidFinishEvents` calling completion handler?
- [ ] Are uploads file-based (not data-based)?
- [ ] Are delegate methods used (not completion handlers)?
- [ ] Is `isDiscretionary` set for non-urgent transfers?
- [ ] Is background session at app level (not ViewController)?

### Memory
- [ ] Is session delegate invalidated to break retain cycle?
- [ ] Are tasks always resumed after creation?
