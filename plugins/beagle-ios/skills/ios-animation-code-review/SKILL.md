---
name: ios-animation-code-review
description: Reviews iOS animation code for correctness, performance, accessibility, and Apple API best practices. Use when reviewing .swift files containing animation code — withAnimation, .animation(), PhaseAnimator, KeyframeAnimator, matchedGeometryEffect, navigationTransition, CABasicAnimation, CASpringAnimation, UIViewPropertyAnimator, UIDynamicAnimator, symbolEffect, scrollTransition, contentTransition, or custom Transition conformances.
---

# iOS Animation Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Spring parameters, withAnimation misuse, phase/keyframe bugs | [references/swiftui-animation-patterns.md](references/swiftui-animation-patterns.md) |
| Frame drops, offscreen rendering, main thread blocking | [references/performance.md](references/performance.md) |
| Reduce Motion, VoiceOver, motion sensitivity | [references/accessibility.md](references/accessibility.md) |
| Transition protocol, matchedGeometryEffect, navigation transitions | [references/transitions.md](references/transitions.md) |

## Output Format

Report each finding as:

```
[FILE:LINE] ISSUE_TITLE
```

Example: `[AnimatedCard.swift:42] Missing Reduce Motion fallback for spring animation`

All details, code suggestions, and rationale follow after the header line.

## Review Checklist

- [ ] `@Environment(\.accessibilityReduceMotion)` checked — animations have Reduce Motion fallback
- [ ] Animation is not the sole feedback channel — important state changes pair with haptics (`.sensoryFeedback`) or audio
- [ ] Custom animation isn't duplicating system-provided motion (standard nav transitions, sheet presentation, SF Symbol effects)
- [ ] Animations on frequent interactions are brief and unobtrusive — or absent (system handles it)
- [ ] All animations are interruptible — user is never forced to wait for completion before interacting
- [ ] Spring animations use `duration`/`bounce` parameters (not raw mass/stiffness/damping unless UIKit/CA)
- [ ] No deprecated `.animation()` without `value:` parameter
- [ ] `withAnimation` wraps state changes, not view declarations
- [ ] `matchedGeometryEffect` IDs are stable and unique within the namespace
- [ ] `geometryGroup()` used when parent geometry animates with child views appearing
- [ ] Looping animations (`PhaseAnimator`, `symbolEffect`) have finite phases or appropriate trigger
- [ ] No `CATransaction.setAnimationDuration()` in UIView-backed layers (use UIView.animate instead)
- [ ] Interactive animations handle interruption (re-trigger mid-flight doesn't break state)
- [ ] Shadow animations provide explicit `shadowPath` (avoids per-frame recalculation)
- [ ] Gesture-driven animations preserve velocity on release for natural completion
- [ ] Gesture-driven feedback follows spatial expectations (dismiss direction matches reveal direction)
- [ ] No animation of `.id()` modifier (destroys view identity — use `transition` or `matchedGeometryEffect` instead)

## When to Load References

- Incorrect spring setup or `withAnimation` scope issues → swiftui-animation-patterns.md
- Hitches, dropped frames, or expensive animations in scroll views → performance.md
- Missing Reduce Motion handling or motion accessibility → accessibility.md
- `matchedGeometryEffect` glitches or custom `Transition` bugs → transitions.md

## Review Questions

1. Does every animation have a Reduce Motion fallback that preserves the information conveyed? Is animation the only feedback channel, or are haptics/audio supplementing it?
2. Is this custom animation necessary, or does the system already provide it (standard transitions, SF Symbol effects, Liquid Glass)?
3. Could this animation cause frame drops — is it animating expensive properties (blur, shadow without path, mask) in a list or scroll view?
4. Are all animations interruptible? Can the user act without waiting for completion? Does gesture-driven feedback follow spatial expectations?
5. Is `withAnimation` scoped to the minimal state change needed, or is it wrapping unrelated mutations?
6. For `matchedGeometryEffect` — are source and destination using the same ID and namespace, and is only one visible at a time?
