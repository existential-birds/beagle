# Unsafe Code: Deep Review

For basic unsafe patterns and Edition 2024 changes, see [common-mistakes.md](common-mistakes.md).

## Safety Contracts and Documentation

Every `unsafe fn` must document the conditions under which it is safe to call. Every `unsafe {}` block must explain why those conditions are met.

**Flag when**:
- An `unsafe fn` has no `# Safety` section in its doc comment
- An `unsafe {}` block has no `// SAFETY:` comment
- A safety comment says "this is safe" without explaining the invariant

### Documentation Template

```rust
/// Reconstructs a `Foo` from its raw parts.
///
/// # Safety
///
/// - `ptr` must have been obtained from `Foo::into_raw`
/// - `ptr` must not have been freed since that call
/// - The caller must ensure no other `Foo` exists for this pointer
pub unsafe fn from_raw(ptr: *mut Inner) -> Self {
    // SAFETY: caller guarantees ptr is valid and uniquely owned
    // per the documented contract above.
    Self { inner: unsafe { Box::from_raw(ptr) } }
}
```

## Raw Pointer Validity Rules

A raw pointer dereference is safe only when ALL of these hold:

1. **Non-null**: the pointer is not null
2. **Aligned**: the pointer is properly aligned for the target type
3. **Initialized**: the pointed-to memory contains a valid value for the type
4. **Provenance**: the pointer was derived from a valid allocation (not fabricated from an integer without care)
5. **No aliasing violations**: creating `&T` from `*const T` requires no `&mut T` exists; creating `&mut T` requires exclusive access

**Check for**:
- Pointer arithmetic via `.add()`, `.sub()`, `.offset()` — result must stay within the same allocation
- Casts between `*const T` and `*mut T` — does not grant mutable access; aliasing rules still apply
- Integer-to-pointer casts — these have provenance concerns and are almost always wrong

### Pointer Type Selection

| Type | Variance | Null? | Use When |
|------|----------|-------|----------|
| `*const T` | covariant | yes | Would use `&T` but can't name the lifetime |
| `*mut T` | **invariant** | yes | Would use `&mut T` but can't name the lifetime |
| `NonNull<T>` | covariant | no | Non-null `*const T` with niche optimization |

## MaybeUninit Patterns

`MaybeUninit<T>` stores a `T` without requiring it to be valid. The compiler makes no assumptions about the value.

### Correct Pattern

```rust
let mut buf = [MaybeUninit::<u8>::uninit(); 4096];
let mut initialized = 0;
for (i, byte) in source.iter().take(4096).enumerate() {
    buf[i] = MaybeUninit::new(*byte);
    initialized = i + 1;
}
// SAFETY: buf[..initialized] was written with valid u8 values
let init = unsafe { MaybeUninit::slice_assume_init_ref(&buf[..initialized]) };
```

**Flag when**:
- `assume_init()` called before all bytes are written — undefined behavior
- Reading from `MaybeUninit` via `as_ptr()` on uninitialized portions
- Missing panic safety: if a panic occurs mid-initialization, partially initialized memory must not be assumed valid on drop

### Panic Safety with MaybeUninit

```rust
// BAD — if T::default() panics, Vec::drop reads uninitialized memory
unsafe {
    vec.set_len(vec.capacity());
    for i in old_len..vec.len() {
        *vec.get_unchecked_mut(i) = T::default(); // panic here = UB
    }
}

// GOOD — update length only after successful initialization
for i in old_len..vec.capacity() {
    vec.push(T::default()); // push handles length correctly
}
```

## UnsafeCell and Interior Mutability

`UnsafeCell<T>` is the **only** correct way to mutate through a shared reference. All safe interior mutability types (`Cell`, `RefCell`, `Mutex`) use it internally.

**Flag when**:
- Code mutates through `&T` without `UnsafeCell` — this is always undefined behavior, even if "it works"
- A type provides `&mut T` from `&self` without going through `UnsafeCell` or an atomic
- The shared reference immutability invariant is violated transitively: an `&Foo` where `Foo` contains `*mut T` that gets mutated without `UnsafeCell` wrapping

## Soundness

An abstraction is **sound** if no sequence of safe calls can trigger undefined behavior. An abstraction is **unsound** if safe code can cause UB.

### Soundness Checklist

1. Can safe callers cause a raw pointer dereference of an invalid pointer?
2. Can safe callers break an invariant that `unsafe` blocks depend on?
3. Does the public API expose enough to invalidate internal safety assumptions?
4. Are `Send`/`Sync` implementations correct? Missing bounds on generics? (`unsafe impl<T: Send> Send for MyType<T> {}`)
5. Could a safe `Unpin` implementation break pinning invariants?
6. Does implementing `Drop` access data that might already be dangling?

**Flag when**:
- An `unsafe impl Send` or `unsafe impl Sync` lacks bounds on generic parameters
- Safe public methods can put the type into a state where internal `unsafe` becomes invalid
- A privacy boundary is too wide — fields that unsafe code depends on are `pub` or `pub(crate)` without justification

## Unsafe Code Review Checklist

| Check | What to Verify |
|-------|---------------|
| Safety comments | Every `unsafe` block and `unsafe fn` has documented invariants |
| Minimal scope | Only the truly unsafe op is inside `unsafe {}` |
| Pointer validity | Non-null, aligned, initialized, within allocation bounds |
| Aliasing | No simultaneous `&T` and `&mut T` to the same memory |
| Panic safety | State is consistent if user-provided code panics mid-operation |
| Drop safety | `Drop` impl doesn't access dangling data; `PhantomData` used for drop check |
| Send/Sync | Manual implementations have correct bounds; raw pointers covered |
| UnsafeCell | All interior mutation goes through `UnsafeCell` |
| FFI | Extern blocks are `unsafe extern` (Edition 2024); signatures match the foreign ABI |
| Casting | Type casts between `repr(Rust)` types are invalid without layout guarantees |

## When to Flag

- **Missing safety comments**: always flag, no exceptions. This is the single most important unsafe review rule.
- **Undocumented invariants**: if the safety of an `unsafe` block depends on an invariant not stated anywhere, flag it.
- **Unnecessary unsafe**: code that could be written safely but uses `unsafe` for convenience or perceived performance. Measure first.
- **Wide unsafe blocks**: safe operations mixed into `unsafe {}` — extract them.
- **`transmute` without `repr` guarantees**: casting between types that are both `repr(Rust)` is never guaranteed to be sound.

## Miri as Verification Tool

Miri interprets Rust at the MIR level and detects:
- Use of uninitialized memory
- Out-of-bounds pointer access
- Aliasing violations (Stacked Borrows / Tree Borrows model)
- Use-after-free
- Invalid enum discriminants
- Misaligned references

**Check for**: whether the project runs `cargo +nightly miri test` in CI. For any non-trivial unsafe code, Miri coverage is a strong signal of correctness. Flag when unsafe code lacks Miri test coverage.

## Review Questions

1. Does every `unsafe` block have a `// SAFETY:` comment explaining the invariant?
2. Is the `unsafe` scope minimal — only the truly unsafe operation inside the block?
3. Are raw pointer dereferences provably valid (non-null, aligned, initialized, in-bounds)?
4. Is the code panic-safe — would a panic leave the program in a valid state?
5. Are `Send`/`Sync` implementations bounded correctly on generic parameters?
6. Could any safe public API call sequence trigger undefined behavior?
7. Is Miri used to test unsafe code paths?
