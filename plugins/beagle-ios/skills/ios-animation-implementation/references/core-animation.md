# Core Animation & UIKit

## When to Use Core Animation

Drop to Core Animation when you need:
- Layer property animation (shadow, border, cornerRadius) that SwiftUI doesn't directly expose
- Precise timing control synchronized with external events
- Animation on non-UIView layers (CAShapeLayer, CAGradientLayer, CAEmitterLayer)
- Complex layer hierarchies with independent animation timelines

## CABasicAnimation

Single-value interpolation from `fromValue` to `toValue`.

```swift
let animation = CABasicAnimation(keyPath: "shadowOpacity")
animation.fromValue = 0
animation.toValue = 0.5
animation.duration = 0.3
animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
animation.fillMode = .forwards
animation.isRemovedOnCompletion = false
layer.add(animation, forKey: "shadowFadeIn")

// Set the model value to match the animation end state
layer.shadowOpacity = 0.5
```

Always set the model value to the final state. Without this, the layer snaps back when the animation completes and is removed.

## CASpringAnimation

Spring physics at the layer level. Subclass of `CABasicAnimation`.

```swift
let spring = CASpringAnimation(keyPath: "transform.scale")
spring.fromValue = 0.8
spring.toValue = 1.0
spring.mass = 1.0
spring.stiffness = 200
spring.damping = 15
spring.initialVelocity = 5
spring.duration = spring.settlingDuration  // let the spring calculate its own duration
layer.add(spring, forKey: "scaleSpring")
layer.transform = CATransform3DIdentity
```

Use `settlingDuration` as the `duration` — it calculates how long the spring needs based on its parameters.

## CAKeyframeAnimation

Multi-value animation with per-segment timing control.

```swift
let keyframe = CAKeyframeAnimation(keyPath: "position")
keyframe.values = [
    CGPoint(x: 100, y: 100),
    CGPoint(x: 200, y: 50),
    CGPoint(x: 300, y: 100)
]
keyframe.keyTimes = [0, 0.4, 1.0]  // timing as fraction of duration
keyframe.timingFunctions = [
    CAMediaTimingFunction(name: .easeOut),
    CAMediaTimingFunction(name: .easeIn)
]
keyframe.duration = 0.6
layer.add(keyframe, forKey: "pathAnimation")
layer.position = CGPoint(x: 300, y: 100)
```

### Path-Based Animation

Animate along a bezier path.

```swift
let pathAnimation = CAKeyframeAnimation(keyPath: "position")
let path = UIBezierPath()
path.move(to: startPoint)
path.addCurve(to: endPoint, controlPoint1: cp1, controlPoint2: cp2)
pathAnimation.path = path.cgPath
pathAnimation.duration = 0.5
pathAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
pathAnimation.rotationMode = .rotateAuto  // orient along path
layer.add(pathAnimation, forKey: "curvedPath")
```

## CAAnimationGroup

Combine multiple animations with shared timing.

```swift
let group = CAAnimationGroup()

let scale = CABasicAnimation(keyPath: "transform.scale")
scale.fromValue = 1.0
scale.toValue = 1.2

let opacity = CABasicAnimation(keyPath: "opacity")
opacity.fromValue = 1.0
opacity.toValue = 0.0

group.animations = [scale, opacity]
group.duration = 0.3
group.fillMode = .forwards
group.isRemovedOnCompletion = false
layer.add(group, forKey: "scaleAndFade")
```

## CATransaction

Control implicit animation parameters or group explicit changes.

```swift
// Disable implicit animations
CATransaction.begin()
CATransaction.setDisableActions(true)
layer.position = newPosition
CATransaction.commit()

// Custom duration for implicit animations
CATransaction.begin()
CATransaction.setAnimationDuration(0.5)
CATransaction.setCompletionBlock {
    print("Animation complete")
}
layer.opacity = 0
CATransaction.commit()
```

## CAShapeLayer Animation

Animate `strokeEnd` for drawing effects, `path` for morphing.

