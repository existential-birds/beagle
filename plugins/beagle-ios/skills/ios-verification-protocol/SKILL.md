---
name: ios-verification-protocol
description: Swift, SwiftUI, and Apple-platform delta to the shared review verification protocol. Extends `beagle-core:review-verification-protocol` — load that skill first for the hard gates, Pre-Report Verification Checklist, severity calibration, and language-neutral verification rules, then load this one for iOS-specific verification of Swift concurrency, SwiftUI lifecycle, optionals and memory semantics, and fast-moving Apple SDK APIs. Load before reporting ANY Swift or iOS code review findings.
user-invocable: false
---

# Review Verification Protocol — Swift / iOS delta

**Load `beagle-core:review-verification-protocol` first.** It carries the hard gates, the Pre-Report Verification Checklist, Severity Calibration, the imported `beagle-core:verification-budget` vocabulary (risk tiers, loop budgets, the one-echo rule, the prove-a-negative ban), and the language-neutral Verification by Issue Type sections.

This file adds **only** what is specific to Swift, SwiftUI, and the Apple platforms. Everything else is in the core; nothing here overrides it.

Apple APIs evolve quickly (Swift concurrency, SwiftUI lifecycle, new SDKs). When syntax may have changed, confirm against current Apple documentation before flagging.

## Verification by Issue Type — iOS specifics

### "Unused Variable/Function"

Run the core's four-pattern reference search. Apple-platform reference patterns that plain grep misses:

- `public`/`open` symbols used by another module, target, or app extension (SPM)
- Objective-C runtime references: `@objc`, `#selector`, key paths, `NSClassFromString`
- References from Interface Builder, storyboards, asset catalogs, `#Preview`, or test targets
- Delegate and protocol members the framework invokes by contract

**Common false positives:** SwiftUI state (`@State`, `@Binding`, `@Observable`) that drives updates even when the binding looks unused in one branch.

### "Missing Validation/Error Handling"

Check whether responsibility already sits with the parent `ViewModel`, a coordinator, the app or scene delegate, or a type-level guarantee (`Codable`, property wrappers, `URLSession` APIs). Errors that surface via a delegate, a Combine pipeline, or a single alert coordinator do not need local `do/catch` at every call.

### "Type Assertion/Unsafe Cast"

An annotation is not a forced unwrap, and `as?` binding is safe narrowing:

```swift
// Type annotation, NOT a forced unwrap
let data: UserData = await loader()

// Type narrowing makes this safe
if let user = data as? User {
  user.name  // Swift knows this is User
}
```

### "Potential Memory Leak / Race Condition"

- Cleanup may live in `deinit`, `onDisappear`, `cancel()`, or a cancellable-store teardown elsewhere
- Check `Task` cancellation, `AsyncSequence` termination, or Combine subscription disposal after awaits
- Confirm the view or object can actually deallocate during the async operation
- `[weak self]` / `[unowned self]` may already be present where needed

### "Performance Issue"

Confirm the code runs in a SwiftUI `body` or layout pass rather than a one-off action, and that Instruments or a clear hot path justifies the change. SwiftUI diffing, lazy containers, and `@Observable` granularity already mitigate many suspected issues.

**Do NOT flag:** allocations in infrequent actions (sheet presentation, button tap), linear work on small collections without evidence of scale, short-lived value types in event handlers absent profiling.

## Valid Patterns (Do NOT Flag)

### Swift

| Pattern | Why It's Valid |
|---------|----------------|
| `guard let` early return | Standard Swift unwrapping, not excessive nesting |
| `weak self` in closures | Required for breaking retain cycles, not unnecessary |
| `@State` / `@Binding` property wrappers | SwiftUI state management primitives |
| Optional chaining (`foo?.bar?.baz`) | Safe access pattern, not error suppression |
| `as?` conditional cast | Safer than a force cast, correct for type narrowing |

### SwiftUI

| Pattern | Why It's Valid |
|---------|----------------|
| `@StateObject` in parent, `@ObservedObject` in child | Correct ownership pattern |
| View body computed property without caching | SwiftUI manages re-rendering efficiently |
| `AnyView` for heterogeneous lists | Valid when `@ViewBuilder` or generics aren't practical |
| `EnvironmentObject` injection | Standard SwiftUI dependency injection |
| `PreferenceKey` for child-to-parent data | Correct alternative to callbacks for layout data |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| `XCTAssertEqual` without a custom message | Default messages are often sufficient |
| `async let` in test methods | Valid for concurrent test setup |
| `@MainActor` test classes | Required when testing UI-bound code |
| Mock objects without protocol conformance | Simple test doubles are acceptable |

Generated Swift, SPM vendored sources, and Xcode-generated files are library code — do not flag them.

## Context-Sensitive Rules

Each list below is an enumerated check, evaluated once. If an item is undecidable, drop the finding or ship it as a question — do not open another verification pass.

### Swift Optionals

Flag a force unwrap (`!`) **ONLY IF ALL** of these hold:
- [ ] The value CAN actually be nil at runtime
- [ ] No prior `guard let` or `if let` protects the access
- [ ] Not in test code or a prototype
- [ ] Not an `@IBOutlet` (conventionally force-unwrapped)

### View Body Complexity

Flag a complex View body **ONLY IF**:
- [ ] The body exceeds 40 lines
- [ ] Nested components could be extracted without losing clarity
- [ ] Performance profiling shows actual rendering issues
- [ ] Not a leaf view with minimal composition

### Error Handling

Flag a missing `do/catch` **ONLY IF**:
- [ ] No `Result` type wraps the throwing call
- [ ] No higher-level error handler catches this
- [ ] The error would cause a crash, not just a failed operation
- [ ] The user needs specific feedback for this error type
