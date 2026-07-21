---
name: go-verification-protocol
description: Go-specific verification deltas layered on top of beagle-core:review-verification-protocol. Covers how to confirm Go review findings before reporting them — unused identifiers, error handling, goroutine and concurrency claims, interface and generics usage. Load the shared core protocol first, then this skill, before reporting ANY Go code review findings.
user-invocable: false
---

# Review Verification Protocol — Go delta

**Load `beagle-core:review-verification-protocol` first.** It carries the hard gates, the Pre-Report Verification Checklist, Severity Calibration, the imported `beagle-core:verification-budget` vocabulary (risk tiers, loop budgets, the one-echo rule, the prove-a-negative ban), and the language-neutral Verification by Issue Type sections.

This file adds **only** what is specific to Go. Everything else is in the core; nothing here overrides it.

## Verification by Issue Type — Go specifics

### "Unused Variable/Function"

Run the core's four-pattern reference search. Go-specific reference patterns to include:

- Exported identifiers consumed by another module or by external importers
- Methods satisfying an interface implicitly — no explicit `implements` to grep for
- Symbols reached by reflection, struct tags, or `init()` registration
- Build-tag-gated files (`//go:build`) excluded from the default search

### "Missing Validation/Error Handling"

Check whether the caller, middleware chain, or `http.Handler` wrapper already enforces the rule before flagging, and whether the check exists in a different form (a sentinel error compared with `errors.Is`, a wrapped error, a validator on the request struct).

### "Type Assertion/Unsafe Cast"

The comma-ok form and type switches are safe narrowing, not unsafe casts:

```go
// Type assertion with ok check, NOT an unsafe cast
data, ok := value.(UserData)
if !ok {
    return fmt.Errorf("unexpected type: %T", value)
}

// Type switch is safe narrowing
switch v := value.(type) {
case User:
    v.Name  // Go knows this is User
}
```

Only a bare `value.(T)` with no ok result is a genuine panic risk.

### "Potential Goroutine Leak / Race Condition"

- Check for `context` cancellation, a `WaitGroup`, or a shutdown channel before claiming a leak
- Check whether a `sync.Mutex`, channel, or `sync/atomic` already guards the access
- Confirm the goroutine can actually outlive its parent scope

## Valid Patterns (Do NOT Flag)

### Go

| Pattern | Why It's Valid |
|---------|----------------|
| `val, ok := map[key]` | Comma-ok idiom, standard for maps |
| Returning `error` as the last return value | Go error handling convention |
| `defer` for cleanup | Correct resource management pattern |
| Short variable names in small scope | Idiomatic Go (`i`, `err`, `ctx`) |
| `interface{}` / `any` in generic code | Valid for truly heterogeneous data |

### Concurrency

| Pattern | Why It's Valid |
|---------|----------------|
| Unbuffered channel for synchronization | Correct when goroutines must synchronize |
| `select` with `default` | Non-blocking channel operation, intentional |
| `sync.Once` for initialization | Thread-safe lazy init pattern |
| `context.Background()` in main/tests | Valid root context for top-level calls |
| Goroutine without explicit join | Valid for fire-and-forget with proper lifecycle management |

### Testing

| Pattern | Why It's Valid |
|---------|----------------|
| Table-driven tests | Standard Go testing pattern |
| `t.Helper()` in test utilities | Correct for accurate error line reporting |
| `testify/assert` alongside stdlib | Common and acceptable in Go projects |
| Test function names without `_` | `TestFooBar` is idiomatic Go |

## Context-Sensitive Rules

Each list below is an enumerated check, evaluated once. If an item is undecidable, drop the finding or ship it as a question — do not open another verification pass.

### Error Handling

Flag an unchecked error **ONLY IF ALL** of these hold:
- [ ] The error return is explicitly discarded (not via `_` with a justifying comment)
- [ ] The function can return meaningful errors (not just `Close()`)
- [ ] Not in test or example code
- [ ] The error would indicate a real problem, not a benign condition

### Goroutine Lifecycle

Flag a goroutine leak **ONLY IF**:
- [ ] No context cancellation controls the goroutine
- [ ] No channel or `WaitGroup` provides a shutdown signal
- [ ] The goroutine can outlive its parent scope
- [ ] Not a top-level server goroutine managed by the runtime

### Interface Design

Flag a missing interface **ONLY IF**:
- [ ] The concrete type is used across package boundaries
- [ ] Testing requires mocking the dependency
- [ ] Multiple implementations exist or are planned
- [ ] Not a simple data struct (interfaces are for behavior, not data)
