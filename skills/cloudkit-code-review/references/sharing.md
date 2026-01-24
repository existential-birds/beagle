# CloudKit Sharing

## Sharing Models

| Model | Use Case | CKShare Creation |
|-------|----------|------------------|
| **Record Sharing** | Individual records with hierarchy | `CKShare(rootRecord: record)` |
| **Zone Sharing** | All records in custom zone | `CKShare(recordZoneID: zone.zoneID)` |

## Permission Levels

| Permission | Description |
|------------|-------------|
| `.none` | No access (default for `publicPermission`) |
| `.readOnly` | Can read shared records |
| `.readWrite` | Can read and modify shared records |

## Database Architecture

```
Private Database (Owner)
└── Custom Zone (required!)
    ├── Root Record
    ├── Child Records (auto-shared)
    └── CKShare Record

Shared Database (Participants)
└── [View into owner's private database]
```

## Critical Anti-Patterns

### 1. Using Default Zone for Sharing

```swift
// BAD: CKShare cannot be saved in Default Zone
let record = CKRecord(recordType: "Item")  // Uses default zone
let share = CKShare(rootRecord: record)
try await privateDatabase.save(share)  // ERROR!

// GOOD: Use custom zone
let zoneID = CKRecordZone.ID(zoneName: "SharedItems", ownerName: CKCurrentUserDefaultName)
let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
let record = CKRecord(recordType: "Item", recordID: recordID)
let share = CKShare(rootRecord: record)
try await privateDatabase.modifyRecords(saving: [record, share], deleting: [])
```

### 2. Saving CKShare Without Root Record

```swift
// BAD: Even if record exists, must save together
let share = CKShare(rootRecord: existingRecord)
try await privateDatabase.save(share)  // ERROR!

// GOOD: Save both together
try await privateDatabase.modifyRecords(saving: [existingRecord, share], deleting: [])
```

### 3. Creating New Shares for Already-Shared Records

```swift
// BAD: Revokes existing share, removes all participants
func shareContact(_ contact: CKRecord) async throws {
    let share = CKShare(rootRecord: contact)  // Creates NEW share!
    try await privateDatabase.modifyRecords(saving: [contact, share], deleting: [])
}

// GOOD: Check for existing share first
func shareContact(_ contact: CKRecord) async throws -> CKShare {
    if let existingShareRef = contact.share {
        return try await privateDatabase.record(for: existingShareRef.recordID) as! CKShare
    }
    let share = CKShare(rootRecord: contact)
    try await privateDatabase.modifyRecords(saving: [contact, share], deleting: [])
    return share
}
```

### 4. Not Verifying Permissions Before Modification

```swift
// BAD: Assumes write access
func updateSharedRecord(_ record: CKRecord) async throws {
    record["name"] = "Updated"
    try await sharedDatabase.save(record)  // Fails if readOnly!
}

// GOOD: Check permission first
func canModify(share: CKShare) -> Bool {
    guard let participant = share.currentUserParticipant else { return false }
    return participant.permission == .readWrite || share.owner == participant
}
```

### 5. Missing CKSharingSupported in Info.plist

```xml
<!-- Required for share acceptance callbacks -->
<key>CKSharingSupported</key>
<true/>
```

Without this, `userDidAcceptCloudKitShareWith` is never called.

### 6. Not Handling Share Acceptance

```swift
// BAD: Share links won't work
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Missing implementation
}

// GOOD
func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
) {
    let container = CKContainer(identifier: metadata.containerIdentifier)
    Task {
        do {
            try await container.accept(metadata)
        } catch {
            // Handle error
        }
    }
}
```

### 7. Not Setting Share Metadata

```swift
// BAD: Email invitations show no context
let share = CKShare(rootRecord: record)

// GOOD: Set title for user-friendly invitations
let share = CKShare(rootRecord: record)
share[CKShare.SystemFieldKey.title] = "Shopping List"
share[CKShare.SystemFieldKey.shareType] = "com.app.shoppinglist"
share[CKShare.SystemFieldKey.thumbnailImageData] = thumbnailData
```

### 8. Multiple CKShare per Zone

```swift
// BAD: Only ONE CKShare allowed per zone
let share1 = CKShare(recordZoneID: zoneID)
try await privateDatabase.save(share1)
let share2 = CKShare(recordZoneID: zoneID)  // ERROR on save!

// GOOD: Check for existing zone share
func getOrCreateZoneShare(for zoneID: CKRecordZone.ID) async throws -> CKShare {
    let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
    do {
        return try await privateDatabase.record(for: shareID) as! CKShare
    } catch {
        let share = CKShare(recordZoneID: zoneID)
        try await privateDatabase.save(share)
        return share
    }
}
```

## UICloudSharingController Integration

```swift
func presentShareController(for share: CKShare, record: CKRecord) {
    // Pre-fetch share before presenting
    let controller = UICloudSharingController(share: share, container: container)
    controller.delegate = self
    present(controller, animated: true)
}

// Required delegate methods
extension ViewController: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        // Handle error
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Shared Item"
    }
}
```

## Review Questions

1. Is CKShare saved to a **custom zone** (not Default Zone)?
2. Is root record saved **together** with CKShare in same operation?
3. Does code check for **existing shares** before creating new ones?
4. Is **CKSharingSupported** enabled in Info.plist?
5. Is `userDidAcceptCloudKitShareWith` implemented?
6. Are shared records accessed from **sharedDatabase** (not privateDatabase)?
7. Does code verify **permissions** before attempting modifications?
8. Is **share metadata** (title, type) set for user-friendly invitations?
