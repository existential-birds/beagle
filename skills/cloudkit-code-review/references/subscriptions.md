# CloudKit Subscriptions

## Subscription Types

| Type | Use Case | Database Support |
|------|----------|------------------|
| **CKQuerySubscription** | Records matching predicate | Public, Private (default zone) |
| **CKRecordZoneSubscription** | All changes in custom zone | Private only |
| **CKDatabaseSubscription** | All changes across database | Private, Shared |

**Recommendations:**
- When using **`CKSyncEngine` (iOS 17+)**, the engine manages database subscriptions automatically for private/shared databases — do not create duplicate manual `CKDatabaseSubscription`s for the same scope.
- Otherwise, start with `CKDatabaseSubscription` unless only querying the default/public zone.

## Notification Configuration

```swift
let info = CKSubscription.NotificationInfo()

// Visible notification
info.alertBody = "New record available"
info.soundName = "default"
info.shouldBadge = true

// Silent notification (background sync)
info.shouldSendContentAvailable = true
// Leave alertBody, soundName, shouldBadge unset
```

## Critical Anti-Patterns

### 1. Creating Duplicate Subscriptions

```swift
// BAD: Creates duplicate on every app launch
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    let subscription = CKQuerySubscription(recordType: "Item", predicate: predicate, options: .firesOnRecordCreation)
    Task { try? await database.save(subscription) }
}

// GOOD: Check before creating, use consistent ID
let subscriptionID = "item-creation-subscription"

func ensureQuerySubscription() async throws {
    do {
        _ = try await database.subscription(for: subscriptionID)
    } catch let error as CKError where error.code == .unknownItem {
        let newSubscription = CKQuerySubscription(
            recordType: "Item",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: .firesOnRecordCreation
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        newSubscription.notificationInfo = info
        _ = try await database.save(newSubscription)
    }
}
```

### 2. Missing NotificationInfo

```swift
// BAD: Subscription will fail to save
let subscription = CKQuerySubscription(recordType: "Item", predicate: predicate, options: .firesOnRecordCreation)
try await database.save(subscription)  // Error!

// GOOD: Always configure notificationInfo
let info = CKSubscription.NotificationInfo()
info.shouldSendContentAvailable = true
subscription.notificationInfo = info
```

### 3. Wrong Subscription Type for Shared Database

```swift
// BAD: CKQuerySubscription doesn't work with shared database
let sharedDB = CKContainer.default().sharedCloudDatabase
let subscription = CKQuerySubscription(recordType: "SharedItem", predicate: predicate, options: .firesOnRecordCreation)
try await sharedDB.save(subscription)  // Error!

// GOOD: Use CKDatabaseSubscription for shared database
let subscription = CKDatabaseSubscription(subscriptionID: "shared-db-subscription")
let info = CKSubscription.NotificationInfo()
info.shouldSendContentAvailable = true
subscription.notificationInfo = info
_ = try await sharedDB.save(subscription)
```

### 4. Relying Solely on Push for Sync

```swift
// BAD: Only syncing when push arrives
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    syncData()  // Only sync trigger
}

// GOOD: Multiple sync triggers (or CKSyncEngine)
func applicationDidBecomeActive(_ application: UIApplication) {
    Task { await syncData() }  // On foreground
}

func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) async -> UIBackgroundFetchResult {
    await syncData()  // On notification
    return .newData
}
```

### 5. Not Indexing Predicate Fields

```swift
// BAD: Field not indexed in CloudKit Dashboard
let predicate = NSPredicate(format: "category == %@", "news")
// Error: CKError.invalidArguments when saving subscription

// FIX: Enable "Query" indexing for field in CloudKit Dashboard
```

## Registration Flow

```swift
@MainActor
func registerForCloudKitPush() async throws {
    let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge])
    if granted {
        UIApplication.shared.registerForRemoteNotifications()
    }
    try await subscriptionManager.ensureSubscriptionExists()
}
```

Note: Silent background pushes (`shouldSendContentAvailable = true`) still require calling `registerForRemoteNotifications()`, even without user-visible alert authorization.

## Subscription Manager Pattern

```swift
actor SubscriptionManager {
    private let subscriptionKey = "cloudkit.subscription.created"
    private let database: CKDatabase

    init(database: CKDatabase) {
        self.database = database
    }

    func ensureSubscriptionExists() async throws {
        guard !UserDefaults.standard.bool(forKey: subscriptionKey) else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: "all-changes")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
        UserDefaults.standard.set(true, forKey: subscriptionKey)
    }
}
```

If legacy `CKModifySubscriptionsOperation` is used, prefer `operation.modifySubscriptionsResultBlock` (`Result<Void, any Error>`) rather than the deprecated `modifySubscriptionsCompletionBlock`.

## Review Questions

1. Is a specific `subscriptionID` used to prevent duplicates (or does `CKSyncEngine` manage subscriptions automatically)?
2. Is `notificationInfo` properly configured before saving?
3. Is the correct subscription type used for the database (shared needs `CKDatabaseSubscription`)?
4. Are predicate fields indexed in CloudKit Dashboard?
5. Is `shouldSendContentAvailable` set for silent notifications (without `alertBody`)?
6. Does the app handle coalesced notifications (not 1:1 with changes)?
7. Is there fallback sync logic for when notifications don't arrive?
8. Is the schema deployed to production before App Store release?
