# View Composition

## View Body Complexity

Keep view bodies under 10 composed elements. Extract subviews when bodies grow large.

```swift
// BAD - massive body
struct ProductView: View {
    let product: Product

    var body: some View {
        VStack {
            // 50+ lines of inline views
        }
    }
}

// GOOD - extracted subviews
struct ProductView: View {
    let product: Product

    var body: some View {
        VStack {
            PriceSection(price: product.price)
            DetailsSection(description: product.description)
        }
    }
}
```

## Computed Property Views

Avoid computed property views - they prevent SwiftUI diffing.

```swift
// BAD - can't be diffed
var priceSection: some View {
    VStack { /* content */ }
}

// GOOD - proper View struct enables diffing
struct PriceSection: View {
    let price: Decimal
    var body: some View { /* content */ }
}
```

## Modifier Ordering

Modifiers apply in order. Common patterns:

```swift
// BAD - background only covers text
Text("Hello")
    .background(.blue)
    .padding()

// GOOD - background covers padded area
Text("Hello")
    .padding()
    .background(.blue)

// BAD - shadow clipped away
RoundedRectangle()
    .shadow(radius: 5)
    .clipShape(Circle())

// GOOD - shadow visible
RoundedRectangle()
    .clipShape(Circle())
    .shadow(radius: 5)
```

## Subview Parameters

Pass simple parameters, not domain models, for reusability.

```swift
// BAD - coupled to model
struct PriceLabel: View {
    let product: Product  // Tightly coupled
}

// GOOD - model-agnostic
struct PriceLabel: View {
    let price: Decimal
    let discount: Decimal?
}
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| `var section: some View {}` | Computed views prevent diffing |
| Body over 10 composed elements | Hard to maintain and test |
| `.background().padding()` | Wrong modifier order |
| Inline closures with complex logic | Extract to methods or views |

## Review Questions

1. Could this view body be split into smaller View structs?
2. Are there computed property views that should be View structs?
3. Is the modifier order intentional and correct?
4. Are subviews model-agnostic and reusable?
