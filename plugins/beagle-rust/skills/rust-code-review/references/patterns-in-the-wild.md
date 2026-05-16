# Patterns in the Wild

Patterns Jon Gjengset highlights in mature Rust crates (Ch 13, *Rust for Rustaceans*). Reviewers should recognize these patterns when they appear correctly and flag misuse — especially typos that silently disable them (`let _ = guard`), index-pointer aliasing after `swap_remove`, extension traits used where direct `impl` would work, and prelude bloat that becomes a SemVer hazard. For dev-side authoring guidance see [../../rust-best-practices/references/coding-idioms.md](../../rust-best-practices/references/coding-idioms.md) and [../../rust-best-practices/references/ecosystem-patterns.md](../../rust-best-practices/references/ecosystem-patterns.md).

## Index Pointers

Storing data once in a `Vec` / `Slab` / arena and threading `usize` (or `u32`) indices through derived structures side-steps the borrow checker without `unsafe`. Real examples: `petgraph` (nodes and edges as `Vec`s, edges store endpoint indices as `u32`), `indexmap` (keys live in a `Vec`, the hashmap stores positions into it), ECS world-state crates. Cycles in the data are now expressible without `Rc`/`Arc` and refcount overhead. The cost is paid in lookup indirection and in the loss of compiler-enforced index validity.

```rust
struct Graph {
    nodes: Vec<Node>,
    edges: Vec<(u32, u32)>, // endpoint indices, not &Node
}

impl Graph {
    fn neighbors(&self, n: u32) -> impl Iterator<Item = u32> + '_ {
        self.edges.iter().filter_map(move |&(a, b)| {
            if a == n { Some(b) } else if b == n { Some(a) } else { None }
        })
    }
}
```

Hazards:

- `Vec::swap_remove(idx)` moves the *last* element into position `idx` for O(1) removal. Any derived structure still holding the swapped element's old index now silently points at the wrong entry.
- No type-level distinction between live and freed slots. A bare `u32` is no safer than a raw pointer once entries can be reused. Reach for `slotmap::DefaultKey` or a hand-rolled generational `(idx, gen)` pair.
- Random access is O(1) but cache-cold compared to `&T` direct dereferences. Index pointers are not free.
- Mixing indices from different containers (a `Vec<Node>` index used to look up in a `Vec<Edge>`) is undetectable at the type level. Newtype the index per container: `struct NodeIdx(u32);`.

Review checks:

- `[FILE:LINE] PIW_INDEX_AFTER_SWAP_REMOVE` — `Vec::swap_remove(idx)` called while other structures hold the swapped element's old index. Use `Vec::remove` for order-preserving deletion, or fix up every derived structure after the swap.
- `[FILE:LINE] PIW_BARE_USIZE_INSTEAD_OF_GENERATIONAL` — long-lived `usize` index into a container that supports deletion-then-reuse, with no generation counter. Use `slotmap` or an explicit `(idx, generation)` pair so stale indices are detectable.
- `[FILE:LINE] PIW_INDEX_TYPE_CONFUSION` — bare `u32` / `usize` indices from two different containers stored in the same struct or passed through the same function. Newtype each: `NodeIdx`, `EdgeIdx`.
- `[FILE:LINE] PIW_RC_USED_WHERE_INDEX_FITS` — `Rc<Node>` / `Arc<Node>` for tree or graph structures that don't actually need shared ownership beyond the container. Index pointers eliminate the refcount and permit cycles.
- `[FILE:LINE] PIW_INDEX_OUT_OF_BOUNDS_PANIC` — direct `self.nodes[idx]` indexing in code that processes externally supplied or persisted indices, with no `get(idx)` fallback. A stale index panics on lookup.
- `[FILE:LINE] PIW_INDEX_LEAK_AFTER_DELETION` — entries removed from the backing `Vec` via `Vec::remove` (which shifts subsequent indices down by one) without updating every derived structure. All higher indices in those structures now point one slot too far. Prefer `swap_remove` with explicit fix-up, or tombstone the slot with `Option<T>` and reuse it later.
- `[FILE:LINE] PIW_ARENA_NEVER_RECLAIMED` — arena-style `Vec<T>` grows monotonically; entries are never reclaimed. Long-lived processes leak. Add tombstoning, a free list, or migrate to `slotmap`.

## Drop Guards

RAII for scoped state changes: toggle a flag, restore a value, or run cleanup at scope exit *including on panic*. The cleanup goes in `Drop`; the guard is bound to a local; when the scope unwinds, `drop` runs. Tokio uses this for the executor handle during `Future::poll` so the handle is cleared even if `poll` panics. `scopeguard::defer!` packages the pattern for ad-hoc use.

