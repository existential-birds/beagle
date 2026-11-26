# Shortcuts Integration

## AppShortcutsProvider

Registers intents for automatic discovery in Shortcuts app and Siri:

```swift
struct LibraryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCurrentlyReading(),
            phrases: [
                "Open Currently Reading in \(.applicationName)",
                "Show my reading list in \(.applicationName)"
            ],
            shortTitle: "Open Reading List",
            systemImageName: "books.vertical.fill"
        )
    }
}
```

| Property | Required | Purpose |
|----------|----------|---------|
| `intent` | Yes | The AppIntent instance to invoke |
| `phrases` | Yes | Siri trigger phrases (must include app name) |
| `shortTitle` | Yes | Brief description for UI |
| `systemImageName` | Yes | SF Symbol for visual display |

### Refreshing Dynamic Shortcut Parameters

Because the system caches `AppShortcutsProvider` definitions, call `updateAppShortcutParameters()` on launch (in `App.init()` / `AppDelegate`) and whenever dynamic entity sets used in shortcut phrases change:

```swift
@main
struct LibraryApp: App {
    init() {
        LibraryAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

## Phrase Requirements

**Critical**: Every phrase MUST include `.applicationName`:

```swift
// BAD: Missing app name
phrases: ["Open my books", "Show reading list"]  // Won't be discoverable

// GOOD: Includes app name
phrases: [
    "Open my books in \(.applicationName)",
    "Show reading list with \(.applicationName)"
]
```

**Limits**:
- Maximum 1,000 total phrases per app (including parameter variations)
- Use natural language that reads well when spoken

## Localization

Phrases must be in `AppShortcuts.strings` (or `AppShortcuts.xcstrings` for String Catalogs):

```strings
// AppShortcuts.strings
"Open Currently Reading in ${applicationName}" = "Open Currently Reading in ${applicationName}";
```

**Critical**: Using `Localizable.strings` for phrases does NOT work.

## Parameterized Phrases

Include parameters using `\(.$parameterName)`:

```swift
AppShortcut(
    intent: OpenBook(),
    phrases: [
        "Open \(\.$book) in \(.applicationName)",
        "Read \(\.$book) with \(.applicationName)"
    ],
    shortTitle: "Open Book",
    systemImageName: "book"
)
```

**Warning**: Custom `AppEntity` parameters in phrases may prevent shortcuts from appearing unless backed by `@Parameter` options / `EntityQuery` and refreshed via `updateAppShortcutParameters()`. Test thoroughly.

## iOS 17+ Extensions

Define `AppShortcutsProvider` in an App Intents extension (or app target) when faster headless startup is needed:

```swift
// In App Intents Extension target
struct BookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] { ... }
}
```

Extensions skip UI, analytics, and non-critical initialization.

## Discovery Issues

Common reasons shortcuts don't appear:

| Issue | Solution |
|-------|----------|
| Missing in Shortcuts app | Check Project Target > General > Supported Intents |
| Xcode version mismatch | Try Xcode beta or release; use `xcode-select` |
| App Intents in Swift Package | Move to main app bundle (pre-iOS 17) |
| Release build issues | Mark all App Intents as `public` if across module boundaries |
| Stale dynamic phrases | Call `AppShortcutsProvider.updateAppShortcutParameters()` |
| Metadata processor failure | Simplify custom types; check build logs |

## Migration from SiriKit

When migrating from `INIntent` to `AppIntent`, conform to `CustomIntentMigratedAppIntent` and provide a non-optional `static var intentClassName: String`:

```swift
@available(iOS 17, *)
struct OpenBookIntent: AppIntent, CustomIntentMigratedAppIntent {
    static var title: LocalizedStringResource = "Open Book"
    static var intentClassName: String = "OpenBookIntent"

    func perform() async throws -> some IntentResult {
        .result()
    }
}
```

**Warning**: `CustomIntentMigratedAppIntent` breaks iOS 16 targets if deployed below its supported availability.

## Multilingual Considerations

- App names in different languages than Siri's language cause recognition failures
- Test with Siri language matching app language settings
- Consider region-specific phrase variations

## Critical Anti-Patterns

```swift
// BAD: Phrase without app name
AppShortcut(
    intent: OpenBook(),
    phrases: ["Open my book"],  // Not discoverable by Siri
    ...
)

// GOOD: App name included
AppShortcut(
    intent: OpenBook(),
    phrases: ["Open my book in \(.applicationName)"],
    ...
)
```

```swift
// BAD: Localization in wrong file
// Localizable.strings - WRONG FILE
"Open book" = "Open book";

// GOOD: Use AppShortcuts.strings or AppShortcuts.xcstrings
// AppShortcuts.strings - CORRECT FILE
"Open book in ${applicationName}" = "Open book in ${applicationName}";
```

```swift
// BAD: Complex entity parameter in phrase (may fail)
AppShortcut(
    intent: ProcessBook(),
    phrases: ["Process \(\.$complexEntity) in \(.applicationName)"],
    ...
)

// GOOD: Simple parameters or none
AppShortcut(
    intent: ProcessBook(),
    phrases: ["Process current book in \(.applicationName)"],
    ...
)
```

## Review Questions

1. **Do all phrases include `.applicationName`?** Required for Siri discovery.
2. **Is `AppShortcutsProvider.updateAppShortcutParameters()` called on launch and after dynamic entity changes?**
3. **Are phrases in `AppShortcuts.strings` / `AppShortcuts.xcstrings`?** `Localizable.strings` doesn't work.
4. **Is the app bundle correct?** Swift Package intents won't appear on pre-iOS 17 targets.
5. **Is migration handled carefully?** `CustomIntentMigratedAppIntent` requires non-optional `intentClassName: String` and availability checks.
