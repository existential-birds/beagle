# Gesture-Driven Animations

## Gesture + Spring Completion Pattern

The core pattern: track gesture state, apply to view, animate to final position on release.

```swift
struct DraggableCard: View {
    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        CardView()
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                        isDragging = true
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 150
                        let velocity = value.predictedEndTranslation

                        if abs(value.translation.width) > threshold ||
                           abs(velocity.width) > 500 {
                            // Dismiss
                            withAnimation(.spring(duration: 0.3, bounce: 0.0)) {
                                offset = CGSize(
                                    width: velocity.width > 0 ? 500 : -500,
                                    height: value.translation.height
                                )
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                                offset = .zero
                            }
                        }
                        isDragging = false
                    }
                )
            .animation(.interactiveSpring, value: isDragging)
    }
}
```

## GestureState for Transient Values

`@GestureState` automatically resets when the gesture ends — useful for tracking intermediate state.

```swift
@GestureState private var dragOffset: CGSize = .zero

var body: some View {
    CardView()
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
        )
        .animation(.interactiveSpring, value: dragOffset)
}
```

Limitation: `@GestureState` resets instantly. If you need animated return-to-origin, use `@State` with explicit `onEnded` spring.

## Velocity-Preserving Completion

Capture gesture velocity and pass it to the completion spring for natural-feeling release.

```swift
.onEnded { value in
    let dx = targetOffset - offset.width
    let dy = targetOffset - offset.height
    let velocity = CGVector(
        dx: abs(dx) > 1 ? value.velocity.width / dx : 0,
        dy: abs(dy) > 1 ? value.velocity.height / dy : 0
    )

    withAnimation(.interpolatingSpring(
        stiffness: 200,
        damping: 25,
        initialVelocity: sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
    )) {
        offset = targetOffset
    }
}
```

## Rubber-Banding

When dragging past bounds, resistance increases logarithmically.

```swift
func rubberBand(_ offset: CGFloat, limit: CGFloat, coefficient: CGFloat = 0.55) -> CGFloat {
    let absOffset = abs(offset)
    guard absOffset > limit else { return offset }

    let overflow = absOffset - limit
    let dampened = limit + coefficient * overflow / (1 + coefficient * overflow / limit)
    return offset > 0 ? dampened : -dampened
}

// Usage
.offset(y: rubberBand(dragOffset.height, limit: maxDrag))
```

## Interactive Dismiss with Progress

Map gesture progress to a 0–1 dismissal progress for visual feedback.

```swift
struct InteractiveDismiss: View {
    @State private var offset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    private var progress: CGFloat {
        min(1, max(0, offset / 300))
    }

    var body: some View {
        ContentView()
            .offset(y: offset)
            .scaleEffect(1 - progress * 0.1)
            .opacity(1 - progress * 0.3)
            .background {
                Color.black.opacity(0.5 * (1 - progress))
                    .ignoresSafeArea()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if progress > 0.4 || value.velocity.height > 600 {
                            withAnimation(.spring(duration: 0.3)) {
                                offset = 1000 // large enough to animate offscreen
                            }
                            // No withAnimation completion API in SwiftUI — asyncAfter
                            // is the pragmatic approach. Keep duration in sync with spring above.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        } else {
                            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                                offset = 0
                            }
                        }
                    }
            )
    }
}
```

## Magnification (Pinch to Zoom)

```swift
struct ZoomableImage: View {
    @State private var currentScale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0

    private var effectiveScale: CGFloat {
        max(1.0, min(5.0, currentScale * gestureScale))
    }

    var body: some View {
        Image("photo")
            .resizable()
            .scaledToFit()
            .scaleEffect(effectiveScale)
            .gesture(
                MagnifyGesture()
                    .updating($gestureScale) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                            currentScale = max(1.0, min(5.0, currentScale * value.magnification))
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    currentScale = currentScale > 1.0 ? 1.0 : 2.0
                }
            }
    }
}
```

## Rotation Gesture

```swift
@State private var rotation: Angle = .zero
@GestureState private var gestureRotation: Angle = .zero

var body: some View {
    DialView()
        .rotationEffect(rotation + gestureRotation)
        .gesture(
            RotateGesture()
                .updating($gestureRotation) { value, state, _ in
                    state = value.rotation
                }
                .onEnded { value in
                    withAnimation(.spring(duration: 0.3)) {
                        // Snap to nearest 45°
                        let total = (rotation + value.rotation).degrees
                        let snapped = (total / 45).rounded() * 45
                        rotation = .degrees(snapped)
                    }
                }
        )
}
```

## Scroll-Linked Animations

### scrollTransition

Phase-based animation tied to scroll position.

```swift
.scrollTransition(.animated(.spring(duration: 0.3))) { content, phase in
    content
        .opacity(phase.isIdentity ? 1 : 0.4)
        .scaleEffect(phase.isIdentity ? 1 : 0.9)
        .rotationEffect(.degrees(phase.isIdentity ? 0 : phase.value * 5))
}
```

### Parallax Effect

Different scroll speeds for background vs foreground.

```swift
ScrollView {
    GeometryReader { geo in
        let minY = geo.frame(in: .global).minY

        Image("hero")
            .resizable()
            .scaledToFill()
            .offset(y: minY > 0 ? -minY * 0.5 : 0)  // parallax factor
            .frame(height: 300 + (minY > 0 ? minY : 0))
    }
    .frame(height: 300)

    // Regular content below
    ContentView()
}
```

## UIKit: UIViewPropertyAnimator for Interactive Animations

When you need interactive scrubbing or need to bridge with UIKit navigation.

```swift
class InteractiveDismissAnimator {
    private var animator: UIViewPropertyAnimator?

    func beginInteraction() {
        animator = UIViewPropertyAnimator(
            duration: 0.5,
            dampingRatio: 0.9
        ) {
            self.presentedView.transform = CGAffineTransform(
                translationX: 0,
                y: self.presentedView.bounds.height
            )
            self.dimmingView.alpha = 0
        }
        animator?.pauseAnimation()
    }

    func updateInteraction(progress: CGFloat) {
        animator?.fractionComplete = progress
    }

    func endInteraction(shouldComplete: Bool) {
        if shouldComplete {
            animator?.continueAnimation(
                withTimingParameters: UISpringTimingParameters(dampingRatio: 0.85),
                durationFactor: 0.5
            )
        } else {
            animator?.isReversed = true
            animator?.continueAnimation(
                withTimingParameters: UISpringTimingParameters(dampingRatio: 0.9),
                durationFactor: 0.3
            )
        }
    }
}
```
