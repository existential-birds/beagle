# Swift Observation Framework

## Critical Anti-Patterns

### 1. Incorrect @State Initialization

```swift
// BAD - model recreated on view reconstruction
struct ContentView: View {
    @State private var viewModel = ExpensiveViewModel()  // init() runs repeatedly
}

// GOOD - initialize at App level
@main
struct MyApp: App {
    @State private var viewModel = ExpensiveViewModel()
    var body: some Scene {
        WindowGroup { ContentView(viewModel: viewModel) }
    }
}
```

### 2. Using @State in Child Views

```swift
// BAD - child ignores parent's instance changes
struct ChildView: View {
    @State var model: Model  // Wrong! Preserves first instance

    var body: some View { Text(model.name) }
}

// GOOD - child receives model directly
struct ChildView: View {
    var model: Model  // No wrapper - updates when parent changes

    var body: some View { Text(model.name) }
}
```

### 3. Missing @Bindable for Two-Way Bindings

```swift
// BAD - cannot create binding
struct EditView: View {
    var user: User
    var body: some View {
        TextField("Name", text: $user.name)  // Error: cannot find '$user'
    }
}

// GOOD - use @Bindable
struct EditView: View {
    @Bindable var user: User
    var body: some View {
        TextField("Name", text: $user.name)  // Works
    }
}
```

### 4. Property Wrappers Without @ObservationIgnored

```swift
// BAD - property wrapper conflicts with @Observable
@Observable class ViewModel {
    @Injected var repository: Repository  // Error
}

// GOOD - exclude from observation
@Observable class ViewModel {
    @ObservationIgnored
    @Injected var repository: Repository
}
```

### 5. Nested Objects Not Observable

```swift
// BAD - nested object changes don't trigger updates
@Observable class Store {
    var items: [Item] = []  // Item is regular class
}
class Item { var name: String = "" }

// GOOD - nested types also @Observable
@Observable class Store {
    var items: [Item] = []
}
@Observable class Item { var name: String = "" }
```

### 6. Combining @Environment with @Bindable

```swift
// BAD - cannot combine property wrappers
struct SettingsView: View {
    @Bindable @Environment(AppSettings.self) var settings  // Error
}

// GOOD - create local @Bindable
struct SettingsView: View {
    @Environment(AppSettings.self) var settings
    var body: some View {
        @Bindable var settings = settings
        Toggle("Dark Mode", isOn: $settings.darkMode)
    }
}
```

### 7. withObservationTracking willSet Semantics

```swift
// BAD - onChange gets OLD value
withObservationTracking {
    _ = model.name
} onChange: {
    print(model.name)  // Prints old value!
}

// GOOD - dispatch to get new value
withObservationTracking {
    _ = model.name
} onChange: {
    DispatchQueue.main.async {
        print(model.name)  // Now has new value
    }
}
```

## Migration from ObservableObject

| Before (Combine) | After (Observation) |
|------------------|---------------------|
| `class: ObservableObject` | `@Observable class` |
| `@Published var` | `var` (automatic) |
| `@StateObject` | `@State` |
| `@ObservedObject` | Direct property or `@Bindable` |
| `@EnvironmentObject` | `@Environment(Type.self)` |

## When to Use Each Wrapper

| Wrapper | Use Case |
|---------|----------|
| `@State` | View owns/creates the observable |
| `@Bindable` | Need two-way binding to properties |
| `@Environment` | Access observable from environment |
| `@ObservationIgnored` | Exclude from tracking (DI, Combine, timers) |

## Review Questions

1. Is `@State` only used in the view that creates the object?
2. Are nested observable objects also marked `@Observable`?
3. Is `@Bindable` used when two-way bindings are needed?
4. Are property wrappers marked with `@ObservationIgnored`?
5. Does `init()` have expensive side effects that could repeat?
