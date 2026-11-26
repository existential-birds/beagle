# CloudKit Records

## CKRecord Basics

**Supported field types:**
- `String`, `NSNumber`, `Data`, `Date`, `CLLocation`
- `CKRecord.Reference` — links to other records
- `CKAsset` — binary files (images, audio, documents)
- Arrays of any above type (same-type elements only)

**Size limits:**
| Constraint | Limit |
|------------|-------|
| Single record (excluding assets) | 1 MB |
| Single asset | Stored separately from 1 MB record limit; constrained by iCloud quota / `CKError.limitExceeded` |
| Batch operations per request | ~400 records (split on `limitExceeded`) |

## CKRecord.Reference

```swift
// Child points to parent with cascade delete
let parentRef = CKRecord.Reference(recordID: parentRecord.recordID, action: .deleteSelf)
childRecord["parentRef"] = parentRef
```

**Actions:**
- `.deleteSelf` — Child deleted when parent deleted
- `.none` — Child becomes orphan when parent deleted

## CKAsset

```swift
let fileURL = getLocalFileURL()
let asset = CKAsset(fileURL: fileURL)
record["attachment"] = asset
```

Assets are stored separately and do not count toward the 1 MB `CKRecord` limit.

**Critical lifetime warning on fetched assets:** When CloudKit downloads a `CKAsset`, `asset.fileURL` points to a **system-managed temporary staging directory** that CloudKit periodically purges. Do NOT store or rely on that temporary URL long-term — copy or move the file to your app's persistent container immediately after fetching.

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

### 2. Ignoring Errors & Rate Limits

```swift
// BAD
_ = try? await database.save(record)  // Silently swallows conflicts & rate limits!

// GOOD
do {
    _ = try await database.save(record)
} catch let error as CKError {
    switch error.code {
    case .serverRecordChanged:
        await resolveConflict(error: error)
    case .requestRateLimited, .serviceUnavailable, .zoneBusy:
        if let retryAfter = error.retryAfterSeconds {
            try await Task.sleep(for: .seconds(retryAfter))
            try await retrySave(record)
        }
    default:
        handleError(error)
    }
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
    try await database.save(record)
}

// GOOD: Async batch operation (iOS 15+) or CKSyncEngine (iOS 17+)
let result = try await database.modifyRecords(saving: records, deleting: [])
for (recordID, saveResult) in result.saveResults {
    if case .failure(let error) = saveResult {
        handleRecordError(recordID: recordID, error: error)
    }
}
```

### 5. Exceeding Record Size or Ignoring Fetched Asset Staging

```swift
// BAD: May exceed 1 MB limit
record["imageData"] = largeImageData as CKRecordValue

// BAD: Keeping fetched CKAsset.fileURL without copying
self.cachedURL = (fetchedRecord["image"] as? CKAsset)?.fileURL  // Purged later by CloudKit!

// GOOD: Use CKAsset and copy fetched assets to persistent storage
if let assetURL = (fetchedRecord["image"] as? CKAsset)?.fileURL {
    try FileManager.default.copyItem(at: assetURL, to: persistentURL)
}
```

### 6. UI Updates Off MainActor

```swift
// BAD: Updating UI directly from legacy CloudKit completion handler (background thread)
database.fetch(withRecordID: recordID) { record, error in
    self.titleLabel.text = record?["title"] as? String  // Off main thread!
}

// GOOD: Use async/await on @MainActor
@MainActor
func loadTitle(for recordID: CKRecord.ID) async throws {
    let record = try await database.record(for: recordID)
    self.titleLabel.text = record[RecordKeys.title.rawValue] as? String
}
```

### 7. Downloading All Fields

```swift
// BAD: Downloads everything including large assets
let query = CKQuery(recordType: "Photo", predicate: predicate)
let (matchResults, _) = try await database.records(matching: query)

// GOOD: Only fetch needed fields
let (matchResults, _) = try await database.records(
    matching: query,
    desiredKeys: ["title", "timestamp"]
)
```

## Error Handling Table

| Error Code | Common Mistake | Correct Handling |
|------------|----------------|------------------|
| `partialFailure` | Treat as complete failure | Parse `partialErrorsByItemID` (or `saveResults` in async `modifyRecords`) |
| `serverRecordChanged` | Retry with client record | Merge using `serverRecord` from error |
| `requestRateLimited` | Immediate retry | Sleep for `error.retryAfterSeconds` |
| `limitExceeded` | Fail operation | Split batch and retry |
| `quotaExceeded` | Silent failure | Alert user |

## Review Questions

1. Are custom record IDs used that match local storage identifiers?
2. Is record data under 1 MB with large files as `CKAsset`?
3. Are fetched `CKAsset.fileURL` files copied to persistent storage rather than referenced in temporary staging?
4. Are relationships using back-references (child -> parent) instead of ID arrays?
5. Are UI mutations isolated on `@MainActor`?
6. Is `desiredKeys` specified to avoid downloading unnecessary fields/assets?
