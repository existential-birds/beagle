# State Management

## Property Wrapper Quick Reference

| iOS Version | View Creates Object | View Receives Object | Two-Way Binding |
|-------------|---------------------|---------------------|-----------------|
| < iOS 17 | `@StateObject` | `@ObservedObject` | `@Binding` |
| iOS 17+ | `@State` (for @Observable) | Plain property | `@Bindable` |

## @StateObject vs @ObservedObject

Use @StateObject when the view creates and owns the object. Use @ObservedObject when passed from a parent.

```swift
// BAD - recreated on every view rebuild
struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()  // Wrong!
}

// GOOD - survives view rebuilds
struct ContentView: View {
    @StateObject var viewModel = ViewModel()
}

// GOOD - received from parent
struct ChildView: View {
    @ObservedObject var viewModel: ViewModel  // Not creating it
}
```

## iOS 17+ @Observable Pattern

With @Observable, use @State at app level, plain properties in children.

```swift
@Observable class AppStore { /* ... */ }

@main
struct MyApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup { ContentView(store: store) }
    }
}

// Child receives without wrapper
struct ChildView: View {
    var store: AppStore  // Read-only access
}

// For two-way bindings, use @Bindable
struct EditView: View {
    @Bindable var user: User
    var body: some View {
        TextField("Name", text: $user.name)
    }
}
```

## @State Mistakes

```swift
// BAD - @State ignores external updates
struct ChildView: View {
    @State var user: User  // Updates from parent ignored!
}

// BAD - property observers don't work
@State var count = 0 {
    didSet { print("Changed") }  // Never called!
}

// GOOD - use .onChange modifier
.onChange(of: count) { oldValue, newValue in
    print("Changed from \(oldValue) to \(newValue)")
}
```

## Environment Usage (iOS 17+)

```swift
// Old syntax
@Environment(\.modelContext) private var context

// New syntax for custom types
@Environment(AuthService.self) private var authService
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| `@ObservedObject var vm = ViewModel()` | Creates new object on rebuild |
| `@State var model: SomeClass` | Reference types need @StateObject |
| `@State` in child for passed data | Ignores parent updates |
| didSet on @State | Property observers don't fire |
| Missing @Bindable for bindings | Can't bind to @Observable properties |

## Review Questions

1. Is @StateObject used when the view creates the object?
2. Is @ObservedObject only used for objects passed from parent?
3. For iOS 17+, is @State with @Observable in a stable parent view?
4. Is @Bindable used where two-way bindings are needed?
5. Is .onChange used instead of didSet on @State?
