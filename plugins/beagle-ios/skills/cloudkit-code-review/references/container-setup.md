# CloudKit Container Setup

## Container Architecture

```swift
// Default container (matches app's bundle identifier)
let container = CKContainer.default()

// Custom container (explicit identifier - recommended)
let container = CKContainer(identifier: "iCloud.com.company.appname")
```

**Container identifiers cannot be deleted once created** - verify naming before creation.

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

## Custom Zones

Custom zones provide atomic operations, sharing, and change tokens. **Required for production apps.**

```swift
let zoneID = CKRecordZone.ID(zoneName: "MyZone", ownerName: CKCurrentUserDefaultName)
let zone = CKRecordZone(zoneID: zoneID)

let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
privateDB.add(operation)
```

## Critical Anti-Patterns

### 1. Using Default Zone for Production

```swift
// BAD: Default zone lacks atomic operations and sharing
let record = CKRecord(recordType: "Note")
privateDB.save(record) { _, _ in }

// GOOD: Use custom zone
let zoneID = CKRecordZone.ID(zoneName: "NotesZone", ownerName: CKCurrentUserDefaultName)
let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
let record = CKRecord(recordType: "Note", recordID: recordID)
```

### 2. Missing Account Status Check

```swift
// BAD: Assumes iCloud is available
func saveUserData() {
    container.privateCloudDatabase.save(record) { _, _ in }
}

// GOOD: Check account status first
container.accountStatus { status, error in
    guard status == .available else {
        // Handle: .noAccount, .restricted, .couldNotDetermine
        return
    }
    self.container.privateCloudDatabase.save(record) { _, _ in }
}
```

### 3. Not Observing Account Changes

```swift
// BAD: Assumes account persists
class DataManager {
    let container = CKContainer.default()
}

// GOOD: Observe account changes
NotificationCenter.default.addObserver(
    forName: .CKAccountChanged,
    object: nil,
    queue: .main
) { _ in
    // Re-check account status, clear private data cache if user changed
}
```

### 4. Missing NSPersistentCloudKitContainer Options

```swift
// BAD: Missing required options
let container = NSPersistentCloudKitContainer(name: "Model")
container.loadPersistentStores { _, _ in }

// GOOD: Enable required tracking
let description = container.persistentStoreDescriptions.first!
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
4. Is `CKAccountChanged` notification observed?
5. Are entitlements configured for both app and extensions?
6. Is the production environment entitlement set for release builds?
