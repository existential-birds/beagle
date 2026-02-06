# Accessibility

## Accessibility Labels

All interactive elements need descriptive labels.

```swift
// BAD - VoiceOver says "heart"
Button(action: { addToFavorites() }) {
    Image(systemName: "heart")
}

// GOOD - VoiceOver says "Add to favorites"
Button(action: { addToFavorites() }) {
    Image(systemName: "heart")
}
.accessibilityLabel("Add to favorites")
.accessibilityHint("Double tap to add to your favorites")
```

## Decorative Images

Hide non-informative images from VoiceOver.

```swift
// BAD - VoiceOver reads "star fill"
HStack {
    Image(systemName: "star.fill")
    Text("Premium Feature")
}

// GOOD - decorative image hidden
HStack {
    Image(decorative: "star.fill")
    Text("Premium Feature")
}

// Alternative
Image(systemName: "star.fill")
    .accessibilityHidden(true)
```

## Custom Control Traits

Custom interactive views need accessibility traits.

```swift
// BAD - VoiceOver doesn't know it's tappable
struct CustomCheckbox: View {
    @Binding var isChecked: Bool
    var body: some View {
        Image(systemName: isChecked ? "checkmark.square" : "square")
            .onTapGesture { isChecked.toggle() }
    }
}

// GOOD - proper accessibility
struct CustomCheckbox: View {
    @Binding var isChecked: Bool
    var body: some View {
        Image(systemName: isChecked ? "checkmark.square" : "square")
            .onTapGesture { isChecked.toggle() }
            .accessibilityLabel("Agreement")
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isChecked ? .isSelected : [])
            .accessibilityValue(isChecked ? "Checked" : "Unchecked")
    }
}
```

## Common Traits

| Trait | Use Case |
|-------|----------|
| `.isButton` | Custom tappable views |
| `.isHeader` | Section headers |
| `.isSelected` | Current selection state |
| `.isLink` | External navigation |

## Grouping Elements

Combine related elements for VoiceOver.

```swift
// BAD - read separately
VStack {
    Text("John Doe")
    Text("Senior Developer")
    Text("San Francisco")
}

// GOOD - single announcement
VStack {
    Text("John Doe")
    Text("Senior Developer")
    Text("San Francisco")
}
.accessibilityElement(children: .combine)
```

## Dynamic Type

Use semantic fonts, not fixed sizes.

```swift
// BAD - ignores user preference
Text("Settings")
    .font(.system(size: 17))

// GOOD - scales with preference
Text("Settings")
    .font(.body)
```

## Environment Properties

Check accessibility settings.

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.accessibilityDifferentiateWithoutColor) var noColor
@Environment(\.dynamicTypeSize) var typeSize
```

## Critical Anti-Patterns

| Pattern | Issue |
|---------|-------|
| Interactive element without label | VoiceOver can't describe it |
| Decorative image not hidden | Clutters VoiceOver reading |
| Custom control without traits | VoiceOver doesn't indicate interactivity |
| Fixed font sizes | Ignores Dynamic Type |
| Color-only information | Excludes color blind users |
| Touch target < 44pt | Hard to tap |

## Review Questions

1. Do all interactive elements have accessibilityLabel?
2. Are decorative images hidden from VoiceOver?
3. Do custom controls have proper accessibility traits?
4. Are related UI elements grouped for VoiceOver?
5. Does the UI support Dynamic Type (no fixed font sizes)?
6. Is color paired with other indicators (shape, text, icon)?
