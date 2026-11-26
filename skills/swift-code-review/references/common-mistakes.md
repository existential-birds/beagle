# Swift Common Mistakes

Focus on non-obvious lifetime, safety, and Swift-specific traps rather than basic syntax.

## Critical Anti-Patterns

### 1. Force Unwraps (`!`) and IUOs on Runtime Data

Flag `!` when the value comes from runtime data (network payloads, JSON decoding, user input, file I/O, dictionaries, collection subscripts). Compile-time literals (`URL(string: "https://apple.com")!`, static `Regex`) and `@IBOutlet` properties are acceptable exceptions.

```swift
// BAD - crashes on malformed runtime input or empty collections
let url = URL(string: response.avatarURL)!
let first = response.items.first!

// BAD - IUO on non-IBOutlet model property hides uninitialized state
final class UserProfile {
    var sessionToken: String!
}

// GOOD - safe unwrapping with recovery
guard let url = URL(string: response.avatarURL) else {
    logger.warning("Invalid avatar URL")
    return
}
```

### 2. Escaping Closure Retain Cycles

Stored or long-lived escaping closures (`onComplete`, `NotificationCenter` observers, `Timer`, Combine `sink`) capture `self` strongly unless `[weak self]` is specified. (Note: non-escaping closures and one-shot `URLSession`/animation completions only retain `self` until completion—focus on stored callbacks and long-lived streams.)

```swift
// BAD - closure stored on self or child creates a permanent retain cycle
final class Coordinator {
    var onComplete: (() -> Void)?
    func setup() {
        onComplete = { self.finish() }
    }
}

// GOOD - weak capture
onComplete = { [weak self] in
    self?.finish()
}
```

### 3. `unowned self` When Lifetime Is Not Strictly Guaranteed

`unowned` crashes with a fatal trap if the referenced object is deallocated before the closure executes (common in async callbacks, delayed dispatches, or `NotificationCenter` blocks).

```swift
// BAD - crashes if ViewModel deallocates before network/timer fires
api.fetch { [unowned self] result in
    self.handle(result)
}

// GOOD - use weak capture unless parent strictly outlives the closure
api.fetch { [weak self] result in
    guard let self else { return }
    self.handle(result)
}
```

### 4. Non-Weak Delegates (Including SwiftUI Coordinators)

Delegate properties between a child/controller/service and its owning parent must be `weak` (requiring `AnyObject` protocol constraint).

```swift
// BAD - strong delegate creates retain cycle with owning parent
protocol PickerDelegate {  // Not AnyObject-constrained
    func didSelect(_ item: Item)
}
final class PickerController {
    var delegate: PickerDelegate?
}

// GOOD - AnyObject + weak
protocol PickerDelegate: AnyObject {
    func didSelect(_ item: Item)
}
final class PickerController {
    weak var delegate: PickerDelegate?
}
```

### 5. `NotificationCenter` / KVO Observer Leaks

Legacy `addObserver(forName:object:queue:using:)` returns an opaque `NSObjectProtocol` token that is retained until explicitly removed with `removeObserver(_:)`; modern code should prefer `NotificationCenter.default.notifications(named:)` inside a `.task` or cancelled `Task`.

```swift
// BAD - token never stored or removed, closure captures self strongly
NotificationCenter.default.addObserver(forName: .didUpdate, object: nil, queue: .main) { _ in
    self.reload()
}

// GOOD - structured async sequence bound to view/task lifetime
for await _ in NotificationCenter.default.notifications(named: .didUpdate) {
    reload()
}
```

## Review Questions

1. Is any force unwrap (`!`) or IUO operating on runtime data rather than a compile-time literal or `@IBOutlet`?
2. Could a stored closure, timer, or observer token retain `self` strongly?
3. Is `unowned` used across an async boundary where `self` could deallocate first?
4. Are all delegate properties constrained to `AnyObject` and marked `weak`?