```rust
fn with_flag(flag: &AtomicBool, f: impl FnOnce()) {
    flag.store(true, Ordering::Release);
    struct Guard<'a>(&'a AtomicBool);
    impl Drop for Guard<'_> {
        fn drop(&mut self) { self.0.store(false, Ordering::Release); }
    }
    let _guard = Guard(flag);
    f();
} // _guard drops here, even on panic
```

The single most common bug: `let _ = Guard(flag)` instead of `let _guard = Guard(flag)`. The bare `_` pattern is *not* a binding — it drops the value immediately at the `;`, before the protected code runs. Reviewers miss this because the two lines look identical at a glance.

State-restore variant uses `mem::replace` / `mem::take` to capture the prior value:

```rust
struct Restore<'a, T>(&'a mut T, Option<T>);
impl<T> Drop for Restore<'_, T> {
    fn drop(&mut self) { *self.0 = self.1.take().unwrap(); }
}
let prev = mem::replace(&mut *cell, new_value);
let _g = Restore(&mut *cell, Some(prev));
```

Caveat: `panic = "abort"` skips destructors entirely. Crates that ship as `cdylib` / `staticlib` (or whose users build with `abort`) cannot rely on drop guards for panic safety. The protected code must instead avoid panicking, or wrap the whole region in `std::panic::catch_unwind`.

Review checks:

- `[FILE:LINE] PIW_DROP_GUARD_DROPPED_IMMEDIATELY` — `let _ = SomeGuard(...)` instead of `let _guard = ...`. The guard's `Drop` fires at the semicolon, before the protected code. Rename to `_guard` or any non-`_` binding.
- `[FILE:LINE] PIW_MISSING_DROP_GUARD_AROUND_FALLIBLE` — code mutates shared state (atomic flag, refcell, thread-local) then runs a fallible / panicking operation, with cleanup placed inline after the call. On panic the state stays mutated. Move cleanup into a `Drop` impl.
- `[FILE:LINE] PIW_DROP_GUARD_RELIES_ON_UNWIND` — drop-guard pattern in a crate whose `Cargo.toml` sets `panic = "abort"`, or in a lib target documented for abort-mode users, with no `catch_unwind` fallback. Destructors don't run on abort.
- `[FILE:LINE] PIW_STATE_RESTORE_FORGOT_REPLACE` — restore-on-drop guard captures `&mut T` but never snapshots the prior value via `mem::replace` / `mem::take`. The `Drop` impl has nothing to restore. See [concurrency-primitives.md](concurrency-primitives.md) for related shared-state hazards.
- `[FILE:LINE] PIW_DROP_GUARD_PANIC_IN_DROP` — `Drop` impl on a guard that itself can panic (e.g. `unwrap` on a lock acquisition during drop). A panic during unwind aborts the process.
- `[FILE:LINE] PIW_DROP_GUARD_USES_PLAIN_REF` — guard captures `&T` where the cleanup requires exclusive access. Tightening to `&mut T` (or `&AtomicX` for atomics) lets the borrow checker prove no concurrent reads see the half-cleaned state.
- `[FILE:LINE] PIW_MEM_FORGET_DISABLES_GUARD` — `mem::forget(guard)` or `ManuallyDrop::new(guard)` in code paths that should always run cleanup. Either is a deliberate disable; flag for justification.

## Extension Traits

The orphan rule forbids `impl ForeignTrait for ForeignType`. The workaround: define a new trait in your crate, give it provided methods, and blanket-impl it for the relevant bound. Real examples include `itertools::Itertools` (extends `Iterator`), `futures::TryStreamExt` (extends `TryStream`), and `tower::ServiceExt` (extends `tower::Service`). Splitting "core trait" from "ergonomic helpers" also lets the helper trait evolve without forcing major bumps of the core. See [interface-design.md](interface-design.md) for adjacent trait-design checks.

```rust
pub trait IteratorExt: Iterator {
    fn chunk_by_key<K, F>(self, f: F) -> ChunkBy<Self, F>
    where
        Self: Sized,
        F: FnMut(&Self::Item) -> K,
        K: PartialEq,
    { ChunkBy { iter: self, key: f } }
}
impl<I: Iterator> IteratorExt for I {}
```

When NOT to reach for an extension trait:

- You own the type. Just write `impl Type` directly — no trait needed.
- The extension method's name shadows a popular inherent method (`len`, `iter`, `clone`) on a common type. Users hit method-resolution ambiguity errors that are hard to diagnose.
- The trait carries associated types or non-`Sized` bounds you haven't thought through. Missing `+ ?Sized` on `T` excludes `str` / `[T]` / `dyn Trait` from the blanket impl.

