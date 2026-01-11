# SwiftUI Code Review Reference

A comprehensive guide for reviewing SwiftUI code, focusing on common anti-patterns, best practices, and critical issues.

---

## Critical Anti-Patterns

### 1. AnyView Type Erasure

AnyView erases type information, preventing SwiftUI's structural identity diffing and causing full view redraws.

```swift
// BAD: Type erasure breaks diffing
func makeView(for type: ContentType) -> some View {
    AnyView(
        switch type {
        case .text: Text("Hello")
        case .image: Image("photo")
        }
    )
}

// GOOD: Use @ViewBuilder to preserve types
@ViewBuilder
func makeView(for type: ContentType) -> some View {
    switch type {
    case .text: Text("Hello")
    case .image: Image("photo")
    }
}

// GOOD: Use Group for conditional views
func makeView(for type: ContentType) -> some View {
    Group {
        switch type {
        case .text: Text("Hello")
        case .image: Image("photo")
        }
    }
}
```

**Why it matters:** SwiftUI uses structural identity to efficiently diff views. AnyView forces complete redraws because the framework cannot determine what changed.

### 2. Wrong Modifier Ordering

Modifier order dramatically affects layout because each modifier wraps the view in a new view.

```swift
// BAD: Background only covers text, not padding
Text("Hello")
    .background(Color.blue)
    .padding()

// GOOD: Background covers padded area
Text("Hello")
    .padding()
    .background(Color.blue)

// BAD: Frame applied before background
Text("Hello")
    .background(Color.red)
    .frame(width: 200, height: 200)
// Result: 200x200 empty square with small red area around text

// GOOD: Background fills the frame
Text("Hello")
    .frame(width: 200, height: 200)
    .background(Color.red)
```

**Why it matters:** Each modifier creates a new wrapper view. The order determines what gets styled/sized.

### 3. VStack in ScrollView with Many Items

VStack renders all children immediately, even those offscreen.

```swift
// BAD: All 1000 rows created at once
ScrollView {
    VStack {
        ForEach(0..<1000, id: \.self) { i in
            ExpensiveRow(index: i)
        }
    }
}

// GOOD: Only visible rows created
ScrollView {
    LazyVStack {
        ForEach(0..<1000, id: \.self) { i in
            ExpensiveRow(index: i)
        }
    }
}
```

**When NOT to use Lazy:** For small, fixed lists where all items fit on screen. Lazy stacks have bookkeeping overhead that isn't worth it for small lists.

### 4. Wrong Property Wrapper for Observable Objects

```swift
// BAD: @ObservedObject for view-owned data (can be recreated)
struct ContentView: View {
    @ObservedObject var model = DataModel()  // Wrong!
    var body: some View { ... }
}

// GOOD: @StateObject for view-owned data (created once)
struct ContentView: View {
    @StateObject var model = DataModel()  // Correct!
    var body: some View { ... }
}

// GOOD: @ObservedObject for passed-in data
struct ChildView: View {
    @ObservedObject var model: DataModel  // Injected from parent
    var body: some View { ... }
}
```

**Rule:** `@StateObject` = view owns and creates the object. `@ObservedObject` = object passed from elsewhere.

### 5. Conditional Views Breaking Structural Identity

```swift
// BAD: Creates two different views with different identities
var body: some View {
    if showDetails {
        DetailView()
            .foregroundColor(.blue)
    } else {
        DetailView()
            .foregroundColor(.gray)
    }
}

// GOOD: Same view, different modifiers (preserves identity)
var body: some View {
    DetailView()
        .foregroundColor(showDetails ? .blue : .gray)
}
```

**Why it matters:** Branches (`if/else`) create different structural identities, triggering animations and state loss.

### 6. Heavy Work in View Body

```swift
// BAD: Expensive computation on every redraw
var body: some View {
    let filtered = items.filter { $0.isActive }
        .sorted { $0.date > $1.date }
    List(filtered) { item in
        ItemRow(item: item)
    }
}

// GOOD: Cache expensive operations
@State private var filteredItems: [Item] = []

var body: some View {
    List(filteredItems) { item in
        ItemRow(item: item)
    }
    .task { filteredItems = await computeFiltered() }
    .onChange(of: items) { filteredItems = computeFiltered() }
}

// BAD: Database/network calls in computed properties
var hasAttachment: Bool {
    loadAttachment() != nil  // Called on every body evaluation!
}

// GOOD: Check only what's necessary
var hasAttachment: Bool {
    attachmentURL != nil  // Fast check
}
```

### 7. Missing Identifiers in Dynamic Lists

```swift
// BAD: Dynamic range without stable identifier
@State private var rowCount = 5

var body: some View {
    List(0..<rowCount) { row in  // Warning: range must be constant
        Text("Row \(row)")
    }
}

// GOOD: Explicit identifier
List(0..<rowCount, id: \.self) { row in
    Text("Row \(row)")
}

// BEST: Use Identifiable data
List(items) { item in  // item.id used automatically
    ItemRow(item: item)
}
```

