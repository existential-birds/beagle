# Timing & Easing Guidelines

## Duration Ranges by Purpose

| Category | Range | Default | Notes |
|----------|-------|---------|-------|
| Micro-interaction | 0.1–0.25s | 0.15s | Button press, toggle, icon swap |
| Content transition | 0.2–0.35s | 0.25s | Data change, state switch |
| Navigation transition | 0.3–0.5s | 0.4s | Push/pop, modal present |
| Hero animation | 0.35–0.55s | 0.45s | Matched geometry, zoom |
| Elaborate choreography | 0.5–0.8s | 0.6s | Onboarding reveal, celebration |
| Looping/ambient | 1.0–5.0s | 2.0s | Shimmer, pulse, gradient shift |

Animations over 0.5s should be rare and intentional. If an animation feels slow, it probably is.

## Spring Presets

### When to Use Each

| Preset | Character | Best For |
|--------|-----------|----------|
| `.smooth` | No bounce, critically damped | Most transitions, navigation, content changes |
| `.snappy` | Quick with slight bounce | Micro-interactions, toggles, quick feedback |
| `.bouncy` | Noticeable bounce | Celebratory moments, playful UI, attention-drawing |
| `.interactiveSpring` | Very fast, no bounce | Gesture tracking, drag following |

### Custom Spring Tuning

```
.spring(duration: D, bounce: B)
```

- `duration`: Time to settle. Shorter = snappier.
- `bounce`: 0.0 = no bounce (critically damped). 0.5 = very bouncy. Negative = overdamped.

| Feel | Duration | Bounce |
|------|----------|--------|
| Crisp and precise | 0.2–0.3 | 0.0–0.1 |
| Responsive with life | 0.3–0.4 | 0.15–0.25 |
| Playful and springy | 0.4–0.6 | 0.3–0.5 |
| Gentle and soft | 0.5–0.7 | 0.1–0.2 |

## Stagger Timing

When animating multiple items sequentially (list appearance, grid reveal):

| Item Count | Stagger Delay | Total Spread |
|------------|---------------|--------------|
| 3–5 items | 0.05–0.08s | 0.15–0.32s |
| 6–10 items | 0.03–0.05s | 0.15–0.45s |
| 10+ items | 0.02–0.03s | Cap at 0.5s total |

Rules:
- Cap total stagger spread at 0.5s — after that, later items feel delayed rather than choreographed
- Only stagger visible items. Items below the fold animate individually when they scroll into view.
- First item should start immediately (0s delay)

## Easing Curves

Springs are preferred for almost everything in modern iOS. Use bezier curves only when you need precise timing control (synchronized with audio, video, or external events).

| Curve | Use Case |
|-------|----------|
| `.easeOut` | Elements entering — fast start, gentle settle |
| `.easeIn` | Elements leaving — slow start, accelerate away |
| `.easeInOut` | Looping animations, symmetrical motion |
| `.linear` | Progress indicators, synchronized timing |

## Interruption Strategies

What happens when an animation is re-triggered before it completes:

| Strategy | Behavior | When to Use |
|----------|----------|-------------|
| **Retarget** | Redirect to new end value, preserving velocity | Default for springs — most interactions |
| **Replace** | Stop current, start new from current position | Discrete state changes |
| **Queue** | Wait for current to finish | Sequential choreography |
| **Ignore** | Let current animation complete | One-shot celebrations |

SwiftUI springs retarget by default — this is almost always what you want. For explicit control in `KeyframeAnimator`, use the `trigger` parameter.

## Reduce Motion Timing

When `accessibilityReduceMotion` is enabled:

| Original | Reduce Motion Alternative |
|----------|--------------------------|
| Spring with bounce | `.easeOut(duration: 0.15)` or `.none` |
| 0.3–0.5s transition | Crossfade 0.15–0.2s |
| Gesture-driven interactive | Keep interactive (user controls it), remove decorative completion |
| Looping animation | Static (no animation) |
| Staggered reveal | All items appear simultaneously with fade |

The goal is not to remove all animation — it's to remove vestibular-triggering motion (large movement, zoom, rotation, bouncing) while keeping simple opacity changes that communicate state.

## Defining App-Wide Presets

Define a small set of named timing presets and reuse them everywhere. Consistency in timing makes the app feel polished.

```
enum AnimationPreset {
    /// Micro-interactions: button press, toggle, icon swap
    static let quick: Animation = .spring(duration: 0.2, bounce: 0.15)

    /// Standard transitions: state changes, content swaps
    static let standard: Animation = .spring(duration: 0.35, bounce: 0.1)

    /// Navigation: push/pop, modal present/dismiss
    static let navigation: Animation = .spring(duration: 0.45, bounce: 0.12)

    /// Celebratory: like burst, achievement unlock
    static let playful: Animation = .spring(duration: 0.5, bounce: 0.35)

    /// Reduced alternative
    static let reduced: Animation = .easeOut(duration: 0.15)
}
```

Three to five presets is plenty. More than that and you lose consistency.
