# Lifetime Variance

## Variance Fundamentals

Variance describes when a subtype can substitute for a supertype. A lifetime `'b` is a subtype of `'a` if `'b: 'a` (outlives). There are three kinds:

- **Covariant**: a subtype can substitute freely. `&'a T` is covariant in both `'a` and `T`.
- **Invariant**: must match exactly. `&mut T` is invariant in `T`; `Cell<T>` is invariant in `T`.
- **Contravariant**: flipped relationship. `fn(T)` is contravariant in `T` (a function accepting less-specific args is more useful).

### Quick Reference Table

| Type | Variance in `'a` | Variance in `T` |
|------|-------------------|------------------|
| `&'a T` | covariant | covariant |
| `&'a mut T` | covariant | **invariant** |
| `Cell<T>` / `RefCell<T>` | — | **invariant** |
| `*const T` / `NonNull<T>` | — | covariant |
| `*mut T` | — | **invariant** |
| `fn(T) -> U` | — | **contra** in `T`, covariant in `U` |
| `Box<T>` / `Vec<T>` | — | covariant |
| `UnsafeCell<T>` | — | **invariant** |

## When Variance Causes Bugs

### Invariance Behind `&mut`

**Flag when**: a type uses a single lifetime where two are needed, and one appears behind `&mut`.

```rust
// BAD — single lifetime forces invariance, won't compile
struct MutStr<'a> {
    s: &'a mut &'a str,
}

// GOOD — two lifetimes decouple the mutable borrow from the inner reference
struct MutStr<'a, 'b> {
    s: &'a mut &'b str,
}
```

With one lifetime, the compiler cannot shorten the mutable borrow independently of the inner `&str` because `&mut T` is invariant in `T`. Two lifetimes let the outer borrow end while the inner `&str` lifetime remains `'static`.

### `Cell<&'a T>` Is Invariant

**Flag when**: `Cell` or `RefCell` wraps a reference and code assumes lifetime covariance.

```rust
// This won't compile — Cell<&'a T> is invariant in 'a
fn bad<'a>(cell: &Cell<&'a str>) {
    let local = String::from("temp");
    cell.set(&local); // would allow dangling ref if covariant
}
```

Invariance is correct here: if `Cell<&'a str>` were covariant, you could store a short-lived reference that outlives its source.

## Memory Regions and Lifetime Implications

- **Stack**: references to stack frames cannot outlive the frame. Check that returned references don't point to locals.
- **Heap** (`Box`, `Arc`): lifetime is unconstrained until deallocation. `Box::leak` produces `&'static`.
- **Static memory**: `'static` references to `static` variables or string literals are always valid.

**Check for**: `'static` bounds on type parameters (e.g., `T: 'static`) — this means `T` must be owned or itself `'static`, not that it lives forever. Common in `thread::spawn` and `tokio::spawn` closures.

## Lifetime Annotation Review Rules

### Flag When

- **Unnecessary `'static` on parameters**: `fn process(name: &'static str)` when `&str` suffices. This forces callers to provide only compile-time strings or leaked allocations.
- **Missing multiple lifetimes**: a struct holds references to two independent sources but uses one lifetime, causing invariance-related compilation failures or overly restrictive APIs.
- **Lifetime on return but not needed**: functions returning owned data (`String`, `Vec<T>`) that carry a phantom lifetime parameter.
- **Single lifetime on iterator types**: types like `StrSplit` that yield references from one field but borrow a different field need separate lifetimes so the yielded reference isn't tied to the shorter-lived field.

### Valid Patterns

- **Elided lifetimes**: when the three elision rules apply, explicit annotations are noise. Don't flag missing annotations when elision handles it.
- **`'a` on `&self` returns**: rule 3 of elision assigns `self`'s lifetime to outputs. Explicit annotation is optional.
- **`'static` for `thread::spawn` and `tokio::spawn`**: required by the API, not a code smell.
- **`'static` trait bounds**: `T: 'static` on generic parameters is standard for owned, self-sufficient types.

## Common Mistakes

### Conflating `'static` with "lives forever"

`T: 'static` means `T` contains no non-static borrows. An owned `String` is `'static`. This is a bound, not a lifetime annotation on a reference.

### Ignoring Drop's interaction with lifetimes

If a type implements `Drop` and is generic over `'a`, dropping counts as a use of `'a`. Code that shortens borrows before the drop site may fail to compile.

```rust
// If Wrapper<'a> implements Drop, this won't compile:
let mut x = 42;
let w = Wrapper(&mut x);
x = 0; // x is still mutably borrowed because w.drop() might use it
```

**Check for**: types with `Drop` that hold references — the borrow extends to the drop point, not the last explicit use.

### **Edition 2024**: RPIT captures all lifetimes by default

In edition 2024, `-> impl Trait` captures all in-scope lifetime parameters. Use `+ use<'a>` to narrow capture when the return value doesn't actually borrow all parameters.

## Review Questions

1. Does the type need multiple lifetime parameters, or does a single lifetime cause invariance issues?
2. Are `'static` annotations on parameters genuinely required, or would an elided lifetime work?
3. Do types implementing `Drop` account for the extended borrow at the drop site?
4. Are `Cell`/`RefCell` wrapping references with correct variance expectations?
5. **Edition 2024**: Do RPIT return types need `+ use<...>` to avoid capturing unrelated lifetimes?
