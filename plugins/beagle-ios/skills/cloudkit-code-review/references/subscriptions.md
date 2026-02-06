# CloudKit Subscriptions

## Subscription Types

| Type | Use Case | Database Support |
|------|----------|------------------|
| **CKQuerySubscription** | Records matching predicate | Public, Private (default zone) |
| **CKRecordZoneSubscription** | All changes in custom zone | Private only |
| **CKDatabaseSubscription** | All changes across database | Private, Shared |

**Recommendation:** Start with `CKDatabaseSubscription` unless only using default zone.

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
    database.save(subscription) { _, _ in }
}

// GOOD: Check before creating, use consistent ID
let subscriptionID = "item-creation-subscription"

database.fetch(withSubscriptionID: subscriptionID) { subscription, error in
    if subscription == nil {
        let newSubscription = CKQuerySubscription(
            recordType: "Item",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: .firesOnRecordCreation
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        newSubscription.notificationInfo = info
        database.save(newSubscription) { _, _ in }
    }
}
```

### 2. Missing NotificationInfo

```swift
// BAD: Subscription will fail to save
let subscription = CKQuerySubscription(recordType: "Item", predicate: predicate, options: .firesOnRecordCreation)
database.save(subscription) { _, error in }  // Error!

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
sharedDB.save(subscription) { _, error in }  // Error!

// GOOD: Use CKDatabaseSubscription for shared database
let subscription = CKDatabaseSubscription(subscriptionID: "shared-db-subscription")
let info = CKSubscription.NotificationInfo()
info.shouldSendContentAvailable = true
subscription.notificationInfo = info
sharedDB.save(subscription) { _, _ in }
```

### 4. Relying Solely on Push for Sync

```swift
// BAD: Only syncing when push arrives
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    syncData()  // Only sync trigger
}

// GOOD: Multiple sync triggers
func applicationDidBecomeActive(_ application: UIApplication) {
    syncData()  // On app launch
}

func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    syncData()  // On notification
}
// Also implement background fetch
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
// 1. Request authorization
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    // 2. Register for remote notifications
    DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

// 3. Create subscription after registration
subscriptionManager.ensureSubscriptionExists()
```

## Subscription Manager Pattern

```swift
class SubscriptionManager {
    private let subscriptionKey = "cloudkit.subscription.created"

    func ensureSubscriptionExists() {
        guard !UserDefaults.standard.bool(forKey: subscriptionKey) else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: "all-changes")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        operation.modifySubscriptionsCompletionBlock = { saved, _, error in
            if error == nil {
                UserDefaults.standard.set(true, forKey: self.subscriptionKey)
            }
        }
        database.add(operation)
    }
}
```

## Review Questions

1. Is a specific `subscriptionID` used to prevent duplicates?
2. Is `notificationInfo` properly configured before saving?
3. Is the correct subscription type used for the database (shared needs CKDatabaseSubscription)?
4. Are predicate fields indexed in CloudKit Dashboard?
5. Is `shouldSendContentAvailable` set for silent notifications (without alertBody)?
6. Does the app handle coalesced notifications (not 1:1 with changes)?
7. Is there fallback sync logic for when notifications don't arrive?
8. Is the schema deployed to production before App Store release?
