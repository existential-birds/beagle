# CloudKit Container Setup

## Container Architecture

```swift
// Default container (matches app's bundle identifier)
let container = CKContainer.default()

// Custom container (explicit identifier - recommended)
let container = CKContainer(identifier: "iCloud.com.company.appname")
```

**Container identifiers cannot be deleted once created** — verify naming before creation.

## Database Types

| Database | Access | Custom Zones | Use Case |
|----------|--------|--------------|----------|
| **Private** | User-only (requires iCloud) | Yes | Personal data |
| **Public** | Read: anyone; Write: signed-in | No (default only) | App-wide content |
| **Shared** | Invited users only | Yes (one per sharer) | Collaboration |

```swift
let privateDB = container.privateCloudDatabase
let publicDB = container.publicCloudDatabase
let sharedDB = container.sharedCloudDatabase
```

## Sync Architecture: `CKSyncEngine` (iOS 17+) vs `CKDatabase` Async APIs

- **iOS 17+ sync**: Prefer `CKSyncEngine` (`CKSyncEngineDelegate`) for syncing local stores to private/shared databases. It manages server change tokens, batching, push notifications, and `retryAfterSeconds` scheduling automatically.
- **iOS 15+ direct operations**: Prefer `CKDatabase` / `CKContainer` `async`/`await` methods (`try await container.accountStatus()`, `try await database.modifyRecordZones(saving:deleting:)`, `try await database.modifyRecords(saving:deleting:)`) over legacy `CKOperation` subclasses or completion-handler callbacks.

```swift
// CKSyncEngine setup (iOS 17+)
let config = CKSyncEngine.Configuration(
    database: container.privateCloudDatabase,
    stateSerialization: loadSavedStateSerialization(),
    delegate: syncDelegate
)
let syncEngine = CKSyncEngine(config)
```

## Custom Zones

Custom zones provide atomic operations, sharing, and change tokens. **Required for production apps.**

```swift
let zoneID = CKRecordZone.ID(zoneName: "MyZone", ownerName: CKCurrentUserDefaultName)
let zone = CKRecordZone(zoneID: zoneID)

_ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
```

## Critical Anti-Patterns

### 1. Using Default Zone for Production

```swift
// BAD: Default zone lacks atomic operations and sharing
let record = CKRecord(recordType: "Note")
try await privateDB.save(record)

// GOOD: Use custom zone
let zoneID = CKRecordZone.ID(zoneName: "NotesZone", ownerName: CKCurrentUserDefaultName)
let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
let record = CKRecord(recordType: "Note", recordID: recordID)
```

### 2. Missing Account Status Check

```swift
// BAD: Assumes iCloud is available
func saveUserData() async throws {
    try await container.privateCloudDatabase.save(record)
}

// GOOD: Check account status first
func saveUserData() async throws {
    let status = try await container.accountStatus()
    guard status == .available else {
        // Handle: .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable
        return
    }
    try await container.privateCloudDatabase.save(record)
}
```

### 3. Not Observing Account Changes

```swift
// BAD: Assumes account persists across app lifetime
class DataManager {
    let container = CKContainer.default()
}

// GOOD: Observe account changes (or handle CKSyncEngine accountChange event)
for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
    // Re-check account status, clear private data cache if user changed
}
```

### 4. Missing NSPersistentCloudKitContainer Options

```swift
// BAD: Missing required options
let container = NSPersistentCloudKitContainer(name: "Model")
container.loadPersistentStores { _, _ in }

// GOOD: Enable required tracking
guard let description = container.persistentStoreDescriptions.first else { return }
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.company.app"
)
```

## Required Entitlements

```xml
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.company.appname</string>
</array>
```

For production:
```xml
<key>com.apple.developer.icloud-container-environment</key>
<string>Production</string>
```

## Review Questions

1. Is the container identifier explicitly specified or relying on `.default()`?
2. Is account status checked before accessing private/shared databases?
3. Are custom zones used for production features?
4. Is `CKSyncEngine` (iOS 17+) or async `CKDatabase` used cleanly without legacy `CKOperation` boilerplate?
5. Is `CKAccountChanged` notification (or `CKSyncEngine` `.accountChange` event) observed?
6. Are entitlements configured for both app and extensions?
7. Is the production environment entitlement set for release builds?
