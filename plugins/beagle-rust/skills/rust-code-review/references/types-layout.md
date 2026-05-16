# Types and Layout

## Type Layout in Memory

### Alignment and Padding

Every type has an alignment determined by its largest field. Fields may require padding to satisfy alignment constraints.

```rust
#[repr(C)]
struct Foo {
    tiny: bool,   // 1 byte + 3 bytes padding
    normal: u32,  // 4 bytes (4-byte aligned)
    small: u8,    // 1 byte + 7 bytes padding
    long: u64,    // 8 bytes (8-byte aligned)
    short: u16,   // 2 bytes + 6 bytes padding (struct alignment)
}
// repr(C) total: 32 bytes
// repr(Rust) can reorder fields: 16 bytes (no padding needed)
```

**Check for**: `#[repr(C)]` types with suboptimal field ordering — padding can significantly inflate size. With default `repr(Rust)`, the compiler reorders fields for you.

### `repr` Variants

| Repr | Guarantees | Use Case |
|------|-----------|----------|
| `repr(Rust)` (default) | No layout guarantees, compiler optimizes freely | Internal types |
| `repr(C)` | Predictable C-compatible layout, field order preserved | FFI, raw pointer casts between types |
| `repr(transparent)` | Outer type has identical layout to its single field | Newtypes used in FFI or pointer casts |
| `repr(packed)` | No padding, may cause misaligned access | Size-critical data, network protocols |
| `repr(align(N))` | Minimum alignment of N bytes | Cache line isolation, SIMD |

**Flag when**:
- FFI types lack `#[repr(C)]` — default Rust layout is not stable across compiler versions
- Pointer casts between types assume identical layout without `repr(C)` or `repr(transparent)`
- `repr(packed)` used without awareness of performance cost from misaligned access
- Types used in concurrent shared arrays lack `repr(align(64))` for cache-line padding when false sharing is a concern

## PhantomData Usage Patterns

`PhantomData<T>` is a zero-sized type that tells the compiler "this type logically owns/references a `T`."

### When Required

- **Drop check**: if your type owns a `T` behind a raw pointer, add `PhantomData<T>` so the drop check knows you'll drop `T`
- **Lifetime association**: `PhantomData<&'a T>` ties a lifetime to a type that holds `*const T`
- **Variance control**: `PhantomData<fn(T)>` makes a type contravariant in `T`; `PhantomData<*mut T>` makes it invariant

```rust
struct Iter<'a, T> {
    ptr: *const T,
    end: *const T,
    _marker: PhantomData<&'a T>, // ties lifetime 'a to this type
}
```

### When Over-Used

**Flag when**: `PhantomData` appears in types that already hold a real `T` — it's redundant and adds confusion. Only needed when the `T` is behind a raw pointer or absent from fields.

## Zero-Sized Types (ZST)

ZSTs occupy no memory and are optimized away at compile time. Common uses:

- **Marker types**: `struct Authenticated;` for type-state patterns
- **PhantomData**: compile-time lifetime and variance markers
- **Empty iterators**: `std::iter::Empty<T>` is zero-sized
- **Map keys as sets**: `HashMap<K, ()>` (though `HashSet` is preferred)

**Check for**: allocation of ZSTs is valid but produces a dangling pointer — `Box<()>` doesn't allocate. This is correct behavior, not a bug.

**Valid pattern**: ZSTs as generic parameters for compile-time state machines (type-state pattern). No runtime cost.

## Trait Objects vs Generics

### Static Dispatch (Generics / `impl Trait`)

- Monomorphized: compiler generates a copy per concrete type
- Zero overhead: calls are direct, inlinable
- **Cost**: increased compile time and binary size from monomorphization

### Dynamic Dispatch (`dyn Trait`)

- Single copy of code, vtable indirection per method call
- Enables heterogeneous collections (`Vec<Box<dyn Trait>>`)
- **Cost**: vtable lookup per call, prevents inlining, requires allocation behind a pointer

### Decision Checklist

