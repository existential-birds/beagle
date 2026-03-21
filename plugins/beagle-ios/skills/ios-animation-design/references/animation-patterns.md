# Animation Pattern Library

## Navigation Patterns

### Hero Element Transition
Element from source screen flies to its position in destination screen. Creates spatial continuity between list and detail views.

**When to use**: Tapping a card/cell to open detail. Photo grids. Product listings.
**API**: `matchedGeometryEffect` (iOS 14+), `.navigationTransition(.zoom)` (iOS 18+)
**Timing**: 0.35–0.5s spring (duration: 0.45, bounce: 0.15)
**Reduce Motion**: Crossfade (0.2s)

### Shared Axis Transition
Views slide along a shared spatial axis — horizontal for peer navigation, vertical for parent-child hierarchy.

**When to use**: Tab switches, onboarding steps, wizard flows.
**API**: Custom `Transition` with `offset` + `opacity`
**Timing**: 0.3s `.snappy`
**Reduce Motion**: Crossfade

### Full-Screen Cover with Zoom
Source element zooms to fill the screen. Built-in to iOS 18+ navigation.

**When to use**: Image viewers, media playback, detail views from grids.
**API**: `.navigationTransition(.zoom(sourceID:in:))` + `.matchedTransitionSource`
**Timing**: System-managed spring
**Reduce Motion**: System handles automatically

## Micro-Interaction Patterns

### Press Scale
Button scales down slightly on press, returns with bounce on release. Pairs with haptic.

**Spec**:
- Press: scale 0.95, opacity 0.8, duration 0.1s
- Release: scale 1.0, opacity 1.0, spring(duration: 0.3, bounce: 0.4)
- Haptic: `.sensoryFeedback(.impact(flexibility: .soft))`

### Toggle State
Binary state switch with smooth property interpolation.

**Spec**:
- Properties: background color, icon rotation/swap, track position
- Duration: 0.2s `.snappy`
- Content swap: `.contentTransition(.symbolEffect(.replace))`

### Like/Favorite Burst
Celebratory response to a positive action. Should feel rewarding without being slow.

**Spec**:
- Icon: scale 1.0 → 1.3 → 1.0, with `.symbolEffect(.bounce)`
- Optional: particle burst using overlay + `PhaseAnimator`
- Haptic: `.sensoryFeedback(.success)`
- Duration: 0.4s total

### Pull to Refresh
Overscroll triggers refresh indicator. Progress maps to pull distance.

**Spec**:
- Threshold: 80pt pull
- Indicator: rotation tied to scroll offset, then continuous spin on release
- Completion: scale down + fade (0.2s)

## Content Transition Patterns

### Number Counter
Animated number changes — scores, prices, quantities.

**API**: `.contentTransition(.numericText(countsDown:))`
**Timing**: System-managed
**Reduce Motion**: Instant update (system handles)

### Skeleton to Content
Placeholder shimmer replaced by actual content on load.

**Spec**:
- Skeleton: gradient mask sweep using `PhaseAnimator` with 2 phases (offset -1.0, +1.0)
- Reveal: opacity 0→1, offset.y 8→0, spring 0.35s
- Stagger: 0.05s between items

### List Reorder
Items slide to new positions when sort changes.

**API**: `withAnimation(.spring()) { items.sort(...) }` with `ForEach` + stable IDs
**Timing**: 0.35s `.smooth`
**Reduce Motion**: Instant reorder

### State Switch (Empty/Error/Loaded)
Full-view content swap between states.

**Spec**:
- Outgoing: opacity 1→0, scale 1.0→0.95 (0.15s)
- Incoming: opacity 0→1, scale 1.05→1.0, offset.y 10→0 (spring 0.35s)
- Custom `Transition` recommended for reuse

## Gesture-Driven Patterns

### Card Swipe Dismiss
Drag card horizontally past threshold to dismiss, or snap back.

**Spec**:
- Track: offset follows finger with 1:1 mapping
- Rotation: slight tilt proportional to horizontal offset (±5°)
- Threshold: 150pt or velocity > 500pt/s
- Commit: fly off-screen in drag direction, spring completion
- Cancel: spring back to origin (duration: 0.5, bounce: 0.2)
- Opacity: fade as distance increases (1.0 at center, 0.5 at threshold)

### Bottom Sheet Drag
Pull sheet between detents with rubber-banding at limits.

**Spec**:
- Detents: collapsed (100pt), half (50%), full (90%)
- Between detents: 1:1 finger tracking
- Past limits: rubber-band (0.3:1 ratio)
- Release: snap to nearest detent using spring(duration: 0.4, bounce: 0.15)
- Velocity: release velocity determines target detent

### Pinch to Zoom
Scale content interactively with gesture, settle to discrete zoom levels on release.

**Spec**:
- Track: scale follows `MagnificationGesture` value
- Min/max: 1.0x–5.0x, rubber-band beyond
- Release: spring to nearest integer zoom (or back to 1.0 if below threshold)
- Double-tap: toggle between 1.0x and 2.0x (spring 0.35s)

## Ambient & Loading Patterns

### Mesh Gradient Background
Slowly shifting color field for visual atmosphere.

**API**: `MeshGradient` (iOS 18+) with timer-driven point interpolation
**Spec**:
- Grid: 3×3 minimum
- Animation: shift 2–3 control points by small random offsets
- Cycle: 3–5s per shift, continuous
- Reduce Motion: static gradient (no animation)

### Pulsing Activity Indicator
Subtle pulse for ongoing background activity.

**API**: `.symbolEffect(.pulse)` on SF Symbol or `PhaseAnimator` for custom
**Spec**:
- Opacity: 0.4 ↔ 1.0
- Scale: 0.95 ↔ 1.0
- Cycle: 1.5s per pulse
- Reduce Motion: static icon at full opacity

### Shimmer Loading
Gradient sweep across placeholder shapes.

**Spec**:
- Gradient: 3-stop (background → highlight → background)
- Sweep: linear move from leading to trailing, 1.2s cycle
- Angle: 15° for visual interest
- Reduce Motion: static gray placeholders (no sweep)
