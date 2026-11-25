# Coding Idioms

## `OnceLock` / `LazyLock` / `LazyCell` Migration (Rust 1.80+)

Replace `lazy_static!` and `once_cell` with standard library primitives (`LazyLock` / `LazyCell` stable since Rust 1.80; `OnceLock` / `OnceCell` since 1.70):

```rust
// BAD -- third-party dependency no longer needed
lazy_static::lazy_static! {
    static ref CONFIG: Config = load_config();
}
static REGEX: once_cell::sync::Lazy<Regex> = once_cell::sync::Lazy::new(|| Regex::new(r"^\d+$").unwrap());

// GOOD -- standard library LazyLock / OnceLock
use std::sync::{LazyLock, OnceLock};

static CONFIG: LazyLock<Config> = LazyLock::new(|| load_config());
static RUNTIME_CFG: OnceLock<Config> = OnceLock::new();
fn get_config() -> &'static Config {
    RUNTIME_CFG.get_or_init(|| load_config_from_disk())
}
```

For single-threaded lazy initialization without atomic overhead, use `std::cell::LazyCell` / `std::cell::OnceCell`. Note: for fallible initialization on stable Rust, `OnceLock::get_or_try_init` is still nightly-only (`#109737`), so either cache `OnceLock<Result<T, E>>` via `get_or_init` or use `tokio::sync::OnceCell::get_or_try_init` in async code.

## Edition 2024 Awareness

### Reserved Keyword: `gen`

Rust 2024 reserves `gen` as a keyword (for future generator support). Code using `gen` as an identifier must use the raw identifier escape or rename:

```rust
// BAD (edition 2024) -- gen is a reserved keyword
let gen = 42;
fn gen() {}

// GOOD -- raw identifier or rename (prefer renaming for clarity)
let r#gen = 42;
let generation = 42;
```

### Never Type Fallback

In edition 2024, the `!` (never) type falls back to `!` instead of `()`. This affects diverging expressions in type inference:

```rust
let value = if condition {
    42
} else {
    panic!("unreachable")
    // In 2021: unconstrained fallback inferred ()
    // In 2024: unconstrained fallback infers ! (never type)
};
```

Watch for cases where diverging branches interact with trait resolution or generic fallback (e.g., `never_type_fallback_flowing_into_unsafe`).

### `if let` Temporary Scope

In edition 2024, temporaries in an `if let` scrutinee **still live through the entire `then` block**, and are dropped **before entering the `else` branch** (instead of at the end of the entire `if let ... else ...` expression, as in edition 2021).

- **Inside `then`:** Any `MutexGuard` or borrow in the scrutinee is **still held** throughout the `then` body (even if `.cloned()` is called inline). Extract the value in a `let` statement before `if let` when you need the lock/borrow released before the `then` body runs (e.g., before `.await` or re-locking).
- **Inside `else`:** The scrutinee temporary is already dropped before `else` begins (fixing edition 2021 deadlocks when locking in `else`), so bind `let guard = ...;` before `if let` if you explicitly need the temporary alive in `else`.

```rust
// Inside `then`, guard is STILL held in both 2021 and 2024;
// inside `else`, edition 2024 drops the guard before entering `else`
if let Some(val) = get_mutex().lock().unwrap().get("key") {
    use_val(val); // MutexGuard is STILL held here in edition 2024
} else {
    // MutexGuard already dropped before `else` in 2024 (was still locked in 2021)
}

// GOOD -- extract before `if let` to drop the guard before the `then` body runs
let val = get_mutex().lock().unwrap().get("key").cloned();
if let Some(val) = val {
    do_work_unlocked(val); // guard already dropped at `;`
}

// GOOD -- bind explicitly if you need the guard alive across both `then` and `else`
let guard = get_mutex().lock().unwrap();
if let Some(val) = guard.get("key") {
    use_val(val);
} else {
    // guard still alive in `else`
}
```

## Import Ordering

Standard order: `std` -> external crates -> workspace crates -> `super::`/`crate::`

