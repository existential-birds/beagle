# WatchKit App Lifecycle

## Lifecycle Architecture

watchOS uses two lifecycle models:

### SwiftUI App Protocol (Modern)

```swift
@main
struct MyWatchApp: App {
    @WKApplicationDelegateAdaptor var appDelegate: MyAppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### WKApplicationDelegate

Use for lifecycle events not covered by SwiftUI's `scenePhase`. Note: `WKExtensionDelegate` was renamed to `WKApplicationDelegate` in Xcode 14.

### Scene Phase States

| State | Description |
|-------|-------------|
| `.active` | App in foreground, user can interact |
| `.inactive` | Visible but no interaction (wrist lowered, screen on) |
| `.background` | Not visible, may be terminated |

**Note**: On watchOS, `.inactive` does NOT mean the app isn't running.

## Background Execution Modes

| Mode | Use Case | Constraints |
|------|----------|-------------|
| `BGAppRefreshTask` | Data updates | 4 per hour; 4s CPU, 15s total |
| `HKWorkoutSession` | Workout tracking | Continuous; use for workouts only |
| `WKExtendedRuntimeSession` | Self-care, mindfulness | Start while active only |
| Background URLSession | Downloads | Requires complication or dock |

### WKExtendedRuntimeSession Types

| Type | Duration | Notes |
|------|----------|-------|
| Self Care | 10 minutes | |
| Mindfulness | 1 hour | |
| Physical Therapy | 1 hour | Allows background multitasking |
| Health Monitoring | Variable | Requires entitlement |
| Alarm | 30 minutes | Use `startAtDate()` to schedule |

## Critical Anti-Patterns

### 1. Heavy Work in Lifecycle Methods

```swift
// BAD: Slows resume time
func applicationDidBecomeActive() {
    loadAllDataFromDisk()
    syncWithServer()
}

// GOOD: Defer to background
func applicationDidBecomeActive() {
    Task.detached(priority: .background) {
        await self.prefetchData()
    }
}
```

### 2. Reading scenePhase in Sheets

```swift
// BAD: Always returns .active in sheets
struct SettingsSheet: View {
    @Environment(\.scenePhase) var scenePhase  // Broken!
}

// GOOD: Pass from root view
struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Button("Settings") { showSettings = true }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(scenePhase: scenePhase)
            }
    }
}
```

### 3. Starting Extended Sessions from Background

```swift
// BAD: Cannot start from background
func applicationDidEnterBackground() {
    let session = WKExtendedRuntimeSession()
    session.start()  // Error!
}

// GOOD: Start while active
func startMindfulnessSession() {
    guard WKApplication.shared().applicationState == .active else { return }
    extendedSession = WKExtendedRuntimeSession()
    extendedSession?.start()
}
```

### 4. Not Recovering Workout Sessions

```swift
// BAD: handleActiveWorkoutRecovery NOT called on reboot
class AppDelegate: NSObject, WKApplicationDelegate {
    func handleActiveWorkoutRecovery() {
        recoverWorkout()
    }
}

// GOOD: Check in applicationDidFinishLaunching
func applicationDidFinishLaunching() {
    Task {
        do {
            let (session, builder) = try await HKHealthStore().recoverActiveWorkoutSession()
            workoutManager.resume(session: session, builder: builder)
        } catch {
            // No session to recover
        }
    }
}
```

### 5. Network Calls During Background Transition

```swift
// BAD: Not enough time
func applicationWillResignActive() {
    URLSession.shared.dataTask(with: url) { ... }  // Won't complete
}

// GOOD: Use expiring activity
func applicationWillResignActive() {
    ProcessInfo.processInfo.performExpiringActivity(withReason: "Sync") { expired in
        guard !expired else { return }
        self.quickSync()
    }
}
```

## Background App Refresh

### Correct Pattern

```swift
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
            // 1. Schedule next FIRST
            scheduleNextRefresh()

            // 2. Use download task (not data task)
            let config = URLSessionConfiguration.background(withIdentifier: "com.app.refresh")
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            session.downloadTask(with: url).resume()

            // 3. Complete this task
            refreshTask.setTaskCompletedWithSnapshot(false)
        }
    }
}

func scheduleNextRefresh() {
    // At least 5 minutes in future
    let preferredDate = Date().addingTimeInterval(5 * 60)
    WKApplication.shared().scheduleBackgroundRefresh(
        withPreferredDate: preferredDate,
        userInfo: nil
    ) { _ in }
}
```

## Review Questions

1. Is SwiftUI App protocol used with `@WKApplicationDelegateAdaptor` for lifecycle events?
2. Is `scenePhase` read from root view (not sheets/modals)?
3. Are extended runtime sessions started only while app is active?
4. Is `HKHealthStore().recoverActiveWorkoutSession()` called in `applicationDidFinishLaunching`?
5. Are background tasks scheduled at least 5 minutes apart?
6. Is `URLSessionDownloadTask` (not `DataTask`) used for background network?
7. Is next refresh scheduled BEFORE completing current task?
