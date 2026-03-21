# SwiftUI Animations

## withAnimation vs .animation(_:value:)

`withAnimation` wraps a state change — all views affected by that state animate. Use when the animation is tied to an event (tap, toggle, data load).

`.animation(_:value:)` attaches to a specific view and animates whenever `value` changes. Use when the animation should happen every time a binding or state property updates, regardless of what triggered it.

```swift
// BAD — deprecated form without value:
.animation(.spring())

// GOOD — explicit value binding
.animation(.spring(), value: isExpanded)

// GOOD — event-driven
Button("Toggle") {
    withAnimation(.snappy) {
        isExpanded.toggle()
    }
}
```

### Scoping withAnimation

`withAnimation` should wrap the minimal state mutation, not the entire action.

```swift
// BAD — wraps unrelated work
withAnimation {
    viewModel.loadData()     // network call doesn't need animation
    isLoading = false
    items = newItems
}

// GOOD — only animate the state change
viewModel.loadData()
withAnimation(.smooth) {
    isLoading = false
    items = newItems
}
```

## Spring Animations

Springs are the default in iOS 17+. Specify with `duration` and `bounce`.

```swift
// Named presets
withAnimation(.smooth) { }          // duration: 0.5, bounce: 0.0
withAnimation(.snappy) { }          // duration: 0.3, bounce: 0.15
withAnimation(.bouncy) { }          // duration: 0.5, bounce: 0.3

// Custom tuning
withAnimation(.spring(duration: 0.4, bounce: 0.2)) { }

// With extra bounce on a preset
withAnimation(.snappy(extraBounce: 0.1)) { }
```

## Custom Timing Curves

For precise easing control beyond the built-in presets, define a cubic Bézier curve with two control points.

```swift
// Cubic Bézier — control points (x1, y1) and (x2, y2)
withAnimation(.timingCurve(0.68, -0.55, 0.27, 1.55, duration: 0.4)) { }

// Equivalent to CSS ease-in-out
withAnimation(.timingCurve(0.42, 0, 0.58, 1, duration: 0.3)) { }
```

The built-in easing functions are shorthand for specific curves:

| Preset | Bézier Approximation |
|--------|---------------------|
| `.easeIn` | `(0.42, 0, 1, 1)` |
| `.easeOut` | `(0, 0, 0.58, 1)` |
| `.easeInOut` | `(0.42, 0, 0.58, 1)` |
| `.linear` | `(0, 0, 1, 1)` |

## Repeating Animations

Chain `.repeatCount(_:autoreverses:)` or `.repeatForever(autoreverses:)` onto any animation to loop it.

```swift
// Pulse 3 times then stop
withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
    isPulsing.toggle()
}

// Continuous rotation (no autoreverse for smooth loop)
withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
    rotationAngle = .degrees(360)
}

// Bouncy repeat with autoreverse
.animation(
    .spring(duration: 0.5, bounce: 0.3).repeatCount(2, autoreverses: true),
    value: isActive
)
```

`autoreverses: true` (default) plays the animation forward then backward per cycle. Set to `false` for one-directional loops like rotation or progress.

## Speed and Delay

Modify animation timing without changing the curve itself.

```swift
// Half-speed spring (takes twice as long)
withAnimation(.spring().speed(0.5)) {
    isExpanded.toggle()
}

// Delay start by 0.3s (useful for staggered sequences)
withAnimation(.snappy.delay(0.3)) {
    showSecondElement = true
}

// Combined — staggered cards
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    CardView(item: item)
        .animation(
            .spring(duration: 0.4).delay(Double(index) * 0.05),
            value: isVisible
        )
}
```

## Transaction Control

`Transaction` lets you override or suppress animations at the point of a state change, useful when you need different animation behavior than what the view's `.animation()` modifier provides.

```swift
// Suppress all animations for a state change
var transaction = Transaction()
transaction.disablesAnimations = true
withTransaction(transaction) {
    selectedItem = newItem  // updates instantly, no animation
}

// Override with a custom animation
var transaction = Transaction(animation: .spring(duration: 0.6, bounce: 0.2))
withTransaction(transaction) {
    isExpanded = true
}

// Inside a view modifier — read and modify the current transaction
.transaction { transaction in
    if skipAnimation {
        transaction.animation = nil
    }
}
```

Use `withTransaction` over `withAnimation` when you need to disable animations or override them for a specific state change without affecting the view's default animation modifiers.

## PhaseAnimator

Cycles through discrete phases. Each transition between phases is a separate animation. Use for multi-step sequences.

```swift
enum PulsePhase: CaseIterable {
    case idle, scale, reset
}

Circle()
    .phaseAnimator(PulsePhase.allCases) { content, phase in
        content
            .scaleEffect(phase == .scale ? 1.3 : 1.0)
            .opacity(phase == .scale ? 0.7 : 1.0)
    } animation: { phase in
        switch phase {
        case .idle: .easeOut(duration: 0.3)
        case .scale: .spring(duration: 0.4, bounce: 0.3)
        case .reset: .easeInOut(duration: 0.5)
        }
    }
```