```toml
# rustfmt.toml (note: imports_granularity and group_imports require nightly rustfmt)
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

## Drop Guards

RAII bound to a scoped local lets you restore state, release a flag, or run cleanup at scope exit, including on panic. The pattern is a small struct that implements `Drop`; the side effect lives in the destructor.

```rust
fn with_flag(flag: &AtomicBool, f: impl FnOnce()) {
    flag.store(true, Ordering::Release);
    struct Guard<'a>(&'a AtomicBool);
    impl Drop for Guard<'_> {
        fn drop(&mut self) { self.0.store(false, Ordering::Release); }
    }
    let _guard = Guard(flag); // bound to a name; lives until scope ends
    f();
}
```

The bug that catches everyone: `let _ = Guard(flag)` is NOT the same as `let _guard = Guard(flag)`. The bare `_` pattern is a wildcard, not a binding — the temporary is dropped immediately at the `;`, before `f()` runs. A leading-underscore name (`_guard`) is a real binding and extends the lifetime to the end of the enclosing block.

```rust
let _ = Guard(flag);      // BAD: Drop runs here, before f()
f();
let _guard = Guard(flag); // GOOD: Drop runs at end of scope
f();
```

State-restore variants use `mem::replace` (or `mem::take`) to snapshot the prior value into the guard, then restore on drop:

```rust
let prev = mem::replace(&mut *cell, new_value);
struct Restore<'a, T>(&'a mut T, Option<T>);
impl<T> Drop for Restore<'_, T> {
    fn drop(&mut self) { *self.0 = self.1.take().unwrap(); }
}
let _g = Restore(&mut *cell, Some(prev));
```

For ad-hoc cleanup, the `scopeguard` crate's `defer!` macro packages the same pattern as a one-liner. Caveat: `panic = "abort"` skips destructors entirely *and* there is no unwind for `std::panic::catch_unwind` to intercept — the process terminates immediately. Under `abort`, neither drop guards nor `catch_unwind` will run cleanup. Crates that ship as `cdylib` / `staticlib` cannot dictate the consumer's panic strategy and should document this hazard explicitly.

## Extension Traits

The orphan rule forbids `impl ForeignTrait for ForeignType`. The workaround is to define a new trait in your crate and blanket-impl it for the bound you want to extend:

```rust
pub trait MyExt {
    fn my_method(&self) -> usize;
}
impl<T: AsRef<str>> MyExt for T {
    fn my_method(&self) -> usize { self.as_ref().len() }
}
```

Real examples: `itertools::Itertools` extends `Iterator`, `futures::TryStreamExt` extends `TryStream`, `tower::ServiceExt` extends `Service`. Splitting "core trait" from "ergonomic helpers" lets the helper trait evolve without forcing major bumps of the core.

When to reach for an extension trait: the type is foreign, the trait you'd want to impl is also foreign, and you want method-call syntax (`x.my_method()`) rather than a free function (`my_method(x)`). When NOT to reach for one: when you own the type — just write `impl Type` directly, no trait import required at every call site.

Pitfalls:

- Method names that shadow popular inherent methods (`len`, `iter`, `clone`, `into`) on the implementing type cause call-site ambiguity that's hard to diagnose.
- Add `#[doc(alias = "base_method")]` to make the extension method discoverable when users search for the base trait's name.
- If the trait is meant to be call-site-only and not implemented by downstream crates, seal it (`pub trait Ext: sealed::Sealed`); otherwise adding a method becomes a breaking change.

## Index Pointers

Storing data once in a `Vec` / `Slab` / arena and threading `usize` (or `u32`) indices through derived structures side-steps the borrow checker without `unsafe`. Real-world examples: `petgraph` stores nodes and edges as parallel `Vec`s with `u32` endpoint indices; `indexmap` keeps keys in a `Vec` and stores positions in its hashmap; ECS world-state crates do the same. Cycles in the data are now expressible without `Rc`/`Arc` and refcount overhead.

```rust
use slotmap::{DefaultKey, SlotMap};

struct Graph {
    nodes: SlotMap<DefaultKey, Node>,
    edges: Vec<(DefaultKey, DefaultKey)>, // generational keys
}

impl Graph {
    fn add_node(&mut self, n: Node) -> DefaultKey { self.nodes.insert(n) }
    fn neighbors(&self, k: DefaultKey) -> impl Iterator<Item = DefaultKey> + '_ {
        self.edges.iter().filter_map(move |&(a, b)| {
            if a == k { Some(b) } else if b == k { Some(a) } else { None }
        })
    }
}
```

Trade-offs:

- Lookup is O(1) but cache-cold compared to direct `&T` dereferences. Index pointers are not free.
- No compile-time check that the index is valid. A stale `usize` panics at lookup time, or silently returns the wrong entry if the slot was reused.
- `Vec::swap_remove(i)` invalidates the index `len-1` (it moves into slot `i`). Any derived structure still holding that old index is now wrong. Either fix up every derived structure after the swap, or use `Vec::remove` and accept O(n).
- Mixing indices from different containers (a `Vec<Node>` index used to look up in a `Vec<Edge>`) is undetectable at the type level. Newtype each: `struct NodeIdx(u32);`, `struct EdgeIdx(u32);`.
- For containers that delete and reuse slots, use **generational indices**: `slotmap::DefaultKey` and `petgraph::graph::NodeIndex` carry a generation that invalidates stale references at lookup time.

## Crate Preludes

Curate a `pub mod prelude` that re-exports the items used in 80% of call sites, so users can write `use somecrate::prelude::*;` once at the top of a file. Preludes pair especially well with extension traits, whose methods are invisible-until-imported — `diesel`'s prelude is what makes `posts.filter(...).limit(5).load(&conn)` compile without naming every helper trait.

```rust
pub mod prelude {
    pub use crate::{Pool, Connection, Query};
    pub use crate::traits::{Executor, Queryable, Loadable};
    pub use crate::Result; // crate-specific Result alias
}
```

What belongs in a prelude:

- Core traits users almost always need (extension traits, the crate's error trait).
- A `Result` type alias if you have one.
- Most-used types (connection handles, builders, the primary entry-point struct).

What does NOT belong:

- Internal types that escaped `pub` and shouldn't have.
- Items that shadow the std prelude without a clear reason (`Result`, `Option`, `Box`, `Iterator`). `anyhow::Result` shadows deliberately; most don't.
- Deprecated items — glob users get warnings they didn't opt into.

SemVer note: per RFC 1105, *adding* a trait to a published prelude is a minor breaking change because method-resolution ambiguity can break user code at the call site. Reserve prelude additions for major versions when feasible.

## Review-Side Companion

For the reviewer-facing checklist of these patterns — `[FILE:LINE]` checks for `let _ = guard` typos, `swap_remove` aliasing, extension-trait overuse, prelude bloat, and related SemVer hazards — see [patterns-in-the-wild.md](../../rust-code-review/references/patterns-in-the-wild.md) in the `rust-code-review` skill.
