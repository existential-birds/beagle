# Swift Observation Framework (`@Observable`)

This reference focuses on **`@Observable` macro design, tracking semantics, and actor isolation**. For SwiftUI property wrapper ownership (`@State`, `@Bindable`, `@Environment`, and legacy `ObservableObject`), see [state-management.md](../../swiftui-code-review/references/state-management.md) in `swiftui-code-review`.

## Critical Anti-Patterns

### 1. Expensive or Side-Effecting `init()` with `@State`

In SwiftUI, `@State private var viewModel = ViewModel()` in an owning `View` **is** Apple's recommended pattern (replacing `@StateObject`). SwiftUI preserves the first stored instance across view updates, **but** unlike `@StateObject` (`@autoclosure`), `@State`'s initial value expression is evaluated eagerly every time the parent recreates the `View` struct.

```swift
// BAD - heavy work or side effects run on every View struct initialization, even though result is discarded
@Observable
final class HeavyViewModel {
    init() {
        loadFromDiskSynchronously()  // Re-runs on every parent re-render!
        Analytics.track(.screenInit) // Duplicate side effects!
    }
}

struct ContentView: View {
    @State private var viewModel = HeavyViewModel()
}

// GOOD - keep @Observable init() cheap and pure; defer loading to .task
@Observable
@MainActor
final class ProfileViewModel {
    var profile: Profile?
    init() {}

    func load() async {
        profile = try? await service.fetchProfile()
    }
}

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    var body: some View {
        ContentView(viewModel: viewModel)
            .task { await viewModel.load() }
    }
}
```

### 2. Property Wrappers Without `@ObservationIgnored`

`@Observable` rewrites stored properties into computed accessors backed by `_property` storage, which conflicts with other property wrappers unless excluded.

```swift
// BAD - property wrapper conflicts with @Observable macro expansion
@Observable
final class ViewModel {
    @Injected var repository: Repository  // Compile error
}

// GOOD - exclude non-UI dependencies, Combine cancellables, and timers
@Observable
final class ViewModel {
    @ObservationIgnored
    @Injected var repository: Repository

    @ObservationIgnored
    private var observationTask: Task<Void, Never>?
}
```

### 3. Non-Observable Nested Reference Types

`@Observable` tracks property mutations on the annotated class itself, not stored properties inside nested non-`@Observable` reference types. (Value types like `struct` *do* trigger updates when mutated via a `var` property on the `@Observable` parent.)

```swift
// BAD - mutating item.name won't notify views observing store.items
@Observable
final class Store {
    var items: [Item] = []
}
final class Item {
    var name: String = ""
}

// GOOD - mark nested reference types @Observable, or use structs
@Observable
final class Store {
    var items: [Item] = []
}
@Observable
final class Item {
    var name: String = ""
}
```

### 4. `@Observable` on `struct`

`@Observable` requires reference semantics (`class`) and does not apply to `struct` or `actor`.

```swift
// BAD - compile error
@Observable
struct UserState {
    var name: String = ""
}
```

### 5. Missing `@MainActor` Isolation on UI Models

UI-facing `@Observable` models mutated from async tasks must be isolated to `@MainActor` (explicitly, or via Swift 6.2 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) so state mutations never race off the main thread.

```swift
// BAD - mutating tracked state from background Task races with SwiftUI reads
@Observable
final class FeedViewModel {
    var posts: [Post] = []
    func refresh() async {
        posts = await api.fetchPosts()  // Off-main mutation if non-isolated!
    }
}

// GOOD - isolate UI model to @MainActor
@Observable
@MainActor
final class FeedViewModel {
    var posts: [Post] = []
    func refresh() async {
        posts = await api.fetchPosts()
    }
}
```

### 6. Computed Properties Reading `@ObservationIgnored` State

SwiftUI only invalidates views for computed properties when the underlying stored properties they read are tracked by `@Observable`.

```swift
// BAD - view never updates when cachedCount changes
@Observable
final class CounterModel {
    @ObservationIgnored private var rawCount = 0
    var displayCount: String { "\(rawCount)" }  // Never triggers observation!
}
```

### 7. `withObservationTracking` `willSet` and Single-Shot Semantics

`withObservationTracking` fires `onChange` **before** the property mutates (`willSet`), inside a `@Sendable` closure, and **only once** per registration.

```swift
// BAD - reads the OLD value and never re-subscribes
withObservationTracking {
    _ = model.name
} onChange: {
    print(model.name)  // Prints old value; only fires once!
}

// GOOD - hop to @MainActor to read the post-mutation value (and re-register if continuous observation is needed)
func observeName() {
    withObservationTracking {
        _ = model.name
    } onChange: {
        Task { @MainActor [weak self] in
            guard let self else { return }
            print(self.model.name)  // Has new value
            self.observeName()      // Re-register for subsequent changes
        }
    }
}
```

## Quick Notes on Wrapper Interactions

- Use `@ObservationIgnored` for injected dependencies, `Timer`, `Task` handles, and `AnyCancellable` sets so `@Observable` doesn't synthesize unnecessary tracking overhead.
- Never stack `@Bindable @Environment(AppSettings.self)` on one property—read `@Environment(AppSettings.self)` and create `@Bindable var settings = settings` inside `body` (see [state-management.md](../../swiftui-code-review/references/state-management.md) in `swiftui-code-review`).

## Review Questions

1. Does any `@Observable` class initialized with `@State` perform expensive I/O or side effects in `init()`?
2. Are injected dependencies, `Task` handles, and property wrappers marked `@ObservationIgnored`?
3. Are nested mutable reference types inside `@Observable` models also marked `@Observable`?
4. Are UI-driving `@Observable` classes isolated to `@MainActor`?
5. Do `withObservationTracking` `onChange` closures avoid reading old values synchronously or expecting repeated callbacks without re-registration?