| Criterion | Use Generics | Use `dyn Trait` |
|-----------|-------------|-----------------|
| Library API | Prefer (caller chooses) | Only if object safety needed |
| Binary code | Either works | Prefer (smaller binary, faster compile) |
| Hot path | Prefer (zero-cost inlining) | Avoid (vtable overhead) |
| Heterogeneous collection | Not possible | Required |
| Compile time concern | May be slow | Faster |

**Flag when**: `dyn Trait` used on a hot path where a generic would allow inlining, or generics used with dozens of instantiations causing compile-time bloat in a binary crate.

## Monomorphization Code Bloat

**Check for**: generic functions with large bodies instantiated for many types. The compiler copies the entire function body per type.

Mitigation patterns:
- **Non-generic inner functions**: extract type-independent logic into a non-generic helper

```rust
fn process<T: Hash>(items: &[T]) {
    // Type-dependent: hashing
    let hashes: Vec<u64> = items.iter().map(|i| hash(i)).collect();
    // Type-independent: extracted to share machine code
    process_hashes(&hashes);
}

fn process_hashes(hashes: &[u64]) {
    // This code is compiled once, not per T
}
```

- **`dyn Trait` for binary internals**: when the binary doesn't need peak per-call performance, dynamic dispatch reduces code size
- **Bounded generics in libraries**: use `impl Trait` in argument position for flexibility while keeping the generic surface small

## Dynamically Sized Types

`dyn Trait` and `[T]` are `!Sized` — they must live behind a wide pointer (`&`, `Box`, `Arc`).

