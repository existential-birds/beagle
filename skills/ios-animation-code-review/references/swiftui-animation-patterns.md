# SwiftUI Animation Patterns

## withAnimation Scope & Completion (iOS 17+)

`withAnimation` should wrap only the state mutation that drives the animation, not unrelated logic.

```swift
// BAD — animation wraps network call and unrelated state
withAnimation {
    Task { await viewModel.fetchData() }
    selectedTab = .home
    showBanner = false
}

// GOOD — only the visual state change is animated
Task { await viewModel.fetchData() }
withAnimation(.snappy) {
    selectedTab = .home
}
showBanner = false
```

### Completion Callbacks (`withAnimation(_:completionCriteria:_:completion:)`)

On iOS 17+, flag `DispatchQueue.main.asyncAfter` hacks that guess animation duration — use `withAnimation`'s native completion closure (`completionCriteria: .logicallyComplete` or `.removed`):

```swift
// BAD — fragile timing hack instead of SwiftUI completion API
withAnimation(.spring(duration: 0.3)) {
    offset = 1000
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    dismiss()
}

// GOOD — iOS 17+ native completion handler
withAnimation(.spring(duration: 0.3), completionCriteria: .logicallyComplete) {
    offset = 1000
} completion: {
    dismiss()
}
```

## Bridging SwiftUI Animations to UIKit (`context.animate`, iOS 18+)

When a `UIViewRepresentable` (or `UIViewControllerRepresentable`) updates UIKit views inside `updateUIView(_:context:)`, ignoring `context.animate` drops the active SwiftUI transaction's spring/timing curve or snaps changes immediately:

```swift
// BAD — ignores active SwiftUI withAnimation / Transaction
func updateUIView(_ uiView: CustomView, context: Context) {
    uiView.transform = isCollapsed ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
}

// GOOD — iOS 18+ context.animate inherits the SwiftUI transaction animation
func updateUIView(_ uiView: CustomView, context: Context) {
    context.animate {
        uiView.transform = isCollapsed ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
    }
}
```

## Deprecated .animation() Without Value

The parameterless `.animation(_:)` modifier is deprecated. It animates every state change in the view, causing unexpected animations on unrelated properties.

```swift
// BAD — deprecated, animates everything
Text(name)
    .animation(.spring())

// GOOD — explicit value binding
Text(name)
    .animation(.spring(), value: isExpanded)
```

## Spring Parameter Anti-Patterns

| Pattern | Problem |
|---------|---------|
| `.spring(mass:stiffness:damping:)` in SwiftUI | Old API — use `duration`/`bounce` instead |
| `duration: 0` on a spring | Undefined behavior — use `.none` for instant |
| `bounce: 1.0` or higher | Extremely bouncy, likely unintentional — values above 0.5 are unusual |
| `.easeInOut(duration: 0.25)` for interactive feedback | Springs feel more natural for user interactions |

## PhaseAnimator Issues

### Infinite Loop Without Trigger

`PhaseAnimator` without a `trigger` parameter loops continuously. This is intentional for ambient animations but a bug if used for one-shot effects.

```swift
// This loops forever — intentional?
.phaseAnimator([false, true]) { content, phase in
    content.opacity(phase ? 1 : 0.5)
}

// One-shot: add trigger
.phaseAnimator([false, true], trigger: tapCount) { content, phase in
    content.opacity(phase ? 1 : 0.5)
}
```

### Single Phase

A `PhaseAnimator` with only one phase does nothing.

```swift
// BUG — needs at least 2 phases
.phaseAnimator([Phase.idle]) { /* never transitions */ }
```

## KeyframeAnimator Issues

### Mismatched Track Properties

Keyframe tracks must reference properties that exist on the `initialValue` type.

```swift
// BUG — if AnimationValues doesn't have .blur, this crashes
KeyframeTrack(\.blur) { ... }
```

### Missing Duration on Keyframes

Every keyframe needs a `duration`. Omitting it defaults to 0, making the keyframe instant.

```swift
// BAD — instant jump, probably unintentional
SpringKeyframe(1.5)

// GOOD — explicit duration
SpringKeyframe(1.5, duration: 0.3)
```

## Content Transition Misuse

`.contentTransition` is for content changes within a view, not view insertion/removal.

```swift
// BAD — contentTransition on a conditional view
if isVisible {
    Text("Hello")
        .contentTransition(.opacity)  // Wrong — use .transition()
}

// GOOD — for content that changes in place
Text(count, format: .number)
    .contentTransition(.numericText())
```

## Symbol Effect on Non-SF-Symbols

`.symbolEffect` only works with SF Symbols (system images). Applied to custom images, it silently does nothing.

```swift
// No effect — custom image, not SF Symbol
Image("custom-icon")
    .symbolEffect(.bounce, value: count)

// Works — SF Symbol
Image(systemName: "bell.badge")
    .symbolEffect(.bounce, value: count)
```

## Animation Identity vs. Transition

Animating the `.id()` modifier destroys and recreates the view. This is almost never what you want for smooth animation.

```swift
// BAD — destroys view identity, no smooth animation
Text(name)
    .id(currentUser.id)  // View is destroyed and recreated on change
    .animation(.spring(), value: currentUser.id)

// GOOD — transition for view swap
Text(name)
    .transition(.opacity)
    .id(currentUser.id)

// GOOD — matchedGeometryEffect for position/size animation
Text(name)
    .matchedGeometryEffect(id: "title", in: namespace)
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| `.animation()` without `value:` | Deprecated, animates all state changes unpredictably |
| `DispatchQueue.main.asyncAfter` for animation completion | Fragile timing hack — use `withAnimation(_:completionCriteria:_:completion:)` (iOS 17+) |
| `UIViewRepresentable` ignoring `context.animate` | Drops active SwiftUI transaction animation (iOS 18+) |
| `withAnimation` wrapping `Task { }` | Async work doesn't need animation wrapping |
| `PhaseAnimator` with 1 phase | Does nothing — needs >= 2 phases to transition |
| `.symbolEffect` on custom images | Silently fails — only works with SF Symbols |
| Animating `.id()` modifier changes | Destroys view — use `transition` or `matchedGeometryEffect` |
| `spring(bounce: > 0.5)` | Excessively bouncy — verify this is intentional |

## Review Questions

1. Is `.animation()` always paired with a `value:` parameter?
2. Does `withAnimation` scope include only the state mutation, and use `completion:` instead of `asyncAfter` on iOS 17+?
3. Do `UIViewRepresentable` updates use `context.animate` when bridging animated SwiftUI state?
4. Are `PhaseAnimator` phase counts >= 2 and triggered appropriately (continuous vs. one-shot)?
5. Are `KeyframeAnimator` track properties matching the `initialValue` struct?
6. Is `.symbolEffect` only applied to SF Symbols?
