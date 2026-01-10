# Swift Common Mistakes

## Critical Anti-Patterns

### 1. Force Unwrapping Runtime Data

```swift
// BAD - crashes on invalid input
let url = URL(string: userProvidedString)!
let first = response.items.first!
let value = dictionary["key"]!

// GOOD - safe unwrapping
guard let url = URL(string: userProvidedString) else {
    showError("Invalid URL")
    return
}
let first = response.items.first ?? defaultItem
let value = dictionary["key", default: fallback]

// ACCEPTABLE force unwrap - compile-time verifiable
let url = URL(string: "https://apple.com")!
let image = UIImage(named: "AppIcon")!
```

### 2. Retain Cycles in Closures

```swift
// BAD - closure captures self strongly
class ViewController {
    var onComplete: (() -> Void)?
    func setup() {
        onComplete = { self.updateUI() }  // Retain cycle!
    }
}

// GOOD - weak capture
onComplete = { [weak self] in
    guard let self else { return }
    self.updateUI()
}
```

### 3. Delegate Without Weak

```swift
// BAD - strong delegate causes cycle
var delegate: SomeDelegate?

// GOOD - delegates are always weak
weak var delegate: SomeDelegate?
```

### 4. Nil Check Then Force Unwrap

```swift
// BAD - dangerous pattern
if optionalString != nil {
    print(optionalString!.count)
}

// GOOD - optional binding
if let string = optionalString {
    print(string.count)
}

// Swift 5.7+ shorthand
if let optionalString {
    print(optionalString.count)
}
```

### 5. Unnecessary Optionals

```swift
// BAD - always has value but declared optional
struct Person {
    let name: String?  // Set in init, never nil
    init(name: String) { self.name = name }
}

// GOOD - non-optional when always present
struct Person {
    let name: String
    init(name: String) { self.name = name }
}
```

### 6. Unchecked Array Access

```swift
// BAD - crashes if out of bounds
let item = items[index]
let first = items[0]  // Crashes if empty

// GOOD - bounds checking
if items.indices.contains(index) {
    let item = items[index]
}
let first = items.first  // Returns optional

// Safe subscript extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

### 7. Implicitly Unwrapped Optionals

```swift
// BAD - IUO for regular properties
class UserProfile {
    var name: String!
    var avatar: UIImage!  // Never set - crash!
}

// GOOD - proper optionals or non-optionals
class UserProfile {
    let name: String
    var avatar: UIImage?  // Truly optional
    init(name: String) { self.name = name }
}

// ACCEPTABLE IUO - @IBOutlet only
@IBOutlet weak var titleLabel: UILabel!
```

## Naming Conventions

```swift
// BAD naming
func chkPwd(_ p: String) -> Bool  // Unclear abbreviation
let stringName: String  // Type in name
var enabled: Bool  // Missing is/has prefix
func sort() -> [Int]  // Reads like mutation

// GOOD naming
func checkPassword(_ password: String) -> Bool
let userName: String  // Name by role
var isEnabled: Bool  // Predicate prefix
func sorted() -> [Int]  // Non-mutating returns new value
mutating func sort()  // Mutating is imperative verb
```

## Best Practices Summary

| Topic | Best Practice |
|-------|---------------|
| Force Unwrap | Only for compile-time verifiable constants |
| Retain Cycles | `weak` delegates, `[weak self]` in closures |
| Optionals | Use binding, not nil-check + force-unwrap |
| Collections | Use `.first`, `.last`, or safe subscript |
| IUOs | Only for @IBOutlet |

## Review Questions

1. Is this force unwrap (`!`) backed by compile-time certainty?
2. Could this closure stored as a property cause a retain cycle?
3. Are delegate properties marked `weak`?
4. Is this optional really necessary, or is it always set?
5. Is collection access bounds-checked?