Review checks:

- `[FILE:LINE] PIW_EXTENSION_TRAIT_OVER_INHERENT_IMPL` — extension trait defined for a type the crate owns. Replace with a direct `impl Type` block; the trait adds no orphan-rule benefit and costs an import at every call site.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_SHADOWS_INHERENT` — extension method has the same name as a popular inherent method on the implementing type (e.g. `len`, `iter`, `into`). Rename to avoid ambiguity, or qualify use sites with `Trait::method(value)`.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_FREE_FN_FALLBACK` — author wanted to add a method to a foreign type but wrote a free function instead. Extension trait + blanket impl gives method-call ergonomics without violating the orphan rule.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_MISSING_SIZED_BOUND` — blanket impl `impl<T: Foo> Ext for T {}` excludes `str`, `[T]`, and `dyn Foo`. Add `+ ?Sized` if the trait methods don't require it.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_NO_DOC_ALIAS` — public extension trait that augments a well-known trait with no `#[doc(alias)]` linking back to the base. Users searching docs for `Service` won't find `ServiceExt`.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_PUB_BUT_UNSEALED` — public extension trait that downstream crates can `impl` for their own types, without a sealed-trait pattern (`pub trait Ext: sealed::Sealed`). Adding a new method becomes a breaking change. Seal it if the trait is meant to be call-site-only.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_NOT_OBJECT_SAFE_BY_ACCIDENT` — extension trait used as a generic bound but never as `dyn Ext`; check that `Self: Sized` bounds on methods are present where needed and absent where not, so downstream users can decide.

## Crate Preludes

A `pub mod prelude { pub use crate::{A, B, C}; }` module lets users write `use somecrate::prelude::*;` once at the top of a file. This pairs especially well with extension traits, whose methods are invisible-until-imported — `diesel`'s prelude is what makes `posts.filter(...).limit(5).load(&conn)` compile. Glob imports have *lower* precedence than named imports, so adding a non-trait name to a prelude is generally non-breaking. *Adding a new trait* to a prelude is different: per RFC 1105 it's a minor breaking change because method-resolution ambiguity can break user code at the call site.

```rust
pub mod prelude {
    pub use crate::{Pool, Connection, Query};
    pub use crate::traits::{Executor, Queryable, Loadable};
}
```

Reviewer notes:

- Preludes should re-export only the *common core* — types and traits used in 80% of call sites. Re-exporting everything turns `prelude::*` into a worse `crate::*`.
- Watch for collisions with the standard prelude: re-exporting your own `Result` / `Option` / `Error` / `Iterator` shadows std's via the named-import precedence rule. Sometimes that's intentional (`anyhow::Result`); when it isn't, it's a footgun.
- Tokio's and Diesel's preludes are the gold standard: small, mostly traits, stable across minor versions.

Review checks:

- `[FILE:LINE] PIW_PRELUDE_BLOAT` — `prelude` module re-exporting most of the crate's public items, including ones used in a minority of call sites. Pare back to the common core; users can still name the rest.
- `[FILE:LINE] PIW_PRELUDE_ADDED_TRAIT_AS_MINOR_BUMP` — published minor release adds a new trait to `prelude`, where the trait's methods could create ambiguity with existing inherent methods on common types. RFC 1105 permits this; flag as SemVer hazard and consider a major bump.
- `[FILE:LINE] PIW_PRELUDE_SHADOWS_STD` — prelude re-exports `Result` / `Option` / `Error` / `Iterator` with the crate's own definitions without a doc comment explaining the shadow. Users will hit confusing errors when they expect std semantics.
- `[FILE:LINE] PIW_GLOB_IMPORT_OUTSIDE_PRELUDE` — `use somecrate::*;` at a call site rather than `use somecrate::prelude::*;` or named imports. Pulls in more than the crate's curated surface; harder to review.
- `[FILE:LINE] PIW_PRELUDE_INCLUDES_DEPRECATED` — prelude re-exports items marked `#[deprecated]`. Glob users get deprecation warnings they didn't opt into. Remove from prelude before the deprecation cycle ends.

## Closing Review Checklist

Index pointers:

