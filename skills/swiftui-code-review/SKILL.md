---
name: swiftui-code-review
description: "Reviews SwiftUI code for view composition, state management, performance, and accessibility. Use when reviewing .swift files containing SwiftUI views, property wrappers (@State, @Binding, @Observable, @Bindable), or UI code."
---

# SwiftUI Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| View extraction, modifiers, body complexity | [references/view-composition.md](references/view-composition.md) |
| `@State`, `@Binding`, `@Observable`, `@Bindable`, `@Environment` | [references/state-management.md](references/state-management.md) |
| `LazyVStack`, `AnyView`, `ForEach`, view identity | [references/performance.md](references/performance.md) |
| VoiceOver, Dynamic Type, labels, traits | [references/accessibility.md](references/accessibility.md) |

## Gates (review workflow)

Complete in order; do not skip ahead.

1. **Anchor scope** — Pass when: every reviewed file is listed as a repo-relative `.swift` path (or the review explicitly states “none opened / N/A” with reason).
2. **Reference before critique** — Pass when: for any non-trivial body, modifier chain, or wrapper-ownership question, you have opened the matching `references/*.md` row from the table above *or* you state “not needed” with one line why.
3. **Evidence-bound findings & protocol** — Pass when: every finding satisfies `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) and includes **`[FILE:LINE]`** (or a bounded line range) before recommendations; symbols/snippets may supplement but not replace the location anchor; no finding that rests only on “typical SwiftUI” without pointing at this code.

## Review Checklist

- [ ] Large view bodies (`> 40` lines or causing measurable layout/type-checker cost) extracted into reusable `View` structs (not trivial 1–3 line leaf views)
- [ ] Modifiers in correct order (`padding` before `background`, `clipShape` before `shadow`)
- [ ] iOS 17+ `@Observable`: `@State` in owning view (with lightweight `init()`), plain property for read-only child access, `@Bindable` for two-way bindings, `@Environment(Type.self)` for environment injection
- [ ] Legacy `ObservableObject` (when supporting `< iOS 17` or Combine): `@StateObject` in owning view, `@ObservedObject` when passed from parent
- [ ] `LazyVStack`/`LazyHStack` for scrolling lists with many items (e.g. 50+)
- [ ] No `AnyView` (use `@ViewBuilder` or generics instead)
- [ ] `ForEach` uses stable `Identifiable` IDs (not array indices)
- [ ] Interactive icon-only controls have `.accessibilityLabel(...)` and decorative SF Symbols use `.accessibilityHidden(true)`
- [ ] Custom controls have `.accessibilityAddTraits(.isButton)` (and value/selection state)
- [ ] Dynamic Type supported (semantic text styles rather than fixed font sizes)
- [ ] `.task` modifier for view-scoped async work (not `onAppear` + unstructured `Task`)

## When to Load References

- Complex view bodies or modifier chains -> [references/view-composition.md](references/view-composition.md)
- Property wrapper usage (`@State`, `@Bindable`, `@Observable`, `@StateObject`) -> [references/state-management.md](references/state-management.md)
- List performance or view identity issues -> [references/performance.md](references/performance.md)
- VoiceOver or accessibility implementation -> [references/accessibility.md](references/accessibility.md)

## Review Questions

1. Should a view body over 40 lines (or causing slow type-checking/re-evaluation) be split into dedicated `View` structs?
2. Is modifier order intentional (`padding` -> `background` -> `frame`, `clipShape` -> `shadow`)?
3. Is ownership clear (`@State` + `@Observable` or legacy `@StateObject` in the creator, plain property/`@Bindable` in children)?
4. Could `LazyVStack`/`LazyHStack` improve this `ScrollView`'s performance?
5. Would VoiceOver users understand interactive icons and decorative symbols?
