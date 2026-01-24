# WatchConnectivity

## Communication Methods

| Method | Use Case | Guaranteed | Queuing |
|--------|----------|------------|---------|
| `sendMessage(_:)` | Real-time, immediate | No | None |
| `transferUserInfo(_:)` | Critical data | Yes | FIFO |
| `updateApplicationContext(_:)` | State sync, latest only | Yes (latest) | Overwrites |
| `transferFile(_:)` | Large files | Yes | FIFO |
| `transferCurrentComplicationUserInfo(_:)` | Complication data | Yes | Budget limited |

## Session Setup

```swift
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    override private init() {
        super.init()
        #if !os(watchOS)
        guard WCSession.isSupported() else { return }
        #endif
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}
```

## Required Delegate Methods

**iOS (all three required):**
- `session(_:activationDidCompleteWith:error:)`
- `sessionDidBecomeInactive(_:)`
- `sessionDidDeactivate(_:)`

**watchOS (one required):**
- `session(_:activationDidCompleteWith:error:)`

## Pre-Send Validation

```swift
private func canSendToPeer() -> Bool {
    guard WCSession.default.activationState == .activated else { return false }

    #if os(watchOS)
    guard WCSession.default.isCompanionAppInstalled else { return false }
    #else
    guard WCSession.default.isWatchAppInstalled else { return false }
    #endif

    return true
}

// For sendMessage only
if WCSession.default.isReachable {
    WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
}
```

## Critical Anti-Patterns

### 1. Setup in View Controller

```swift
// BAD: Won't be called during background launches
class MyViewController: UIViewController {
    override func viewDidLoad() {
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

// GOOD: Singleton in early lifecycle
// In AppDelegate
func application(...) -> Bool {
    _ = WatchConnectivityService.shared
    return true
}
```

### 2. Using sendMessage for Critical Data

```swift
// BAD: Lost when counterpart not reachable
func sendToWatch(_ data: [String: Any]) {
    WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: nil)
}

// GOOD: Use appropriate method based on criticality
func sendToWatch(_ data: [String: Any], critical: Bool) {
    guard canSendToPeer() else { return }

    if critical {
        WCSession.default.transferUserInfo(data)
    } else if WCSession.default.isReachable {
        WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: nil)
    }
}
```

### 3. UI Updates on Background Thread

```swift
// BAD: Delegate runs on background thread
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    self.label.text = message["text"] as? String  // Crash!
}

// GOOD: Dispatch to main
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    DispatchQueue.main.async {
        self.label.text = message["text"] as? String
    }
}
```

### 4. Async File Handling

```swift
// BAD: File deleted before async completes
func session(_ session: WCSession, didReceive file: WCSessionFile) {
    DispatchQueue.global().async {
        try? FileManager.default.moveItem(at: file.fileURL, to: destination)
    }
}

// GOOD: Synchronous move first
func session(_ session: WCSession, didReceive file: WCSessionFile) {
    do {
        try FileManager.default.moveItem(at: file.fileURL, to: destination)
        DispatchQueue.main.async {
            self.processFile(at: destination)
        }
    } catch {
        print("Failed: \(error)")
    }
}
```

### 5. Not Reactivating After Deactivation

```swift
// BAD: Session unusable after watch swap
func sessionDidDeactivate(_ session: WCSession) {
    // Nothing
}

// GOOD: Reactivate for watch swaps
func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
}
```

### 6. Reply Handler When Not Expecting Reply

```swift
// BAD: OS generates errors
WCSession.default.sendMessage(data, replyHandler: { _ in }, errorHandler: nil)

// GOOD: nil when no reply expected
WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: { error in
    print("Error: \(error)")
})
```

## Data Type Requirements

Only Plist-encodable types allowed:
- String, Int, Double, Bool
- Data
- Array, Dictionary (of above types)

```swift
// BAD: Custom types
WCSession.default.sendMessage(["user": myUser], ...)

// GOOD: Encode first
let data = try JSONEncoder().encode(myUser)
WCSession.default.sendMessage(["userData": data], ...)
```

## Review Questions

1. Is `WCSession.isSupported()` checked on iOS before setup?
2. Is delegate set before `activate()` (use singleton)?
3. Is `activationState == .activated` checked before sending?
4. Is `isReachable` checked for `sendMessage` calls?
5. Is `transferUserInfo` used for data that must be delivered?
6. Are delegate callbacks dispatching UI updates to main thread?
7. Are received files moved synchronously before delegate returns?
8. Is `sessionDidDeactivate` reactivating the session on iOS?
9. Are only Plist-encodable types being sent?
