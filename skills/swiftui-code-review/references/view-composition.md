# View Composition

## View Body Complexity

Flag `View.body` complexity only when the body is genuinely oversized (`> 40` lines) or exhibits measurable layout/type-checker cost (e.g., deeply nested branches or slow Swift expression type-checking)—do **not** flag small leaf views or concise 10–20 line compositions just to add boilerplate.

```swift
// BAD - massive body (> 40 lines of nested layout and business formatting)
struct ProductView: View {
    let product: Product

    var body: some View {
        VStack {
            // 50+ lines of inline views and nested modifiers
        }
    }
}

// GOOD - extracted subviews with clear inputs
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

## Computed Property Views vs Extracted `View` Structs

SwiftUI **still structurally diffs** computed `some View` properties, *however* computed properties share the parent's `View` identity—so whenever the parent's state changes, SwiftUI must re-evaluate the computed property inside the parent's `body`. Extracting a separate `View` `struct` creates an independent `View` identity and equatability boundary, allowing SwiftUI to **skip evaluating the subview's `body`** when its stored inputs haven't changed (and keeping `@State` scoped cleanly). Reserve `@ViewBuilder` computed properties for tiny 1–3 line layout helpers.

```swift
// SUBOPTIMAL for non-trivial sections - re-evaluated on every parent body pass
var priceSection: some View {
    VStack { /* complex section reading parent state */ }
}

// GOOD - independent View identity & diffing boundary; skipped when `price` is unchanged
struct PriceSection: View {
    let price: Decimal
    var body: some View { /* content */ }
}
```

## Modifier Ordering

Modifiers wrap the view sequentially and order changes layout/rendering behavior:

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
RoundedRectangle(cornerRadius: 12)
    .shadow(radius: 5)
    .clipShape(Circle())

// GOOD - shadow remains visible outside clip
RoundedRectangle(cornerRadius: 12)
    .clipShape(Circle())
    .shadow(radius: 5)
```

## Subview Parameters

Pass minimal value inputs rather than entire domain models when a leaf view only needs a couple of fields—this narrows its dependencies and improves equatability skipping.

```swift
// BAD - coupled to full Product; redraws when unrelated Product fields change
struct PriceLabel: View {
    let product: Product
}

// GOOD - narrow value inputs
struct PriceLabel: View {
    let price: Decimal
    let discount: Decimal?
}
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| Non-trivial `var section: some View {}` | Shares parent identity; re-evaluated on every parent update instead of skipped at subview boundary |
| Monolithic `body` (`> 40` lines) | Hurts type-checker performance, diffing granularity, and readability |
| `.background().padding()` | Wrong modifier order |
| Passing whole models to leaf views | Causes unnecessary invalidations when unrelated fields change |

## Review Questions

1. Should any monolithic `body` (`> 40` lines) be split into focused `View` structs?
2. Are complex computed `some View` properties missing an independent `View` struct boundary?
3. Is the modifier order intentional (`padding` -> `background`, `clipShape` -> `shadow`)?
4. Are leaf subviews receiving only the values they read rather than whole mutable models?
