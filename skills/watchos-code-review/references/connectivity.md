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

### 1. Setup in a View Instead of Early App Lifecycle

```swift
// BAD: Won't receive background launches if activated lazily inside a deep view
struct DetailView: View {
    var body: some View {
        Text("Details")
            .onAppear {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
    }
}

// GOOD: Initialize singleton early in AppDelegate / WKApplicationDelegate
func applicationDidFinishLaunching() {
    _ = WatchConnectivityService.shared
}
```

### 2. Using `sendMessage` for Critical Data

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

### 3. Updating `@MainActor` / SwiftUI State on `WCSessionDelegate` Background Queue

`WCSessionDelegate` callbacks execute on an internal background queue. Updating `@MainActor`-isolated `@Observable` models or UI state directly violates actor isolation and crashes/races.

```swift
// BAD: Delegate callback runs on background queue
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    store.latestText = message["text"] as? String  // Background mutation / data race!
}

// GOOD: Hop to @MainActor before updating @Observable / SwiftUI state
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    let text = message["text"] as? String
    Task { @MainActor in
        store.latestText = text
    }
}
```

### 4. Async File Handling

`WCSession` deletes the temporary `file.fileURL` as soon as `session(_:didReceive:)` returns.

```swift
// BAD: File deleted before async move completes
func session(_ session: WCSession, didReceive file: WCSessionFile) {
    Task {
        try? FileManager.default.moveItem(at: file.fileURL, to: destination)
    }
}

// GOOD: Move synchronously first, then notify @MainActor
func session(_ session: WCSession, didReceive file: WCSessionFile) {
    do {
        try FileManager.default.moveItem(at: file.fileURL, to: destination)
        Task { @MainActor in
            store.processFile(at: destination)
        }
    } catch {
        logger.error("Failed to move received file: \(error)")
    }
}
```

### 5. Not Reactivating After Deactivation (iOS)

```swift
// BAD: Session unusable after paired Apple Watch swap
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
// BAD: OS generates errors if counterpart doesn't invoke replyHandler
WCSession.default.sendMessage(data, replyHandler: { _ in }, errorHandler: nil)

// GOOD: Pass nil when no reply expected
WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: { error in
    logger.error("sendMessage failed: \(error)")
})
```

## Data Type Requirements

Only Plist-encodable types allowed:
- `String`, `Int`, `Double`, `Bool`
- `Data`
- `Array`, `Dictionary` (of above types)

```swift
// BAD: Custom types
WCSession.default.sendMessage(["user": myUser], replyHandler: nil)

// GOOD: Encode first
let data = try JSONEncoder().encode(myUser)
WCSession.default.sendMessage(["userData": data], replyHandler: nil)
```

## Review Questions

1. Is `WCSession.isSupported()` checked on iOS before setup?
2. Is the delegate set before `activate()` via an early-initialized singleton?
3. Is `activationState == .activated` checked before sending?
4. Is `isReachable` checked for `sendMessage` calls?
5. Is `transferUserInfo` used for data that must be delivered?
6. Are `WCSessionDelegate` callbacks hopping to `@MainActor` before mutating UI state?
7. Are received files moved synchronously before `session(_:didReceive:)` returns?
8. Is `sessionDidDeactivate` reactivating the session on iOS?
9. Are only Plist-encodable types being sent?
