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

## Validity vs Safety

This is the keystone distinction for unsafe review. Reviewers who conflate the two miss the most consequential UB.

**Validity** is a property of bytes, fixed by the language. The compiler optimizes assuming values are valid; producing an invalid value is immediate UB even if you never read it.

- `bool` is valid only with byte `0x00` or `0x01`.
- `char` excludes surrogates `[0xD800, 0xDFFF]` and anything above `0x10FFFF`.
- `&T` and `&mut T` must be non-null, aligned, and point to a valid `T`.
- `NonNull<T>` must be non-null.
- An enum discriminant must match a declared variant.
- Reading uninitialized memory is invalid even at type `u8`.

**Safety** is a property defined by the *author* of an abstraction — invariants the type chose, not the language. `Vec<T>` requires `len <= cap` and elements `[0..len)` initialized. Violating safety is UB only when it becomes observable through a safe API; violating validity is UB the moment the invalid value exists.

```rust
// Invalid: bit pattern 2 is not a valid bool. Immediate UB.
let b: bool = unsafe { mem::transmute::<u8, bool>(2) };

// Unsafe but not invalid: bytes are all valid u8s. UB only when
// safe Vec methods read past the initialized prefix.
let mut v: Vec<u8> = Vec::with_capacity(8);
unsafe { v.set_len(8); } // len > initialized — broken safety invariant
```

`MaybeUninit<T>` is the only canonical "valid bytes, possibly unsafe" container: `MaybeUninit<bool>` may hold `0x03`, `MaybeUninit<NonNull<T>>` may hold null. `assume_init` is the assertion that bytes are *now* also valid for `T`.

- `[FILE:LINE] INVALID_BOOL_FROM_TRANSMUTE` — `mem::transmute::<u8, bool>(x)` where `x` may be outside `{0, 1}`. Invalid value, immediate UB. Use `x != 0` or a checked constructor.
- `[FILE:LINE] INVALID_CHAR_FROM_U32` — `mem::transmute::<u32, char>(n)` for any `n` not pre-validated. Use `char::from_u32(n)` or `char::from_u32_unchecked` with a documented safety proof.
- `[FILE:LINE] UNINIT_INTEGER_READ` — `let x: u32 = unsafe { MaybeUninit::uninit().assume_init() };` and `x` is later read. Uninit at any integer type is UB. Use `MaybeUninit<u32>` and write before reading.

## Two Meanings of `unsafe`

Conflating these two roles is the most common review error.

**Declaring** (`unsafe trait`, `unsafe fn`, `unsafe impl`) signals "caller or implementer must uphold an invariant the compiler cannot check." The body may contain no unsafe ops — the keyword is a contract demand on the *user* of this item.

**Using** (`unsafe {}` block) signals "I, the author of this site, have audited every unsafe op inside against the documented invariants and they hold here." The block is a *signature* on the contract.

```rust
// Declaring: callers must promise self.cap > 0.
pub unsafe fn first(&self) -> &T {
    // Using: signing that the deref is in-bounds because the
    // documented precondition (cap > 0) was promised by the caller.
    unsafe { &*self.ptr.as_ptr() }
}
```

Edition 2024 (RFC 2585) closes the gap between the two: `unsafe fn` bodies no longer carry an implicit `unsafe {}` — each op needs its own block. This forces the implementer to mark which line is load-bearing and pair it with a `// SAFETY:` comment that proves the caller's contract is being relied on correctly.

- `[FILE:LINE] UNSAFE_FN_BODY_NO_INNER_BLOCK_2024` — Edition 2024 crate uses `unsafe fn` with raw unsafe ops in the body and no inner `unsafe {}` blocks. Wrap each op and add a `// SAFETY:` referencing the function's `# Safety` contract.
- `[FILE:LINE] UNSAFE_TRAIT_FOR_LOGIC_INVARIANT` — `unsafe trait` declared because a buggy impl would corrupt application state, not memory. Should be a safe trait whose contract is documented; only declare `unsafe trait` when memory unsafety is reachable from safe code.

## Drop Check, `#[may_dangle]`, and `PhantomData<T>`

The drop checker decides whether the lifetimes inside a value may dangle when `Drop` runs. A generic owning type whose `Drop` reads or drops a `T` must tell the compiler it owns a `T` — otherwise the drop checker mis-orders drops and safe code triggers use-after-free.

A type that holds `T` *only* through a raw pointer (`*mut T`, `NonNull<T>`, `*const T`) does not appear to own a `T` as far as the drop checker is concerned. Add `PhantomData<T>` to restore the dependency.

