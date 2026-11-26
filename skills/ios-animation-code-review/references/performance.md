# Animation Performance

## Frame Budget

iOS targets 60fps (16.67ms per frame) or 120fps on ProMotion devices (8.33ms). Animations that exceed the frame budget cause visible hitches — dropped frames where the UI visibly stutters.

## Offscreen Rendering Triggers

These properties force the GPU to render to an offscreen buffer before compositing, doubling the rendering cost:

| Property | When Expensive |
|----------|---------------|
| `cornerRadius` + `masksToBounds` | Always — clips content to rounded rect |
| `shadow` without explicit `shadowPath` | Every frame — system must compute shadow from layer alpha |
| `.blur()` in SwiftUI | Always — Gaussian blur is computationally expensive |
| `mask` / `.mask()` modifier | Always — requires compositing pass |
| `shouldRasterize = true` on changing layer | Cache invalidation every frame defeats the purpose |

### Shadow Path Fix

```swift
// BAD — shadow path recalculated every frame
layer.shadowOpacity = 0.3
layer.shadowRadius = 10
// No shadowPath set

// GOOD — explicit path, cached by GPU
layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: 12).cgPath
```

In SwiftUI, `.shadow()` doesn't expose path control. For animated shadows in lists, consider using a separate `RoundedRectangle` with `.shadow()` behind the content rather than applying shadow to the content itself.

## Animations in Scroll Views and Lists

Per-item animations in scrolling containers are the most common source of hitches.

```swift
// BAD — blur per cell in a list
ForEach(items) { item in
    ItemView(item: item)
        .blur(radius: 5)  // Offscreen render per cell, every frame while scrolling
}

// BAD — shadow without path per cell
ForEach(items) { item in
    ItemView(item: item)
        .shadow(radius: 10)  // Recomputed per cell
}

// GOOD — use opacity or overlay for visual depth instead
ForEach(items) { item in
    ItemView(item: item)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.shadow(.drop(radius: 5)))
        )
}
```

## View Identity and Animation Cost

Changing a view's structural identity (`.id()` modifier, conditional `if/else`) creates a new view from scratch. This is far more expensive than animating an existing view's properties.

```swift
// EXPENSIVE — destroys and recreates view
if isExpanded {
    ExpandedView().id("expanded")
} else {
    CompactView().id("compact")
}

// CHEAPER — animate properties of the same view
ContentView()
    .frame(height: isExpanded ? 400 : 100)
    .animation(.spring(), value: isExpanded)
```

When you must swap views (different content), use `transition` instead of relying on implicit animation of `id` changes.

## geometryGroup() for Layout Anomalies

When a parent's geometry changes (position, size) are animated and new child views appear during that animation, the children can render at incorrect positions. `geometryGroup()` fixes this by resolving the parent's geometry before passing it to children.

```swift
// Without geometryGroup — children may appear at wrong position during parent animation
VStack {
    if showContent {
        ContentView()  // May animate from wrong origin
    }
}
.frame(height: expanded ? 400 : 200)
.animation(.spring(), value: expanded)

// With geometryGroup — parent geometry resolved first
VStack {
    if showContent {
        ContentView()
    }
}
.frame(height: expanded ? 400 : 200)
.geometryGroup()
.animation(.spring(), value: expanded)
```

## drawingGroup() for Complex View Hierarchies

Flattens a SwiftUI view hierarchy into a single Metal-rendered layer. Reduces compositing overhead for complex but static-ish view trees.

```swift
// Complex animated overlay — flatten to single texture
ZStack {
    ForEach(particles) { particle in
        Circle()
            .fill(particle.color)
            .frame(width: particle.size)
            .offset(particle.offset)
    }
}
.drawingGroup()  // Rendered as single Metal texture
```

Use when: many overlapping views with shared animation. Don't use when: views need independent hit testing or accessibility.

## Looping Animation Cost

`PhaseAnimator` without a trigger, `.symbolEffect(.pulse)`, and `repeatForever` animations run continuously. Each consumes render cycles even when the view isn't visible (unless the view is removed from the hierarchy).

```swift
// This runs forever, even if scrolled off screen in a LazyVStack
// (LazyVStack keeps some buffer views alive)
.phaseAnimator([false, true]) { content, phase in
    content.opacity(phase ? 1 : 0.5)
}
```

For items in scroll views, prefer triggered animations (`.symbolEffect(.bounce, value: trigger)`) over continuous ones.

## Profiling Tools

| Tool | What It Shows |
|------|---------------|
| Instruments → Animation Hitches | Frame drops with call stacks |
| Instruments → Core Animation | FPS, offscreen rendering, blending |
| Debug → Color Blended Layers | Green = normal, red = blended (expensive) |
| Debug → Color Offscreen-Rendered | Yellow highlight on offscreen renders |
| Xcode GPU Report | Frame time breakdown |

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| `.blur()` in ForEach/List | Offscreen render per cell |
| Shadow without `shadowPath` | Path recalculated every frame |
| Continuous `PhaseAnimator` in scroll cells | Battery drain, hitch source |
| Animating `.id()` change | View recreation instead of property animation |
| `shouldRasterize` on frequently changing layers | Cache invalidation overhead |
| `drawingGroup()` on interactive views | Breaks hit testing and accessibility |

## Review Questions

1. Are blur, shadow, or mask applied to views inside a scroll view or list?
2. Do shadow layers have an explicit `shadowPath`?
3. Are looping animations (PhaseAnimator, repeatForever) appropriate for this context — or should they be triggered?
4. Could `geometryGroup()` fix layout anomalies where children appear at wrong positions during parent geometry animation?
5. Are expensive animations profiled with Instruments Animation Hitches template?
