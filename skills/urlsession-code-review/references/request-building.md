# URLRequest Building Reference

## Quick Reference

### URLRequest Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | `URL?` | nil | Request URL |
| `httpMethod` | `String?` | "GET" | HTTP method |
| `httpBody` | `Data?` | nil | Request body |
| `timeoutInterval` | `TimeInterval` | 60.0 | Timeout in seconds |
| `cachePolicy` | `CachePolicy` | `.useProtocolCachePolicy` | Cache behavior |

### Cache Policies

| Policy | Use Case |
|--------|----------|
| `.useProtocolCachePolicy` | Default; respects server headers |
| `.reloadIgnoringLocalCacheData` | Always fetch fresh |
| `.returnCacheDataElseLoad` | Offline-first apps |
| `.returnCacheDataDontLoad` | Strictly offline |

### Content-Types

| Content Type | Use Case |
|--------------|----------|
| `application/json` | JSON body |
| `application/x-www-form-urlencoded` | Form data |
| `multipart/form-data; boundary=xxx` | File uploads |

## HTTP Headers

```swift
// Set headers
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// Set all at once
request.allHTTPHeaderFields = [
    "Content-Type": "application/json",
    "Accept": "application/json"
]
```

## Body Encoding

### JSON (Recommended)

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let body = CreateUserRequest(name: "John", email: "john@example.com")
request.httpBody = try JSONEncoder().encode(body)
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

### Form URL Encoded

```swift
let parameters = ["username": "john", "password": "secret"]
let bodyString = parameters
    .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
    .joined(separator: "&")
request.httpBody = bodyString.data(using: .utf8)
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
```

### Multipart Form Data

```swift
let boundary = UUID().uuidString
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

var body = Data()
body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
body.append(imageData)
body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
request.httpBody = body
```

## URL Query Parameters

```swift
// CORRECT: Use URLComponents
var components = URLComponents(string: "https://api.example.com/search")!
components.queryItems = [
    URLQueryItem(name: "query", value: "swift programming"),
    URLQueryItem(name: "page", value: "1")
]
let request = URLRequest(url: components.url!)

// Handle plus signs (not encoded by default)
let encodedValue = value?.replacingOccurrences(of: "+", with: "%2B")
```

## Timeout Configuration

```swift
// Request-level
var request = URLRequest(url: url)
request.timeoutInterval = 30.0

// Session-level
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30.0   // Resets on each packet
config.timeoutIntervalForResource = 300.0 // Total time (default: 7 days!)
```

## Critical Anti-Patterns

### 1. CRLF Injection (CVE-2022-3918)

```swift
// DANGEROUS: User input in headers
let userInput = "value\r\nEvil-Header: injected"
request.setValue(userInput, forHTTPHeaderField: "X-Custom")

// SAFE: Sanitize header values
let sanitized = userInput.replacingOccurrences(of: "\r", with: "")
    .replacingOccurrences(of: "\n", with: "")
request.setValue(sanitized, forHTTPHeaderField: "X-Custom")
```

### 2. Hardcoded Secrets

```swift
// DANGEROUS
request.setValue("sk_live_abc123xyz", forHTTPHeaderField: "Authorization")

// SAFE: From Keychain
let token = KeychainService.shared.getAPIToken()
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

### 3. Content-Type/Body Mismatch

```swift
// BUG: JSON body but wrong Content-Type
request.httpBody = try JSONEncoder().encode(user)
request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

// CORRECT
request.httpBody = try JSONEncoder().encode(user)
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

### 4. Manual URL Concatenation

```swift
// DANGEROUS: Injection risk
let url = URL(string: "https://api.com/search?q=\(userQuery)")!

// SAFE: URLComponents
var components = URLComponents(string: "https://api.com/search")!
components.queryItems = [URLQueryItem(name: "q", value: userQuery)]
```

### 5. Memory Issues with Large Files

```swift
// DANGEROUS: Loads entire file into memory
let largeFileData = try Data(contentsOf: largeFileURL)
request.httpBody = largeFileData

// SAFE: Use file-based upload
session.uploadTask(with: request, fromFile: largeFileURL)
```

### 6. Creating Sessions Per Request

```swift
// INEFFICIENT
func makeRequest() {
    let session = URLSession(configuration: .default)  // New each time!
    session.dataTask(with: request).resume()
}

// EFFICIENT: Reuse session
class NetworkManager {
    private let session = URLSession(configuration: .default)
}
```

## Review Questions

### Security
- [ ] Are header values sanitized for CRLF characters?
- [ ] Are secrets from Keychain, not hardcoded?
- [ ] Is SSL/TLS validation proper (no blanket trust)?
- [ ] Are credentials excluded from URLs and logs?

### Correctness
- [ ] Does Content-Type match body encoding?
- [ ] Is HTTP method appropriate (no body on GET)?
- [ ] Are query parameters built with URLComponents?
- [ ] Are special characters (+, ;, ,) encoded correctly?

### Performance
- [ ] Is URLSession reused across requests?
- [ ] Are timeouts configured appropriately?
- [ ] Are large uploads using file-based API?
- [ ] Is `timeoutIntervalForResource` set (not 7-day default)?
