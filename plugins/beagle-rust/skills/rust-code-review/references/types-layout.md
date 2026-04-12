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