```rust
struct MyBox<T> {
    ptr: NonNull<T>,
    _owned: PhantomData<T>, // dropck marker: we own and drop a T
}
unsafe impl<#[may_dangle] T> Drop for MyBox<T> {
    fn drop(&mut self) {
        // SAFETY: ptr was Box::into_raw'd; drop the T in place.
        unsafe { ptr::drop_in_place(self.ptr.as_ptr()); }
    }
}
```

`#[may_dangle]` (nightly, `feature(dropck_eyepatch)`) opts a generic drop impl out of the strict drop-check rule. It asserts "my `Drop` does not access the borrowed contents of `T`'s lifetime." Combined with `PhantomData<T>`, this is sound; without `PhantomData<T>`, it is unsound because the compiler now believes nobody drops a `T`.

If your `Drop` needs `T` to outlive `self` (delayed deallocation, channel sends, GC), add `T: 'static`. Otherwise `T` may contain references that have already expired by the time `Drop` runs.

See [types-layout.md](types-layout.md) for `PhantomData` variance markers and [concurrency-models.md](concurrency-models.md) for deferred-drop patterns in actor systems.

- `[FILE:LINE] MAY_DANGLE_MISSING_PHANTOMDATA` — `unsafe impl<#[may_dangle] T> Drop for X<T>` where `X` holds `*mut T` / `NonNull<T>` / `*const T` and contains no `PhantomData<T>` field. Add `_owned: PhantomData<T>` so the drop checker sees the owned `T`.
- `[FILE:LINE] DEFERRED_DROP_NO_STATIC_BOUND` — `Drop` impl that hands `T` to a channel, background thread, or deferred queue without `T: 'static`. The deferral can outlive any non-static lifetime inside `T`.

## Provenance

Raw pointers carry hidden metadata identifying the originating allocation. The compiler uses provenance for aliasing analysis; round-tripping a pointer through an integer destroys it.

- `ptr as usize` discards provenance. The resulting integer is just bits.
- `usize as *mut T` cannot generally restore the original provenance. The recovered pointer has *synthesized* provenance, often invalid for the allocation you intended.
- Strict-provenance APIs make the model explicit: `ptr.addr()` returns the integer address, `ptr.with_addr(new)` produces a pointer with the *original* provenance and a new address, `expose_addr()` and `from_exposed_addr()` opt in to the legacy lossy round-trip when truly required (e.g., interpreter values).

```rust
// BAD: int-to-ptr fabricates provenance. Miri with -Zmiri-strict-provenance flags it.
let n: usize = ptr as usize;
let recovered: *mut T = n as *mut T;

// GOOD: with_addr keeps the original allocation's provenance.
let tagged: *mut T = ptr.with_addr((ptr.addr() & !3) | tag);
```

Tagged-pointer code (low-bit tags, NaN-boxing) is the most common provenance violator. Use `with_addr` and `map_addr`. Run `cargo +nightly miri test -- -Zmiri-strict-provenance` to flag round-trips.

See [memory-ordering.md](memory-ordering.md) for atomic pointer operations that interact with provenance.

- `[FILE:LINE] PTR_INT_ROUNDTRIP_NO_WITH_ADDR` — `let n = ptr as usize; ...; let p = n as *mut T;` to manipulate tag bits. Use `ptr.with_addr(n)` or `ptr.map_addr(|a| ...)` so provenance is preserved.
- `[FILE:LINE] FABRICATED_POINTER_FROM_CONST` — `0x1000 as *mut T` for MMIO or stub addresses without documentation that the platform guarantees the provenance. At minimum, use `ptr::without_provenance_mut(0x1000)` and document the platform contract.

## Panic Safety in Unsafe Code

Unwinding is the silent multiplier of unsafe UB. Every line that may panic is an implicit early return that runs `Drop` on every live local — if an unsafe block has temporarily broken a safety invariant, the unwind ships that violation into safe code.

**Double-drop hazard.** `ptr::read` copies a value bit-for-bit without moving ownership at the type level. Both the original location and the new value will be dropped. If a panic occurs between the read and the overwrite, both drops run.

```rust
// BAD: if user_callback panics, both old_value and self.slot drop the same T.
let old_value = unsafe { ptr::read(&self.slot) };
let new_value = user_callback(old_value); // panic here -> double drop
unsafe { ptr::write(&mut self.slot, new_value); }

// GOOD: wrap the duplicated value in ManuallyDrop until ownership is reconciled.
let old = ManuallyDrop::new(unsafe { ptr::read(&self.slot) });
```

