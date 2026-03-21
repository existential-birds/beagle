---
name: ios-animation-implementation
description: Write Swift animation code using Apple's latest frameworks — SwiftUI animations, Core Animation, and UIKit. Prefer first-party APIs over third-party libraries. Use when implementing iOS animations, writing animation code, building transitions, creating gesture-driven interactions, or converting animation specs/designs into working Swift code. Covers iOS 18 through iOS 26 APIs including KeyframeAnimator, PhaseAnimator, custom Transition protocol, zoom navigation transitions, matchedGeometryEffect, symbol effects, mesh gradients, and SwiftUI-UIKit animation bridging.
---

# iOS Animation Implementation

Write animation code that uses Apple's frameworks directly. Third-party animation libraries add dependency risk and often lag behind new OS releases — Apple's APIs are well-optimized for the render pipeline and get free improvements with each iOS version.

## Before Writing Custom Animation

Check whether the system already handles the motion you need. Apple's HIG: "Many system components automatically include motion, letting you offer familiar and consistent experiences throughout your app." System components also automatically adjust for accessibility settings and input methods — Liquid Glass (iOS 26) responds with greater emphasis to direct touch and produces subdued effects for trackpad. Custom animation can't match this adaptiveness for free, so prefer system-provided motion when it exists.

**Skip custom animation when:**
- Standard navigation transitions cover your case (push, pop, sheet, fullScreenCover)
- SF Symbol `.symbolEffect` provides the feedback you need
- `.contentTransition(.numericText)` handles your data change
- The system's default spring on `withAnimation` is sufficient

**Write custom animation when:**
- The system doesn't provide the spatial relationship you need (hero transitions, custom gestures)
- You need coordinated multi-property choreography
- The animation is a signature moment that defines the app's identity
- Gesture-driven interaction requires custom progress mapping

## API Selection

Choose the right API for the job. Start with SwiftUI animations (simplest, most declarative), drop to UIKit when you need interactive control, and reach for Core Animation only when you need layer-level precision.

| Need | API | Why |
|------|-----|-----|
| State-driven property changes | `withAnimation` / `.animation(_:value:)` | Declarative, automatic interpolation |
| Multi-step sequenced animation | `PhaseAnimator` | Discrete phases with per-phase timing |
| Per-property timeline control | `KeyframeAnimator` | Independent keyframe tracks per property |
| Hero transitions between views | `matchedGeometryEffect` + `Namespace` | Geometry matching across view identity |
| Navigation push/pop with zoom | `.navigationTransition(.zoom)` | iOS 18+ built-in zoom transition |
| Custom view insertion/removal | `Transition` protocol conformance | `TransitionPhase`-based modifier |
| In-view content swap | `.contentTransition()` | Numeric text, interpolation, opacity |
| Scroll-position-based effects | `.scrollTransition` | Phase-driven scroll-linked animation |
| SF Symbol animation | `.symbolEffect()` | Bounce, pulse, wiggle, breathe, rotate |
| Interactive/interruptible (UIKit) | `UIViewPropertyAnimator` | Pause, resume, reverse, scrub |
| Per-layer property animation | `CABasicAnimation` / `CASpringAnimation` | Shadow, border, cornerRadius animation |
| Complex choreography (layers) | `CAKeyframeAnimation` + `CAAnimationGroup` | Multi-property layer animation |
| Physics simulation | `UIDynamicAnimator` | Gravity, collision, snap, attachment |
| Haptic feedback paired with animation | `.sensoryFeedback` modifier | Tied to value changes |
| Animated background gradients | `MeshGradient` | 2D grid of positioned, animated colors |

## Implementation by Category

Detailed patterns and code examples live in the reference files. Load the one that matches your task:

| Task | Reference |
|------|-----------|
| SwiftUI declarative animations (withAnimation, springs, phase, keyframe) | [references/swiftui-animations.md](references/swiftui-animations.md) |
| View transitions (navigation, modal, custom Transition protocol) | [references/transitions.md](references/transitions.md) |
| Gesture-driven interactive animations | [references/gesture-animations.md](references/gesture-animations.md) |
| Core Animation and UIKit animation patterns | [references/core-animation.md](references/core-animation.md) |

## When to Load References

- Writing `withAnimation`, spring parameters, `PhaseAnimator`, or `KeyframeAnimator` → swiftui-animations.md
- Building navigation transitions, modal presentations, `matchedGeometryEffect`, or custom `Transition` → transitions.md
- Implementing drag-to-dismiss, swipe actions, pinch/rotate, or scroll-linked effects → gesture-animations.md
- Working with `CABasicAnimation`, `UIViewPropertyAnimator`, layer animations, or bridging SwiftUI↔UIKit → core-animation.md

## Spring Parameters Quick Reference

Springs are the default animation type in modern SwiftUI. Use `duration` and `bounce` — not mass/stiffness/damping unless bridging to UIKit/CA.

| Preset | Duration | Bounce | Use Case |
|--------|----------|--------|----------|
| `.smooth` | 0.5 | 0.0 | Default transitions, most state changes |
| `.snappy` | 0.3 | 0.15 | Micro-interactions, toggles, quick feedback |
| `.bouncy` | 0.5 | 0.3 | Playful moments, attention-drawing |
| `.interactiveSpring` | 0.15 | 0.0 | Gesture tracking, drag following |
| Custom | varies | varies | `.spring(duration: 0.4, bounce: 0.2)` |

## Accessibility & Multimodal Feedback

Apple's HIG: "Make motion optional" and "supplement visual feedback by also using alternatives like haptics and audio to communicate." Every animation must handle Reduce Motion, and important state changes should use multiple feedback channels — not animation alone.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Pattern 1: Conditional animation
withAnimation(reduceMotion ? .none : .spring()) {
    isExpanded.toggle()
}

// Pattern 2: Simplified alternative
.animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.5, bounce: 0.3), value: isActive)

// Pattern 3: Skip entirely
if !reduceMotion {
    view.phaseAnimator(phases) { /* ... */ }
}
```

Reduce Motion fallback options (from most to least graceful):
1. **Crossfade** — replace motion with opacity transition
2. **Shortened** — same animation, much faster (0.1–0.15s), no bounce
3. **Instant** — `.animation(.none)` or skip the animation block entirely

## Cancellation & Interruptibility

Apple's HIG: "Don't make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once." Every animation must be interruptible.

- Spring animations retarget automatically — this is the default and almost always what you want
- For gesture-driven animations, the user is always in control — let them cancel mid-flight
- For sequenced animations (KeyframeAnimator, PhaseAnimator with trigger), ensure the UI remains interactive during playback
- Never disable user interaction during an animation unless there's a critical reason (e.g., destructive action confirmation)

## Performance Checklist

- Animate on the render server when possible — Core Animation runs off the main thread, SwiftUI's `drawingGroup()` moves rendering to Metal
- Avoid animating view identity changes (`.id()` modifier) — this destroys and recreates the view
- Use `geometryGroup()` when parent geometry changes cause child layout anomalies during animation
- Provide explicit `shadowPath` when animating shadows — without it, the system recalculates the path every frame
- In lists and scroll views, avoid per-item blur/shadow animations — these cause offscreen rendering for each cell
- Keep `PhaseAnimator` and looping animations lightweight — they run continuously
- For frequent interactions, prefer system-provided animation over custom motion — Apple's HIG: "generally avoid adding motion to UI interactions that occur frequently"
- Profile with Instruments → "Animation Hitches" template to find frame drops
