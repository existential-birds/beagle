# State Management

This reference focuses on **SwiftUI property wrapper ownership**. For `@Observable` macro internals (`@ObservationIgnored`, `withObservationTracking`, actor isolation), see [observable.md](../../swift-code-review/references/observable.md) in `swift-code-review`.

## Property Wrapper Quick Reference

| Framework / Target | View Creates & Owns | View Receives (Read-Only) | Two-Way Binding | Environment |
|---|---|---|---|---|
| **iOS 17+ `@Observable` (Preferred)** | `@State` | Plain property (`let`/`var`) | `@Bindable` | `@Environment(Type.self)` |
| **Legacy `ObservableObject` (`< iOS 17` / Combine)** | `@StateObject` | `@ObservedObject` | `@Binding` (on value properties) | `@EnvironmentObject` |

## iOS 17+ `@Observable` Pattern (Preferred)

Use `@State` in the view (or `App`) that **creates and owns** the `@Observable` instance. SwiftUI preserves that stored instance across view updates. However, unlike `@StateObject` (`@autoclosure`), `@State` evaluates its initial value expression eagerly whenever the parent recreates the `View` struct—so keep `@Observable` `init()` cheap and side-effect-free, or construct heavy stores higher up (e.g. `@main App`) and pass them down.

```swift
@Observable
@MainActor
final class Store {
    var items: [Item] = []
    init() {}
}

// Owning view (or App) uses @State
struct StoreView: View {
    @State private var store = Store()

    var body: some View {
        ChildListView(store: store)
            .task { await store.load() }
    }
}

// Child receives read-only access without a wrapper
struct ChildListView: View {
    var store: Store

    var body: some View {
        List(store.items) { item in Text(item.name) }
    }
}

// Child needing two-way $bindings uses @Bindable
struct EditUserView: View {
    @Bindable var user: User

    var body: some View {
        TextField("Name", text: $user.name)
    }
}
```

### `@Environment` + `@Bindable`

```swift
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Toggle("Dark Mode", isOn: $settings.darkMode)
    }
}
```

## Legacy `ObservableObject` (`@StateObject` vs `@ObservedObject`)

For pre-iOS 17 deployment targets or Combine `ObservableObject` models, use `@StateObject` when the view creates the object and `@ObservedObject` when passed from a parent.

```swift
// BAD - recreated on every view rebuild
struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()  // Wrong!
}

// GOOD - survives view rebuilds
struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
}

// GOOD - received from parent
struct ChildView: View {
    @ObservedObject var viewModel: ViewModel  // Not creating it
}
```

## `@State` Mistakes

```swift
// BAD - @State ignores external updates from parent
struct ChildView: View {
    @State var user: User  // Preserves first value, ignores parent changes!
}

// BAD - property observers don't work on @State
@State var count = 0 {
    didSet { print("Changed") }  // Never called!
}

// GOOD - use .onChange modifier
.onChange(of: count) { oldValue, newValue in
    print("Changed from \(oldValue) to \(newValue)")
}
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| Heavy/side-effecting `init()` in `@State var vm = VM()` | `@State` evaluates initial value eagerly on parent re-evaluation |
| `@State` in child for parent-passed model | Ignores parent updates |
| Missing `@Bindable` for `$model.prop` | Cannot derive bindings from `@Observable` properties |
| `@ObservedObject var vm = ViewModel()` | Recreates `ObservableObject` on every view rebuild |
| `@State var model: ObservableObjectClass` | Value-type wrapper won't observe `ObservableObject` `objectWillChange` |
| `didSet` on `@State` | Property observers don't fire; use `.onChange` |

## Review Questions

1. For `@Observable`, is `@State` used only in the owning view (with a lightweight `init()`), plain properties in read-only children, and `@Bindable` for two-way bindings?
2. For legacy `ObservableObject`, is `@StateObject` used by the creator and `@ObservedObject` by children?
3. Are child views accidentally wrapping passed-in models with `@State`?
4. Is `.onChange(of:)` used instead of `didSet` on `@State`?
