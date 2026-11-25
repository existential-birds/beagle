# Transition Review Patterns

## matchedGeometryEffect Issues

### Duplicate IDs in Same Namespace

Only one view with a given ID should be in the view hierarchy at a time. Two visible views sharing an ID causes undefined geometry matching.

```swift
// BUG — both views visible with same ID
ZStack {
    SourceView()
        .matchedGeometryEffect(id: "card", in: namespace)
        .opacity(isExpanded ? 0 : 1)  // Opacity 0 still counts as "in hierarchy"
    DestinationView()
        .matchedGeometryEffect(id: "card", in: namespace)
        .opacity(isExpanded ? 1 : 0)
}

// GOOD — conditional, only one in hierarchy
if isExpanded {
    DestinationView()
        .matchedGeometryEffect(id: "card", in: namespace)
} else {
    SourceView()
        .matchedGeometryEffect(id: "card", in: namespace)
}
```

### Unstable IDs

The matched ID must be stable across the transition. Using array indices or computed values that change during the animation breaks the match.

```swift
// BAD — index changes when array mutates
ForEach(Array(items.enumerated()), id: \.offset) { index, item in
    ItemView(item: item)
        .matchedGeometryEffect(id: index, in: namespace)  // Index shifts on delete
}

// GOOD — stable model ID
ForEach(items) { item in
    ItemView(item: item)
        .matchedGeometryEffect(id: item.id, in: namespace)
}
```

### Missing isSource

When matching position and size separately (rare but valid), one side must be `isSource: true` and the other `isSource: false`. When matching both together (common case), both default to `isSource: true` which works correctly.

### Namespace Scope

`@Namespace` must be declared in the common ancestor view that contains both the source and destination. Passing namespaces between unrelated view hierarchies doesn't work.

## Custom Transition Protocol

### TransitionPhase Misunderstanding

`TransitionPhase` has three cases. `.willAppear` is the "before" state for insertion, `.didDisappear` is the "after" state for removal, and `.identity` is the normal presented state.

```swift
// BUG — this makes the view invisible in its identity state
struct BrokenTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase == .willAppear ? 0 : 1)
            // Removal: .didDisappear gets opacity 1, then view disappears without fade
    }
}

// GOOD — both insertion and removal handled
struct CorrectTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)  // 0 for both willAppear and didDisappear
            .scaleEffect(phase.isIdentity ? 1 : 0.8)
    }
}
```

### Asymmetric Behavior

If insertion and removal should look different, use `.asymmetric()` or check the specific phase.

```swift
struct AsymmetricSlide: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .offset(
                x: phase == .willAppear ? 100 :    // Enter from right
                   phase == .didDisappear ? -100 :  // Exit to left
                   0                                 // Identity
            )
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
```

## Zoom Navigation Transition (iOS 18+)

### Missing matchedTransitionSource

`.navigationTransition(.zoom(sourceID:in:))` on the destination requires `.matchedTransitionSource(id:in:)` on the source. Without it, the zoom has no origin point and falls back to a standard push.

```swift
// BUG — missing source
NavigationLink {
    DetailView()
        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
} label: {
    ItemCell()
    // No .matchedTransitionSource — zoom won't work
}

// GOOD
NavigationLink {
    DetailView()
        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
} label: {
    ItemCell()
        .matchedTransitionSource(id: item.id, in: namespace)
}
```

### ID Mismatch

The `sourceID` in `.navigationTransition(.zoom)` must exactly match the `id` in `.matchedTransitionSource`. Type must also match (both String, both Int, etc.).

### Outside NavigationStack

Zoom transitions require `NavigationStack`. They don't work with the deprecated `NavigationView` or with custom navigation implementations.

## View Transition Timing

### Missing Animation Wrapper

Conditional view changes need `withAnimation` or `.animation(_:value:)` to animate transitions.

```swift
// BUG — no animation, views snap in/out
if showDetail {
    DetailView()
        .transition(.slide)  // Transition defined but never animated
}

// GOOD — wrapped in animation
Button("Show") {
    withAnimation(.spring()) {
        showDetail = true
    }
}
if showDetail {
    DetailView()
        .transition(.slide)
}
```

### Transition on Wrong View

`.transition()` must be on the view being inserted/removed, not the parent.

```swift
// BAD — transition on container, not on the conditional view
VStack {
    if showBanner {
        BannerView()
    }
}
.transition(.slide)  // Does nothing — VStack is always present

// GOOD — transition on the conditional view
VStack {
    if showBanner {
        BannerView()
            .transition(.slide)
    }
}
```

## NavigationStack Path Animation

Programmatic navigation changes should be wrapped in `withAnimation` for smooth transitions.

```swift
// No animation — instant view swap
path.append(destination)

// Animated
withAnimation(.smooth) {
    path.append(destination)
}
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| Two views with same matchedGeometryEffect ID visible simultaneously | Undefined geometry matching |
| `matchedGeometryEffect` with array index as ID | ID shifts when array mutates |
| `.transition()` on a view that's always in the hierarchy | No effect — transitions only fire on insertion/removal |
| `.navigationTransition(.zoom)` without `.matchedTransitionSource` | Falls back to standard push, no zoom |
| Missing `withAnimation` around conditional view state change | Transition defined but never animated |
| Custom Transition that only handles `.willAppear` | Removal has no animation |

## Review Questions

1. For `matchedGeometryEffect` — is only one view with that ID in the hierarchy at a time?
2. Does the custom `Transition` handle both `.willAppear` and `.didDisappear` phases?
3. For zoom navigation — does every `.navigationTransition(.zoom)` have a matching `.matchedTransitionSource` with the same ID?
4. Is the view state change that triggers the transition wrapped in `withAnimation`?
5. Is `.transition()` placed on the conditional view, not its always-present parent?
