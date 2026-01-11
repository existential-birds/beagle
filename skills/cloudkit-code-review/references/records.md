# CloudKit Records

## CKRecord Basics

**Supported field types:**
- `String`, `NSNumber`, `Data`, `Date`, `CLLocation`
- `CKRecord.Reference` - links to other records
- `CKAsset` - binary files (images, audio, documents)
- Arrays of any above type (same-type elements only)

**Size limits:**
| Constraint | Limit |
|------------|-------|
| Single record (excluding assets) | 1 MB |
| Single asset | 250 MB (native) |
| Batch operations per request | ~400 records |

## CKRecord.Reference

```swift
// Child points to parent with cascade delete
let parentRef = CKRecord.Reference(recordID: parentRecord.recordID, action: .deleteSelf)
childRecord["parentRef"] = parentRef
```

**Actions:**
- `.deleteSelf` - Child deleted when parent deleted
- `.none` - Child becomes orphan when parent deleted

## CKAsset

```swift
let fileURL = getLocalFileURL()
let asset = CKAsset(fileURL: fileURL)
record["attachment"] = asset
```

Assets stored separately, don't count toward 1MB record limit.

## Critical Anti-Patterns

### 1. Storing Child Arrays in Parent

```swift
// BAD: Causes conflict resolution nightmares
let parentRecord = CKRecord(recordType: "Album")
parentRecord["photoIDs"] = photoIDs as CKRecordValue

// GOOD: Child references parent
let photoRecord = CKRecord(recordType: "Photo")
let albumRef = CKRecord.Reference(recordID: albumRecord.recordID, action: .deleteSelf)
photoRecord["album"] = albumRef
```

### 2. Ignoring Errors

```swift
// BAD
database.save(record) { _, error in
    self.updateUI()  // Ignores error!
}

// GOOD
database.save(record) { _, error in
    if let error = error as? CKError {
        switch error.code {
        case .serverRecordChanged:
            self.resolveConflict(error: error)
        case .networkUnavailable, .networkFailure:
            if let retry = error.userInfo[CKErrorRetryAfterKey] as? Double {
                DispatchQueue.main.asyncAfter(deadline: .now() + retry) {
                    self.retrySave(record)
                }
            }
        default:
            self.handleError(error)
        }
        return
    }
    DispatchQueue.main.async { self.updateUI() }
}
```

### 3. String Literals for Keys

```swift
// BAD: Typos won't be caught
record["titel"] = title

// GOOD: Type-safe keys
enum RecordKeys: String {
    case title, createdAt, category
}
record[RecordKeys.title.rawValue] = title
```

### 4. Individual Saves Instead of Batch

```swift
// BAD: Separate network call for each record
for record in records {
    database.save(record) { _, _ in }
}

// GOOD: Single batch operation
let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
operation.modifyRecordsResultBlock = { result in }
database.add(operation)
```

### 5. Exceeding Record Size

```swift
// BAD: May exceed 1MB limit
record["imageData"] = largeImageData as CKRecordValue

// GOOD: Use CKAsset for binary data
let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.jpg")
try imageData.write(to: tempURL)
record["image"] = CKAsset(fileURL: tempURL)
```

### 6. UI Updates on Background Thread

```swift
// BAD: CloudKit callbacks are on background thread
database.fetch(withRecordID: recordID) { record, error in
    self.titleLabel.text = record?["title"] as? String  // Crash!
}

// GOOD
database.fetch(withRecordID: recordID) { record, error in
    DispatchQueue.main.async {
        self.titleLabel.text = record?["title"] as? String
    }
}
```

### 7. Downloading All Fields

```swift
// BAD: Downloads everything including large assets
let query = CKQuery(recordType: "Photo", predicate: predicate)
database.perform(query, inZoneWith: nil) { records, error in }

// GOOD: Only fetch needed fields
let operation = CKQueryOperation(query: query)
operation.desiredKeys = ["title", "timestamp"]
database.add(operation)
```

## Error Handling Table

| Error Code | Common Mistake | Correct Handling |
|------------|----------------|------------------|
| `partialFailure` | Treat as complete failure | Parse `partialErrorsByItemID` |
| `serverRecordChanged` | Retry with client record | Merge using server record from error |
| `requestRateLimited` | Immediate retry | Use `retryAfterSeconds` |
| `limitExceeded` | Fail operation | Split batch and retry |
| `quotaExceeded` | Silent failure | Alert user |

## Review Questions

1. Are custom record IDs used that match local storage identifiers?
2. Is record data under 1MB with large files as CKAssets?
3. Are relationships using back-references (child->parent) not arrays?
4. Is `.deleteSelf` used appropriately for cascade delete needs?
5. Are all CloudKit callbacks dispatching UI updates to main thread?
6. Is `desiredKeys` specified to avoid downloading unnecessary data?