**Flag when**:
- A type bound is missing `?Sized` when it should accept DSTs
- Code assumes `size_of::<dyn Trait>()` — this doesn't compile because the size is unknown
- A struct stores `dyn Trait` as a field without indirection (won't compile)

**Valid pattern**: `Box<dyn Error + Send + Sync + 'static>` for heterogeneous error handling in application code.

## Review Questions

1. Do FFI types use `#[repr(C)]` or `#[repr(transparent)]`?
2. Are pointer casts between types justified by matching repr guarantees?
3. Is `PhantomData` present where needed for drop check and variance, and absent where redundant?
4. Are generics causing code bloat that could be mitigated with inner functions or `dyn Trait`?
5. Is `repr(packed)` used with awareness of misaligned access costs?
6. Are cache-sensitive concurrent types aligned to cache line boundaries?

## Padding-Driven Size Bloat — Concrete Numbers

The `{ bool, u32, u8, u64, u16 }` struct from earlier becomes **32 bytes** under `#[repr(C)]` (fields in source order, padded for alignment) versus **16 bytes** with default `repr(Rust)` (compiler reorders by descending alignment). A 2x size difference. At scale — a `Vec` of one million such structs — that is 16 MB of avoidable memory plus extra cache pressure and slower iteration.

`repr(C)` is appropriate **only** when layout must be predictable: FFI structs crossing a `extern "C"` boundary, types serialized via raw byte copy, or types reinterpreted via pointer cast. For purely internal types, `repr(C)` is a mistake — it locks the compiler into a suboptimal layout for no benefit.

- [FILE:LINE] REPR_C_ON_INTERNAL_TYPE — `#[repr(C)]` on a type that never crosses FFI or serialization. Drop the attribute and let the compiler reorder.
- [FILE:LINE] REPR_C_FIELD_ORDER_BLOAT — FFI struct retains source-order fields with heavy padding. Reorder by descending alignment when the wire format permits.

## `repr(packed)` UB on References

`#[repr(packed)]` removes padding, so fields may sit at unaligned addresses. Taking a Rust reference `&packed.field` produces a reference whose address may not satisfy the field type's alignment requirement. Dereferencing a misaligned reference is **undefined behavior**, regardless of whether the current target happens to tolerate it.

```rust
#[repr(packed)]
struct Header { tag: u8, value: u32 }

let h = Header { tag: 1, value: 42 };
// let r = &h.value;                        // UB: potentially misaligned &u32
let v = unsafe { std::ptr::addr_of!(h.value).read_unaligned() };
```

`addr_of!` yields a raw pointer without forming a reference, and `read_unaligned` performs a byte-wise copy that does not require alignment.

- [FILE:LINE] PACKED_FIELD_REFERENCE_UB — `&packed.field` or `&mut packed.field` on a `repr(packed)` struct. Replace with `ptr::addr_of!` / `addr_of_mut!` plus `read_unaligned` / `write_unaligned`.

## `repr(align(N))` for Cache-Line Padding

False sharing: two CPUs writing to distinct values in the same cache line stall each other through coherence traffic. Aligning each value to its own cache line eliminates the conflict.

```rust
#[repr(align(64))]
struct PerThreadCounter(std::sync::atomic::AtomicUsize);

let counters: Vec<PerThreadCounter> = (0..num_cpus).map(|_| PerThreadCounter(0.into())).collect();
```

Cache-line size is **64 bytes** on most x86 and ARM, but **128 bytes** on Apple Silicon (M1+) and several server CPUs (e.g. some POWER, recent Intel with adjacent-line prefetch). Hard-coding 64 is portable-ish but under-pads on those platforms. Prefer `crossbeam_utils::CachePadded<T>` which queries the target at compile time and pads correctly.

- [FILE:LINE] FALSE_SHARING_NO_ALIGN — `Vec<AtomicUsize>` or per-thread struct array lacks `#[repr(align(64))]` (or `CachePadded`). Concurrent writes will serialize through cache coherence.
- [FILE:LINE] HARDCODED_64_ALIGN_ON_APPLE_SILICON — `#[repr(align(64))]` on a type that may run on M1+ where the line is 128 bytes. Prefer `crossbeam_utils::CachePadded`.

## Wide Pointer Layout — Exact Shape

A pointer to a DST is **two words**: `mem::size_of::<&dyn Trait>() == 2 * mem::size_of::<usize>()`. Same for `&[T]`, `Box<dyn Trait>`, `Arc<[T]>`, etc.

- **Slice** wide pointer: `(data_ptr, length)`.
- **Trait object** wide pointer: `(data_ptr, vtable_ptr)`. The vtable is a static table holding the value's **size**, **alignment**, the **drop glue** function pointer, and one entry per method.

Code that assumes `&dyn Trait` fits in a single `usize` (FFI shims, hand-rolled vtables, `transmute` to `*const c_void`) is broken — half the pointer disappears, leading to crashes on first virtual call.

- [FILE:LINE] WIDE_POINTER_ASSUMED_ONE_WORD — FFI or `transmute` treats `&dyn Trait` or `&[T]` as a single `usize`. Use `*const c_void` only for the data half; pass the vtable/length separately or keep the wide pointer intact.

## `Sized` vs `?Sized` Discipline

Every generic parameter implicitly carries `T: Sized`. Opt out with `T: ?Sized` **only** when the function accepts the DST through indirection (`&T`, `&mut T`, `Box<T>`, `Arc<T>`, `Pin<&mut T>`, etc.). A `?Sized` parameter cannot be taken by value, stored in a local, or returned by value — the compiler must know the size to lay out the stack frame.

```rust
fn print_debug<T: ?Sized + std::fmt::Debug>(x: &T) { println!("{x:?}"); }
// fn bad<T: ?Sized>(x: T) {}   // ERROR: T has no known size
```

- [FILE:LINE] SIZED_BOUND_PREVENTS_DST — generic helper takes `&T` but lacks `?Sized`, blocking callers from passing `&str` or `&dyn Trait`. Add `T: ?Sized`.
- [FILE:LINE] UNSIZED_TAKEN_BY_VALUE — `?Sized` parameter used by value or stored in a local. Move it behind indirection or drop `?Sized`.

## Auto-Trait Leakage Through `-> impl Trait`

Callers of `-> impl Trait` can only rely on the **listed** traits — but auto-traits (`Send`, `Sync`, `Unpin`, `RefUnwindSafe`) **do** propagate from the hidden concrete type. A function returning `-> impl Iterator<Item = u32>` whose body captures an `Rc<...>` silently loses `Send`. Callers that try to move the iterator into `tokio::spawn` or `thread::spawn` get a compile error pointing at the spawn site, not the iterator definition.

Lock the contract in any code that may cross thread boundaries:

```rust
fn rows() -> impl Iterator<Item = u32> + Send + 'static { (0..10) }
```

- [FILE:LINE] AUTO_TRAIT_LEAK_RC_IN_RPIT — `-> impl Trait` body uses `Rc`, `Cell`, `RefCell`, or `*const T`, silently dropping `Send`/`Sync`. Add explicit `+ Send + 'static` (or refactor to `Arc`).
- [FILE:LINE] ASYNC_RPIT_NO_SEND_BOUND — async fn or `-> impl Future` returned across threads lacks `+ Send`. See [concurrency-primitives.md](concurrency-primitives.md) for spawn requirements.

## Edition 2024 RPIT Capture Rule

In edition 2021 and earlier, `-> impl Trait` captured only lifetimes and generics that appeared in the listed bounds. In **edition 2024**, RPIT captures **all in-scope generics and lifetimes** by default. To opt out — or to capture explicitly — use `+ use<'a, T>` (or `+ use<>` for nothing):

```rust
fn first<'a, 'b>(xs: &'a [u32], _scratch: &'b mut Vec<u32>) -> impl Iterator<Item = &'a u32> + use<'a> {
    xs.iter()
}
```

Without `+ use<'a>`, edition 2024 would also capture `'b`, extending the borrow on `_scratch` until the iterator drops. See [lifetime-variance.md](lifetime-variance.md) for the lifetime-variance consequences.

- [FILE:LINE] EDITION_2024_RPIT_OVER_CAPTURE — multi-lifetime function with `-> impl Trait` and no `+ use<...>` on edition 2024. Callers will hit surprising borrow extensions; state captures explicitly.

## Derive-Bound Trap with `Arc`/`Rc`/`Box`

`#[derive(Clone)]` (and `Debug`, `Hash`, etc.) generates `impl<T: Clone> Clone for Foo<T>` mechanically, **even when `T` only appears behind `Arc<T>`, `Rc<T>`, or `Box<T>`** — all of which are `Clone` independent of `T`. The result: a `Shared<NotClone>` that logically should clone fine refuses to compile.

```rust
struct Shared<T> { inner: std::sync::Arc<T> }   // do NOT derive Clone here
impl<T> Clone for Shared<T> {
    fn clone(&self) -> Self { Self { inner: self.inner.clone() } }
}
```

- [FILE:LINE] DERIVE_CLONE_SPURIOUS_T_BOUND — `#[derive(Clone)]` on a generic type whose `T` only sits behind `Arc`/`Rc`/`Box`. Hand-write the impl without the `T: Clone` bound. Same trap applies to `Debug`, `Hash`, `PartialEq`, `Default`.

## Object Safety — Five-Rule Summary

A trait is **object-safe** (usable as `dyn Trait`) only if every method satisfies:

1. No generic type parameters on the method (`fn foo<U>(...)` disqualifies).
2. The `Self` type does not appear in **return** position (rules out `Clone::clone -> Self`).
3. The `Self` type does not appear in **argument** position by value (only behind `&`, `&mut`, `Box`, `Arc`, `Pin`, `Rc`).
4. No associated functions (methods without `&self` / `&mut self`) — rules out `Default::default`.
5. Methods violating 1–4 can be exempted with `where Self: Sized`, making them unavailable through trait objects.

Full mechanics, including manual vtable construction and supertrait interactions, live in [interface-design.md](interface-design.md). When choosing between generics and `dyn Trait`, run this five-rule check first.

- [FILE:LINE] DYN_INTENDED_TRAIT_NOT_OBJECT_SAFE — trait used as `dyn Trait` (or stored as `Box<dyn ...>`) violates one of the five rules. Add `where Self: Sized` to the offending method or restructure.
