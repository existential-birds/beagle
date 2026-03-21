# Animation Accessibility

## Core HIG Principle

Apple's Human Interface Guidelines state: "Make motion optional. Not everyone can or wants to experience the motion in your app or game, so it's essential to avoid using it as the only way to communicate important information. To help everyone enjoy your app or game, supplement visual feedback by also using alternatives like haptics and audio to communicate."

This means two things: (1) every animation needs a Reduce Motion fallback, and (2) animation should never be the sole feedback channel for important state changes.

## Reduce Motion

Users with vestibular disorders, motion sensitivity, or preference for reduced visual complexity enable Settings → Accessibility → Motion → Reduce Motion. This is not a niche setting — a meaningful percentage of users have it enabled.

Every animation must have a Reduce Motion path. Not "should have" — must have.

### SwiftUI

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Pattern 1: Skip animation
withAnimation(reduceMotion ? .none : .spring()) {
    isExpanded.toggle()
}

// Pattern 2: Simplified animation (crossfade instead of movement)
.animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.5, bounce: 0.3), value: isActive)

// Pattern 3: Conditional modifier
.modifier(ReduceMotionModifier(
    standard: .offset(y: isVisible ? 0 : 20).combined(with: .opacity),
    reduced: .opacity
))
```

### UIKit

```swift
if UIAccessibility.isReduceMotionEnabled {
    // Instant or simple fade
    UIView.animate(withDuration: 0.15) {
        view.alpha = targetAlpha
    }
} else {
    // Full spring animation
    UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
        view.alpha = targetAlpha
        view.transform = targetTransform
    }
}

// Listen for changes
NotificationCenter.default.addObserver(
    forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
    object: nil, queue: .main
) { _ in
    // Update running animations
}
```

## What to Reduce

Not all animation needs removal with Reduce Motion. The guideline is: remove vestibular-triggering motion while preserving state communication.

| Keep | Remove/Simplify |
|------|-----------------|
| Opacity changes (fade in/out) | Large positional movement (slide, fly) |
| Instant state transitions | Zoom/scale transitions |
| Brief, small-scale changes | Bouncing, wobbling, shaking |
| User-controlled gestures | Auto-playing motion (parallax, ambient) |
| Progress indicators (non-bouncing) | Spring overshoot (bounce parameter) |

### Reduce Motion Replacement Strategies

| Original Animation | Reduced Alternative |
|--------------------|---------------------|
| Slide in from edge | Crossfade (opacity 0→1) |
| Spring with bounce | Linear ease-out, 0.15s |
| Zoom navigation transition | System handles (crossfade) |
| Parallax scroll effect | Static (no parallax) |
| Staggered item entrance | All items appear simultaneously, fade |
| Rotation/flip | Crossfade |
| Animated gradient (MeshGradient) | Static gradient |
| Pulsing indicator | Static indicator at full opacity |

## Missing Reduce Motion — Review Signals

Code patterns that likely need Reduce Motion handling:

```swift
// Any of these without @Environment(\.accessibilityReduceMotion) is a flag:
withAnimation(.spring(duration: 0.5, bounce: 0.3)) { }
.phaseAnimator(phases) { }
.keyframeAnimator(initialValue: values) { }
.matchedGeometryEffect(id: "hero", in: namespace)
.scrollTransition { content, phase in }
.offset(y: isVisible ? 0 : 50)
.scaleEffect(isActive ? 1 : 0.5)
.rotationEffect(.degrees(isFlipped ? 180 : 0))
```

Exceptions (these don't need Reduce Motion handling):
- `.contentTransition(.numericText())` — system handles it
- `.symbolEffect` — system respects Reduce Motion automatically
- `.navigationTransition(.zoom)` — system manages
- `.sensoryFeedback` — haptics, not visual motion

## VoiceOver and Animation

### State Change Announcements

If an animation communicates a state change, VoiceOver users need an equivalent announcement.

```swift
// Visual-only feedback (VoiceOver users miss this)
withAnimation(.bouncy) {
    isLiked.toggle()
}

// With announcement
withAnimation(.bouncy) {
    isLiked.toggle()
}
AccessibilityNotification.Announcement(isLiked ? "Added to favorites" : "Removed from favorites").post()
```

### Animation Blocking Interaction

Animations that block touch interaction (e.g., a loading overlay that animates in) must be announced to VoiceOver so users understand why controls became unresponsive.

### Focus Management After Transition

After animated navigation transitions, verify VoiceOver focus moves to the appropriate element in the new view.

```swift
.accessibilityFocused($isFocused)
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isFocused = true
    }
}
```

## Dynamic Type Considerations

Animations involving layout (position, size, offset) may need adjustment for larger text sizes. Fixed pixel offsets that look right at default text size may be too small or too large at accessibility sizes.

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

// Scale animation distances with type size
let slideDistance: CGFloat = dynamicTypeSize.isAccessibilitySize ? 40 : 20
```

## Prefer Cross-Dissolve for Reduce Motion

When in doubt about what to use as a Reduce Motion replacement, a simple opacity cross-dissolve at 0.15–0.2s is almost always appropriate. It communicates change without triggering vestibular response.

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| No `@Environment(\.accessibilityReduceMotion)` with spring/bounce | Motion-sensitive users see full animation |
| Reduce Motion check only at top level | Individual animated components also need checks |
| Removing all animation with Reduce Motion | Over-correction — keep fades and instant transitions |
| Animated state change with no VoiceOver announcement | VoiceOver users miss the state change |
| Fixed offset values that don't scale with Dynamic Type | Animation looks wrong at accessibility sizes |

## Review Questions

1. Does every spring/bounce/movement animation check `accessibilityReduceMotion`?
2. Is the Reduce Motion fallback appropriate (crossfade, not just removal of all animation)?
3. Are animated state changes communicated to VoiceOver via announcements?
4. Do gesture-driven animations still work correctly with VoiceOver (or provide an accessible alternative)?
5. Are fixed animation distances reasonable at larger Dynamic Type sizes?