- `[FILE:LINE] PIW_INDEX_AFTER_SWAP_REMOVE` — see Index Pointers section.
- `[FILE:LINE] PIW_BARE_USIZE_INSTEAD_OF_GENERATIONAL` — long-lived indices into reusable slots without a generation counter.
- `[FILE:LINE] PIW_INDEX_TYPE_CONFUSION` — bare numeric indices from different containers in the same scope; newtype them.
- `[FILE:LINE] PIW_RC_USED_WHERE_INDEX_FITS` — refcount-based graph/tree where index pointers would work.
- `[FILE:LINE] PIW_INDEX_OUT_OF_BOUNDS_PANIC` — externally supplied indices used with `[]` instead of `get`.
- `[FILE:LINE] PIW_INDEX_LEAK_AFTER_DELETION` — `Vec::remove` shifts indices; derived structures break silently.
- `[FILE:LINE] PIW_ARENA_NEVER_RECLAIMED` — monotonically growing arena with no tombstoning or free list.

Drop guards:

- `[FILE:LINE] PIW_DROP_GUARD_DROPPED_IMMEDIATELY` — `let _ = Guard(...)` typo disables the guard.
- `[FILE:LINE] PIW_MISSING_DROP_GUARD_AROUND_FALLIBLE` — cleanup inline after a panicking call instead of in `Drop`.
- `[FILE:LINE] PIW_DROP_GUARD_RELIES_ON_UNWIND` — drop guards under `panic = "abort"` are no-ops.
- `[FILE:LINE] PIW_STATE_RESTORE_FORGOT_REPLACE` — restore-guard with no snapshot taken via `mem::replace` / `mem::take`.
- `[FILE:LINE] PIW_DROP_GUARD_PANIC_IN_DROP` — `Drop` impl that itself can panic during unwind.
- `[FILE:LINE] PIW_DROP_GUARD_USES_PLAIN_REF` — guard captures `&T` where `&mut T` would let the compiler prove exclusivity.
- `[FILE:LINE] PIW_MEM_FORGET_DISABLES_GUARD` — `mem::forget` or `ManuallyDrop` deliberately skipping the guard's `Drop`.

Extension traits:

- `[FILE:LINE] PIW_EXTENSION_TRAIT_OVER_INHERENT_IMPL` — extension trait for a locally owned type.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_SHADOWS_INHERENT` — method name collides with a popular inherent method.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_FREE_FN_FALLBACK` — free function where an extension trait would give method ergonomics.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_MISSING_SIZED_BOUND` — blanket impl excludes unsized types; add `+ ?Sized`.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_NO_DOC_ALIAS` — public extension trait with no `#[doc(alias)]` to the base trait.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_PUB_BUT_UNSEALED` — public extension trait that downstream crates can `impl`, with no sealed pattern; new methods are breaking.
- `[FILE:LINE] PIW_EXTENSION_TRAIT_NOT_OBJECT_SAFE_BY_ACCIDENT` — `Self: Sized` bounds on methods chosen by accident, blocking or permitting `dyn Ext` by surprise.

Preludes:

- `[FILE:LINE] PIW_PRELUDE_BLOAT` — re-exporting too much; pare to the common core.
- `[FILE:LINE] PIW_PRELUDE_ADDED_TRAIT_AS_MINOR_BUMP` — new prelude trait in a minor release is a SemVer hazard.
- `[FILE:LINE] PIW_PRELUDE_SHADOWS_STD` — prelude re-exports `Result` / `Option` / `Error` without flagging the shadow.
- `[FILE:LINE] PIW_GLOB_IMPORT_OUTSIDE_PRELUDE` — `use crate::*` at a call site instead of `prelude::*` or named imports.
- `[FILE:LINE] PIW_PRELUDE_INCLUDES_DEPRECATED` — deprecated items re-exported through `prelude`.

## Anti-patterns

- `let _ = DropGuard(...)` — drops at the semicolon, silently disabling the guard.
- Holding a `Vec<T>` index across a `Vec::swap_remove` that might displace it.
- Modeling graphs or trees with `Rc<Node>` / `Arc<Node>` cycles when index pointers fit and would also permit cycles.
- Reusing slots in a `Vec` / `Slab` without generational keys, so stale indices alias new entries.
- Mixing `usize` indices from different containers in the same struct without newtypes.
- Defining an extension trait for a type the crate owns instead of a direct `impl` block.
- Extension-trait method names that shadow `len`, `iter`, `clone`, `into` on the implementing type.
- Blanket-impl extension traits that omit `+ ?Sized` and silently exclude `str` / `[T]` / `dyn Trait`.
- Re-exporting an entire crate's public surface from `prelude` ("kitchen-sink prelude").
- Adding a new trait to a published `prelude` in a minor release without considering ambiguity breakage.
- Glob-importing a non-`prelude` module from a third-party crate.
- Relying on drop guards for panic safety in a crate built with `panic = "abort"`.
