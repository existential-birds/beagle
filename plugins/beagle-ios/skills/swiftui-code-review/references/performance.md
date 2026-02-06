# Performance

## Lazy Stacks

Use LazyVStack/LazyHStack for scrolling content with many items.

```swift
// BAD - all 1000 items rendered immediately
ScrollView {
    VStack {
        ForEach(items) { ItemView(item: $0) }
    }
}

// GOOD - only visible items rendered
ScrollView {
    LazyVStack {
        ForEach(items) { ItemView(item: $0) }
    }
}
```

## AnyView Avoidance

AnyView defeats SwiftUI's type-based diffing.

```swift
// BAD - SwiftUI can't diff
func makeView(type: ViewType) -> some View {
    switch type {
    case .a: return AnyView(ViewA())
    case .b: return AnyView(ViewB())
    }
}

// GOOD - preserves type information
@ViewBuilder
func makeView(type: ViewType) -> some View {
    switch type {
    case .a: ViewA()
    case .b: ViewB()
    }
}
```

## ForEach Identity

Use stable Identifiable IDs, never array indices.

```swift
// BAD - index changes when array changes
ForEach(items.indices, id: \.self) { index in
    ItemView(item: items[index])
}

// GOOD - stable ID from Identifiable
ForEach(items) { item in
    ItemView(item: item)
}

// BAD - dynamic range without id
@State var count = 5
List(0..<count) { i in Text("Row \(i)") }  // Crashes!

// GOOD - dynamic range with id
List(0..<count, id: \.self) { i in Text("Row \(i)") }
```

## Equatable Views

For complex views, implement Equatable to optimize diffing.

```swift
struct CalendarView: View, Equatable {
    let events: [Event]
    let selectedDate: Date

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.events.count == rhs.events.count &&
        lhs.selectedDate == rhs.selectedDate
    }

    var body: some View { /* expensive */ }
}

// Usage
ParentView()
    .equatable()
```

## View Body Efficiency

Avoid expensive operations in view body.

```swift
// BAD - formatter created on every rebuild
var body: some View {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return Text(formatter.string(from: date))
}

// GOOD - cached formatter
private static let formatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    return f
}()
```

## Expensive Visual Effects

Blur, shadow, and mask cause offscreen rendering.

```swift
// CAUTION - expensive in lists
ForEach(items) { item in
    ItemView(item: item)
        .blur(radius: 5)      // Expensive
        .shadow(radius: 10)   // Expensive
}
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| VStack in ScrollView with 100+ items | All items rendered at once |
| AnyView | Defeats type-based diffing |
| ForEach with array index as id | View recreation on array change |
| .id() modifier inside List | Prevents List optimization |
| DateFormatter in view body | Recreated on every rebuild |

## Review Questions

1. Should this VStack/HStack be Lazy for scrolling performance?
2. Is AnyView used? Can @ViewBuilder replace it?
3. Does ForEach use stable Identifiable IDs?
4. Are expensive computations cached outside view body?
5. Are visual effects (blur, shadow) used sparingly in lists?
