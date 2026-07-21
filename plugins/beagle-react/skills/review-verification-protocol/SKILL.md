---
name: review-verification-protocol
description: Mandatory verification steps for all code reviews to reduce false positives. Load this skill before reporting ANY code review findings.
user-invocable: false
---

# Review Verification Protocol — React / TypeScript delta

**Load `beagle-core:review-verification-protocol` first.** It carries the hard gates, the Pre-Report Verification Checklist, Severity Calibration, the imported `beagle-core:verification-budget` vocabulary (risk tiers, loop budgets, the one-echo rule, the prove-a-negative ban), and the language-neutral Verification by Issue Type sections.

This file adds **only** what is specific to React, TypeScript, and the surrounding frontend stack. Everything else is in the core; nothing here overrides it.

## Verification by Issue Type — frontend specifics

### "Unused Variable/Function"

Run the core's four-pattern reference search, then add these frontend false positives:

- State setters in React — may trigger re-renders even when the value looks unused
- Identifiers referenced only from JSX or template markup
- Exports consumed by another package in the workspace
- Props threaded through a component that only forwards them

### "Missing Validation/Error Handling"

Frontend-specific mitigations to check before flagging:

- The framework already validates (Zod schema, React Hook Form resolver, route loader/action parsing)
- A parent component validates before passing props
- An error boundary or route `errorElement` catches at a higher level

### "Type Assertion/Unsafe Cast"

Confirm it is an assertion, not an annotation, and that narrowing has not already happened:

```typescript
// Type annotation, NOT assertion
const data: UserData = await loader()

// Type narrowing makes this safe
if (isUser(data)) {
  data.name  // TypeScript knows this is User
}
```

Framework-guaranteed types (loader data, form data, generated route types) are not unsafe casts.

### "Potential Memory Leak/Race Condition"

- Cleanup may exist in the `useEffect` return rather than at the call site
- An `AbortController` signal may be checked after the await, further down
- Confirm the component can actually unmount during the async operation

### "Performance Issue"

**Do NOT flag:** functions created in click handlers (run once per click), array methods on small arrays (< 100 items), object creation in event handlers. Check whether the React compiler or existing memoization already covers it.

## Valid Patterns (Do NOT Flag)

### TypeScript

| Pattern | Why It's Valid |
|---------|----------------|
| `map.get(key) \|\| []` | `Map.get()` returns `T \| undefined`, fallback is correct |
| Class exports without a separate type export | Classes work as both value and type |
| `as const` on literal arrays | Creates readonly tuple types |
| Type annotation on variable declaration | Not a type assertion |
| `satisfies` instead of `as` | Type checking without assertion |

### React

| Pattern | Why It's Valid |
|---------|----------------|
| Array index as key (static list) | Valid when items don't reorder, the list is static, and no item identity is needed |
| Inline arrow in `onClick` | Valid for non-performance-critical handlers (runs once per click) |
| State that appears unused | May be set via refs or external callbacks, or exist to trigger re-renders |
| Empty dependency array with refs | Refs are stable and don't need to be dependencies |
| Non-null assertion after a check | TypeScript narrowing may not track through all patterns |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| `toHaveTextContent` without regex | Handles nested text correctly |
| Mock at module level | Defined once, not duplicated |
| Index-based test data | Tests don't need stable identity |
| Simplified error messages | Test clarity over production polish |

## Context-Sensitive Rules

Each list below is an enumerated check, evaluated once. If an item is undecidable, drop the finding or ship it as a question — do not open another verification pass.

### React Keys

Flag array index as key **ONLY IF ALL** of these hold:
- [ ] Items CAN be reordered (sortable list, drag-drop)
- [ ] Items CAN be inserted or removed from the middle
- [ ] Items HAVE stable identifiers available (id, uuid)
- [ ] The list is NOT completely replaced atomically

### useEffect Dependencies

Flag a missing dependency **ONLY IF**:
- [ ] The value actually changes during the component lifetime
- [ ] A stale closure would cause incorrect behavior
- [ ] The value is NOT a ref (refs are stable)
- [ ] The value is NOT a stable callback (`useCallback` with empty deps)

### Error Handling

Flag a missing try/catch **ONLY IF**:
- [ ] No error boundary catches this at a higher level
- [ ] The framework doesn't handle it (loader `errorElement`)
- [ ] The error would cause a crash, not just a failed operation
- [ ] The user needs specific feedback for this error type