### 8. Stroke vs StrokeBorder

```swift
// BAD: stroke() centers on edge, may clip
Circle()
    .stroke(Color.blue, lineWidth: 20)

// GOOD: strokeBorder() stays inside bounds
Circle()
    .strokeBorder(Color.blue, lineWidth: 20)
```

---

## State Management Rules

### iOS 17+ (Observation Framework)

Three primary property wrappers:

| Wrapper | Use Case |
|---------|----------|
| `@State` | View-owned data (value OR reference types with @Observable) |
| `@Bindable` | Create bindings to @Observable object properties |
| `@Environment` | Shared data from the environment |

```swift
// @State for view-owned Observable object
@Observable class ViewModel { var count = 0 }

struct ContentView: View {
    @State private var viewModel = ViewModel()  // iOS 17+
    var body: some View {
        Button("\(viewModel.count)") { viewModel.count += 1 }
    }
}

// @Bindable for bindings to Observable properties
struct EditView: View {
    @Environment(User.self) private var user

    var body: some View {
        @Bindable var user = user  // Create bindable reference
        TextField("Name", text: $user.name)
    }
}
```

### Pre-iOS 17 (ObservableObject)

| Wrapper | Use Case |
|---------|----------|
| `@State` | View-owned value types |
| `@StateObject` | View-owned ObservableObject |
| `@ObservedObject` | Injected ObservableObject |
| `@EnvironmentObject` | Shared ObservableObject |
| `@Binding` | Two-way binding to parent state |

### State Ownership Decision Tree

1. **Does the view create and own this data?**
   - Value type -> `@State`
   - Reference type (iOS 17+) -> `@State` with `@Observable`
   - Reference type (pre-iOS 17) -> `@StateObject`

2. **Is this data passed from a parent?**
   - Need to modify -> `@Binding`
   - Just read -> regular property

3. **Is this data shared across the app?**
   - iOS 17+ -> `@Environment` with `@Observable`
   - Pre-iOS 17 -> `@EnvironmentObject`

---

## Performance Optimization

### Use Equatable Views

```swift
// Implement Equatable to control view updates
struct ExpensiveView: View, Equatable {
    let data: ExpensiveData

    var body: some View {
        // Complex view hierarchy
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data.id == rhs.data.id  // Custom equality check
    }
}

// Use .equatable() modifier
ParentView()
    .equatable()  // Uses Equatable conformance for diffing
```

**When to use:** When body computation is more expensive than your equality check.

### Minimize Redraws

```swift
// BAD: Every image download triggers all views to redraw
class ImageLoader: ObservableObject {
    @Published var images = [String: UIImage]()
}

// GOOD: Batch updates
class ImageLoader: ObservableObject {
    private var images = [String: UIImage]()
    private var pendingUpdate = false

    func imageLoaded(_ image: UIImage, for key: String) {
        images[key] = image
        if !pendingUpdate {
            pendingUpdate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.objectWillChange.send()
                self.pendingUpdate = false
            }
        }
    }
}
```

### Debug Redraws

```swift
var body: some View {
    let _ = Self._printChanges()  // Prints what triggered redraw
    // ... view content
}
```

### Lazy Container Guidelines

| Container | Use When |
|-----------|----------|
| `VStack`/`HStack` | Small, fixed number of items |
| `LazyVStack`/`LazyHStack` | Scrollable content with many items |
| `List` | Very large datasets (provides cell recycling) |
| `LazyVGrid`/`LazyHGrid` | Grid layouts with many items |

**iOS 18+ Improvement:** LazyVStack now unloads off-screen views, improving memory usage.

---

## View Composition Best Practices

### When to Extract Subviews

1. **Over 50-100 lines** in body -> Extract
2. **Reused in multiple places** -> Extract to separate struct
3. **Has own state** -> Extract to separate struct
4. **Improves readability** -> Extract (even small views)

### Extraction Methods

```swift
// Method 1: Private @ViewBuilder function (local reuse)
struct ContentView: View {
    @ViewBuilder
    private func headerSection() -> some View {
        VStack {
            Text("Header")
            Divider()
        }
    }

    var body: some View {
        VStack {
            headerSection()
            // ...
        }
    }
}

// Method 2: Separate struct (cross-file reuse, has own state)
struct HeaderSection: View {
    let title: String

    var body: some View {
        VStack {
            Text(title)
            Divider()
        }
    }
}

// Method 3: ViewBuilder computed property (simple extraction)
struct ContentView: View {
    @ViewBuilder
    private var headerSection: some View {
        VStack {
            Text("Header")
            Divider()
        }
    }
}
```

### Modifier Grouping

```swift
// Extract common modifier combinations
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 4)
    }
}

// Usage
Text("Card Content")
    .cardStyle()
```