```swift
// Draw-on animation
let shapeLayer = CAShapeLayer()
shapeLayer.path = circlePath.cgPath
shapeLayer.strokeEnd = 0
shapeLayer.lineWidth = 3
shapeLayer.strokeColor = UIColor.blue.cgColor
shapeLayer.fillColor = nil
view.layer.addSublayer(shapeLayer)

let draw = CABasicAnimation(keyPath: "strokeEnd")
draw.fromValue = 0
draw.toValue = 1
draw.duration = 1.0
draw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
shapeLayer.strokeEnd = 1
shapeLayer.add(draw, forKey: "drawCircle")
```

## UIView.animate

Block-based UIView animation. Simple and sufficient for most UIKit needs.

```swift
UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
    view.alpha = 0
    view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
} completion: { _ in
    view.removeFromSuperview()
}

// Spring
UIView.animate(
    withDuration: 0.5,
    delay: 0,
    usingSpringWithDamping: 0.7,
    initialSpringVelocity: 0.5,
    options: []
) {
    view.center = targetPoint
}
```

## iOS 18: SwiftUI Animation in UIKit

Use SwiftUI `Animation` types directly in UIKit.

```swift
// Direct usage
UIView.animate(.spring(duration: 0.5, bounce: 0.2)) {
    view.center = newCenter
}

// In UIViewRepresentable — bridging SwiftUI transaction animations
struct BridgedView: UIViewRepresentable {
    var offset: CGFloat

    func updateUIView(_ uiView: UIView, context: Context) {
        context.animate {
            uiView.transform = CGAffineTransform(translationX: offset, y: 0)
        }
    }
}
```

The `context.animate` call automatically uses whatever animation is active in the SwiftUI transaction — if the parent used `withAnimation(.spring())`, the UIView change inherits that spring.

## UIViewPropertyAnimator

Full lifecycle control: create, start, pause, resume, reverse, scrub.

```swift
let animator = UIViewPropertyAnimator(
    duration: 0.4,
    timingParameters: UISpringTimingParameters(dampingRatio: 0.8)
)

animator.addAnimations {
    view.transform = CGAffineTransform(translationX: 0, y: -200)
    view.alpha = 0
}

animator.addCompletion { position in
    if position == .end {
        view.removeFromSuperview()
    }
}

// Interactive scrubbing
animator.pauseAnimation()
animator.fractionComplete = gestureProgress  // 0.0 to 1.0

// Resume with spring
animator.continueAnimation(
    withTimingParameters: UISpringTimingParameters(dampingRatio: 0.85),
    durationFactor: 0.5  // fraction of remaining duration
)
```

## UIDynamicAnimator

Physics-based animations using behavior composition.

```swift
let animator = UIDynamicAnimator(referenceView: containerView)

// Snap behavior — spring to a point
let snap = UISnapBehavior(item: cardView, snapTo: targetPoint)
snap.damping = 0.5
animator.addBehavior(snap)

// Gravity + collision for falling effect
let gravity = UIGravityBehavior(items: [cardView])
let collision = UICollisionBehavior(items: [cardView])
collision.translatesReferenceBoundsIntoBoundary = true
animator.addBehavior(gravity)
animator.addBehavior(collision)

// Item properties
let behavior = UIDynamicItemBehavior(items: [cardView])
behavior.elasticity = 0.6
behavior.friction = 0.2
animator.addBehavior(behavior)
```

Use sparingly — physics simulations are powerful but can produce unpredictable results if behaviors conflict. For most cases, spring animations achieve a similar feel with more control.

## Performance Notes

- Core Animation runs on the render server (separate process), not the main thread
- Avoid animating properties that trigger offscreen rendering: `cornerRadius` + `masksToBounds`, complex `shadowPath`, `shouldRasterize` on frequently changing layers
- Provide explicit `shadowPath` — without it, the system must calculate the shadow from the layer's composited alpha every frame
- `shouldRasterize = true` caches the layer's rendered content — good for static complex layers, bad for layers that change frequently (the cache gets invalidated)
- Group related layer changes in `CATransaction` to batch commits
