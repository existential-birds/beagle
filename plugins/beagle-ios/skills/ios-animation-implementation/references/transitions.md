# Transitions

## Custom Transition Protocol (iOS 17+)

Define reusable view insertion/removal animations.

```swift
struct SlideAndFade: Transition {
    var edge: Edge

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(
                x: phase == .willAppear ? (edge == .leading ? -50 : 50) :
                   phase == .didDisappear ? (edge == .leading ? -50 : 50) : 0
            )
    }
}

extension AnyTransition {
    static func slideAndFade(from edge: Edge) -> AnyTransition {
        .init(SlideAndFade(edge: edge))
    }
}

// Usage
if showDetail {
    DetailView()
        .transition(.slideAndFade(from: .trailing))
}
```

### TransitionPhase

| Phase | Meaning | Typical Use |
|-------|---------|-------------|
| `.willAppear` | View is about to insert | Set "before" state (offscreen, transparent) |
| `.identity` | View is fully presented | Normal appearance |
| `.didDisappear` | View is about to remove | Set "after" state (offscreen, transparent) |

### Asymmetric Transitions

Different animations for insertion vs removal.

```swift
.transition(.asymmetric(
    insertion: .move(edge: .bottom).combined(with: .opacity),
    removal: .scale(scale: 0.8).combined(with: .opacity)
))
```

## matchedGeometryEffect

Hero transitions between views using shared geometry.

```swift
struct ContentView: View {
    @Namespace private var animation
    @State private var isExpanded = false

    var body: some View {
        if isExpanded {
            ExpandedCard(namespace: animation)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                        isExpanded = false
                    }
                }
        } else {
            CompactCard(namespace: animation)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                        isExpanded = true
                    }
                }
        }
    }
}

struct CompactCard: View {
    var namespace: Namespace.ID

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.blue)
            .matchedGeometryEffect(id: "card", in: namespace)
            .frame(width: 100, height: 100)
    }
}

struct ExpandedCard: View {
    var namespace: Namespace.ID

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.blue)
            .matchedGeometryEffect(id: "card", in: namespace)
            .frame(maxWidth: .infinity, maxHeight: 400)
    }
}
```

### Common Pitfalls

1. **Both views visible simultaneously** — only one view with a given matched ID should be in the hierarchy at a time. Use `if/else`, not opacity toggling.

2. **Unstable IDs** — the `id` parameter must be the same value on both sides. Use a model ID, not an index.

3. **Missing `isSource`** — when matching multiple properties (position and size separately), set `isSource: true` on the view that defines the geometry, `isSource: false` on the one that follows.

4. **Missing `geometryGroup()`** — when the parent's geometry is also changing (e.g., the parent frame animates), wrap the parent with `.geometryGroup()` to isolate layout resolution.

## Zoom Navigation Transition (iOS 18+)

Built-in zoom-style push/pop for NavigationStack.

```swift
struct GridView: View {
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns) {
                ForEach(items) { item in
                    NavigationLink {
                        DetailView(item: item)
                            .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                    } label: {
                        ItemCell(item: item)
                            .matchedTransitionSource(id: item.id, in: namespace)
                    }
                }
            }
        }
    }
}
```

Works with:
- `NavigationStack` push/pop
- `.fullScreenCover`
- `.sheet`

Automatically handles back-gesture interruption and is continuously interactive.

## Full-Screen Cover Transitions

`.fullScreenCover` uses system-managed presentation animation. The `.transition()` modifier does **not** affect modal presentation — it only applies to views conditionally inserted/removed within the same hierarchy.

To customize full-screen cover appearance, animate content **inside** the cover view (e.g., in `.onAppear`), or use `navigationTransition(.zoom)` on iOS 18+.

For zoom-style cover transitions on iOS 18+:

```swift
.fullScreenCover(isPresented: $showPhoto) {
    PhotoViewer(photo: selectedPhoto)
        .navigationTransition(.zoom(sourceID: selectedPhoto.id, in: namespace))
}
```

## Sheet Presentation Transitions

Sheets have system-managed presentation animation. To customize the content appearance within the sheet:

```swift
.sheet(isPresented: $showSettings) {
    SettingsView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

Sheet content that changes state can animate internally with standard `withAnimation`.

## Tab View Transitions

Animate tab switches with content transitions.

```swift
TabView(selection: $selectedTab) {
    // tabs
}
// Custom transition between tab content
.onChange(of: selectedTab) {
    withAnimation(.snappy) {
        // trigger any state changes for the new tab
    }
}
```

For custom tab-like views, use `matchedGeometryEffect` on the tab indicator:

```swift
HStack {
    ForEach(tabs) { tab in
        Button(tab.title) { selectedTab = tab }
            .background {
                if selectedTab == tab {
                    Capsule()
                        .fill(.blue)
                        .matchedGeometryEffect(id: "indicator", in: namespace)
                }
            }
    }
}
```

## NavigationStack Path Animation

Animate programmatic navigation changes.

```swift
@State private var path = NavigationPath()

NavigationStack(path: $path) { /* ... */ }

// Animated push
withAnimation(.smooth) {
    path.append(destination)
}

// Animated pop to root
withAnimation(.smooth) {
    path.removeLast(path.count)
}
```