---

## Accessibility Requirements

### Essential Modifiers

```swift
// Labels for non-text elements
Image(systemName: "star.fill")
    .accessibilityLabel("Favorite")

// Hints for actions
Button(action: sendMessage) {
    Image(systemName: "paperplane")
}
.accessibilityLabel("Send")
.accessibilityHint("Double-tap to send the message")

// Traits for custom interactive elements
Image("product")
    .onTapGesture { selectProduct() }
    .accessibilityLabel("Product photo")
    .accessibilityAddTraits(.isButton)
```

### Grouping Elements

```swift
// BAD: VoiceOver reads each element separately
HStack {
    Image(systemName: "star.fill")
    Text("5.0")
    Text("(128 reviews)")
}

// GOOD: Group as single element
HStack {
    Image(systemName: "star.fill")
    Text("5.0")
    Text("(128 reviews)")
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Rating: 5 stars, 128 reviews")
```

### Dynamic Type Support

```swift
// System fonts automatically scale
Text("Hello")
    .font(.body)  // Scales with Dynamic Type

// Custom fonts must opt-in
Text("Hello")
    .font(.custom("MyFont", size: 17, relativeTo: .body))

// Scale non-text values with @ScaledMetric
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24

var body: some View {
    Image(systemName: "star")
        .frame(width: iconSize, height: iconSize)
}

// Adapt layout for accessibility sizes
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    if dynamicTypeSize.isAccessibilitySize {
        VStack { content }  // Stack vertically for large text
    } else {
        HStack { content }  // Horizontal for normal sizes
    }
}
```

### Hiding Decorative Elements

```swift
// Hide purely decorative elements
Image("decorative-divider")
    .accessibilityHidden(true)
```

---

## Navigation (iOS 16+)

```swift
// BAD: Deprecated NavigationView
NavigationView {
    List { ... }
}

// GOOD: NavigationStack for drill-down
NavigationStack {
    List { ... }
}

// GOOD: NavigationSplitView for master-detail
NavigationSplitView {
    Sidebar()
} detail: {
    DetailView()
}
```

---

## Code Review Questions

### 1. State Management
- Is the correct property wrapper used? (`@State` vs `@StateObject` vs `@ObservedObject`)
- Is state declared as `private` when owned by the view?
- Are there multiple sources of truth for the same data?

### 2. Performance
- Are lazy containers used for large scrollable lists?
- Is expensive computation cached rather than in body/computed properties?
- Is AnyView used unnecessarily (should use @ViewBuilder or generics)?
- Could Equatable conformance reduce unnecessary redraws?

### 3. View Composition
- Is the body under 50-100 lines?
- Are reusable components extracted into separate structs?
- Is modifier order correct (padding before background, frame before background)?

### 4. Accessibility
- Do all actionable elements have accessibility labels?
- Are custom tap gestures marked with `.accessibilityAddTraits(.isButton)`?
- Does the UI work with Dynamic Type accessibility sizes?
- Are decorative images hidden from VoiceOver?

### 5. Identity & Lifecycle
- Are dynamic lists using stable identifiers (Identifiable or explicit `id:`)?
- Are conditional branches necessary or can inline modifiers preserve identity?
- Is `.id()` used intentionally and not causing unexpected state loss?

---

## Sources

### Apple Documentation & WWDC
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [WWDC24: Catch up on accessibility in SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10073/)
- [WWDC24: SwiftUI essentials](https://developer.apple.com/videos/play/wwdc2024/10150/)
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [WWDC21: Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/)

### Community Resources
- [SwiftUI Performance Tips - Martin Mitrevski](https://martinmitrevski.com/2022/04/14/swiftui-performance-tips/)
- [Optimization and Debugging - Fatbobman](https://fatbobman.com/en/collections/optimization-debugging/)
- [8 Common SwiftUI Mistakes - Hacking with Swift](https://www.hackingwithswift.com/articles/224/common-swiftui-mistakes-and-how-to-fix-them)
- [Understanding SwiftUI Performance - Airbnb Engineering](https://medium.com/airbnb-engineering/understanding-and-improving-swiftui-performance-37b77ac61896)
- [Structural identity in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2021/12/09/structural-identity-in-swiftui/)
- [Avoiding massive SwiftUI views - Swift by Sundell](https://www.swiftbysundell.com/articles/avoiding-massive-swiftui-views/)
- [How to avoid using AnyView - Tanaschita](https://tanaschita.com/swiftui-how-to-avoid-using-anyview/)
- [SwiftUI Property Wrappers - Fatbobman](https://fatbobman.com/en/posts/exploring-key-property-wrappers-in-swiftui/)
- [@ScaledMetric Dynamic Type Support - SwiftLee](https://www.avanderlee.com/swiftui/scaledmetric-dynamic-type-support/)
- [Equatable Package for SwiftUI Diffing](https://github.com/ordo-one/equatable)