### Triggered PhaseAnimator

Pass a `trigger` value to run the sequence once per change instead of continuously.

```swift
.phaseAnimator(PulsePhase.allCases, trigger: tapCount) { content, phase in
    // ...
}
```

## KeyframeAnimator

Per-property timeline control. Each property gets its own `KeyframeTrack` with independent timing curves and durations.

```swift
struct AnimationValues {
    var scale: Double = 1.0
    var rotation: Angle = .zero
    var yOffset: Double = 0
}

Text("🎉")
    .keyframeAnimator(initialValue: AnimationValues(), trigger: celebrate) { content, value in
        content
            .scaleEffect(value.scale)
            .rotationEffect(value.rotation)
            .offset(y: value.yOffset)
    } keyframes: { _ in
        KeyframeTrack(\.scale) {
            SpringKeyframe(1.5, duration: 0.2)
            SpringKeyframe(1.0, duration: 0.3)
        }
        KeyframeTrack(\.rotation) {
            LinearKeyframe(.degrees(-15), duration: 0.1)
            SpringKeyframe(.degrees(15), duration: 0.15)
            SpringKeyframe(.zero, duration: 0.25)
        }
        KeyframeTrack(\.yOffset) {
            SpringKeyframe(-20, duration: 0.2)
            SpringKeyframe(0, duration: 0.3)
        }
    }
```

### Keyframe Types

| Type | Interpolation | Use Case |
|------|---------------|----------|
| `LinearKeyframe` | Constant rate | Rotation, progress bars |
| `SpringKeyframe` | Spring physics | Most property animations |
| `CubicKeyframe` | Bezier curve | Precise easing control |
| `MoveKeyframe` | Instant jump | Reset to new position without interpolation |

## Content Transitions

Animate content changes within a view (not insertion/removal).

```swift
// Animated number change
Text(score, format: .number)
    .contentTransition(.numericText(countsDown: score < previousScore))

// Symbol replacement
Image(systemName: isFavorite ? "heart.fill" : "heart")
    .contentTransition(.symbolEffect(.replace))

// General interpolation
Text(statusMessage)
    .contentTransition(.interpolate)
```

## Symbol Effects

SF Symbols 5+ (iOS 17) and SF Symbols 6 (iOS 18) animations.

```swift
// Discrete (trigger once)
Image(systemName: "bell")
    .symbolEffect(.bounce, value: notificationCount)

// Continuous
Image(systemName: "network")
    .symbolEffect(.pulse)

// iOS 18
Image(systemName: "arrow.trianglehead.clockwise")
    .symbolEffect(.rotate)

Image(systemName: "bell")
    .symbolEffect(.wiggle, value: hasAlert)

Image(systemName: "circle")
    .symbolEffect(.breathe)
```

## Scroll Transitions

Animate views based on their position in a scroll view.

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemCard(item: item)
                .scrollTransition { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.3)
                        .scaleEffect(phase.isIdentity ? 1 : 0.85)
                        .blur(radius: phase.isIdentity ? 0 : 2)
                }
        }
    }
}
```

`ScrollTransitionPhase`: `.topLeading` (entering from top/leading), `.identity` (fully visible), `.bottomTrailing` (exiting to bottom/trailing).

## Mesh Gradients (iOS 18+)

Animated background gradients using a 2D control point grid.

```swift
struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5 + 0.1 * sin(phase), 0.5 + 0.1 * cos(phase)], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [.blue, .purple, .indigo, .cyan, .mint, .teal, .blue, .purple, .indigo]
        )
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
```

## Sensory Feedback

Pair haptics with animations for reinforcement.

```swift
Button("Like") {
    withAnimation(.bouncy) { isLiked.toggle() }
}
.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: isLiked)

// Other useful feedback types
.sensoryFeedback(.selection, trigger: selectedTab)      // tab switch
.sensoryFeedback(.success, trigger: taskCompleted)      // completion
.sensoryFeedback(.warning, trigger: errorOccurred)      // alert
.sensoryFeedback(.increase, trigger: count)             // increment
```

## Custom Animation Protocol (iOS 17+)

For animation behaviors not covered by built-in types.

```swift
struct DecayAnimation: CustomAnimation {
    let decayRate: Double

    func animate<V: VectorArithmetic>(value: V, time: Double, context: inout AnimationContext<V>) -> V? {
        let factor = pow(decayRate, time)
        if factor < 0.001 { return nil } // animation complete
        return value.scaled(by: factor)
    }
}

extension Animation {
    static func decay(rate: Double = 0.998) -> Animation {
        Animation(DecayAnimation(decayRate: rate))
    }
}
```