**Partial-init drop hazard.** `Vec::set_len(n)` before all `n` slots are initialized means `Vec::drop` will read uninitialized memory as `T` and call `T::drop` on garbage. Bump length only after each write, or use a guard whose `Drop` re-truncates on panic.

**FFI boundary.** Unwinding into C is UB. Every `extern "C" fn` callable from foreign code must terminate panics with `std::panic::catch_unwind`, or be declared `extern "C-unwind"` if the foreign side genuinely supports unwinds.

```rust
extern "C" fn callback(arg: *const Args) -> i32 {
    let result = panic::catch_unwind(|| { /* Rust work that may panic */ });
    match result { Ok(code) => code, Err(_) => -1 }
}
```

- `[FILE:LINE] DOUBLE_DROP_VIA_PTR_READ` — `ptr::read` followed by code that can panic before the original slot is overwritten or `ManuallyDrop`-wrapped. Both the read value and the slot will drop.
- `[FILE:LINE] SET_LEN_BEFORE_INIT` — `Vec::set_len(n)` before the trailing `n - old_len` slots are written. A panic during init causes `Vec::drop` to read uninit `T`. Push per element or use a drop guard.
- `[FILE:LINE] PARTIAL_INIT_NO_DROP_GUARD` — uninitialized-slot init loop with no guard struct whose `Drop` truncates to the initialized prefix on panic.
- `[FILE:LINE] EXTERN_C_NO_CATCH_UNWIND` — `extern "C" fn` callable from foreign code that contains Rust calls which may panic without a top-level `panic::catch_unwind`. Unwinding into C is UB.
- `[FILE:LINE] CALLBACK_DURING_BROKEN_INVARIANT` — user-provided closure, `Clone::clone`, `Default::default`, or `?` runs between two unsafe ops while a type invariant (length, init prefix, ownership) is temporarily violated.

## Casting Pitfalls

Three increasingly dangerous tools, often confused.

**`as` casts** for numeric types are silent and lossy: `0x1FFu32 as u8 == 0xFF`. Float-to-int saturates since 1.45 (well-defined) but the silent truncation surprise remains. Use `u8::try_from(x).expect("range")` or `x.try_into()` when the value must round-trip.

**`mem::transmute<T, U>`** rewrites bytes between types of equal size. Requires `size_of::<T>() == size_of::<U>()` *and* — the part most reviewers miss — that every bit pattern producible by `T` is also valid for `U`. `transmute::<u8, bool>(2)` compiles and runs but is immediate UB. Use `MaybeUninit` if you genuinely need to store invalid bytes.

**`slice::from_raw_parts`** requires not just a non-null aligned pointer and a length, but valid provenance over the *entire* `len * size_of::<T>()` range, no aliasing `&mut` slices to the same memory, and that the slice fits in `isize::MAX` bytes.

```rust
// BAD: len comes from an external source; the range may exceed the allocation.
let s = unsafe { slice::from_raw_parts(ptr, external_len) };

// BAD: produces an invalid bool.
let b: bool = unsafe { mem::transmute(byte) };

// GOOD: validate first.
let b = byte != 0;
let s = unsafe { slice::from_raw_parts(ptr, len_validated_against_alloc) };
```

See [types-layout.md](types-layout.md) for `repr(C)` and `repr(transparent)` rules that make `transmute` defensible.

- `[FILE:LINE] AS_CAST_NARROWING_NO_TRY_FROM` — `x as u8` (or any narrowing `as` cast) on a value where overflow is possible. Use `u8::try_from(x)` if the range matters.
- `[FILE:LINE] TRANSMUTE_VIOLATES_VALIDITY` — `mem::transmute::<U, T>` where source `U` can produce bit patterns invalid for `T` (`u8`→`bool`, `u32`→`char`, `usize`→`NonNull<T>`, any int→enum). Use a checked constructor.
- `[FILE:LINE] TRANSMUTE_REPR_RUST_LAYOUT` — `mem::transmute` between two types neither marked `#[repr(C)]`, `#[repr(transparent)]`, nor a primitive. `repr(Rust)` layout is not guaranteed across types, fields, or even compilations.
- `[FILE:LINE] FROM_RAW_PARTS_UNVERIFIED_LEN` — `slice::from_raw_parts(ptr, len)` where `len` is not provably bounded by the originating allocation's size. The slice must lie entirely within one allocation.
