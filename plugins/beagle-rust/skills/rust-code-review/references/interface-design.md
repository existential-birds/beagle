# Interface Design

The four high-level principles — unsurprising, flexible, obvious, constrained — are summarized in [api-design.md](../../rust-best-practices/references/api-design.md) along with the builder pattern, sealed-trait introduction, `#[non_exhaustive]`, and generic SemVer rules. This file is reviewer-actionable depth: the exact mechanics that turn each principle into a finding, in the format `[FILE:LINE] ISSUE_TITLE — short description and the fix.` See also [types-layout.md](types-layout.md) for `Send`/`Sync`/`PhantomData` mechanics, and [error-handling.md](error-handling.md) for `Error` trait expectations referenced by destructor and fallibility checks.

## Object Safety Mechanics

A trait is object-safe (dyn-compatible) only if every method obeys all of:

1. **No `Self` by value.** `fn into_inner(self) -> Self::Output` cannot dispatch through `&dyn Trait` — the vtable has no size for `Self`. `Clone::clone(&self) -> Self` is the canonical violator.
2. **No generic methods.** Each instantiation needs its own vtable slot, so `fn extend<I: IntoIterator>(&mut self, iter: I)` is rejected. `Extend` is non-object-safe.
3. **No associated constants.** They have no receiver, so the vtable cannot dispatch to a specific impl.
4. **No `self`-less methods.** A method without `self`/`&self`/`&mut self`/`Box<Self>`/`Pin<&mut Self>` cannot be virtually dispatched. `FromIterator::from_iter` is non-object-safe for this reason.
5. **`Self: Sized` cannot be a supertrait** if you want `dyn Trait` to exist. `trait Foo: Sized` deliberately bans trait objects.

Escape hatch — `where Self: Sized` on an individual method exempts that method from object-safety checks but disables it for `dyn Trait` callers. `Iterator::collect`, `Read::bytes`, and `Iterator::sum` all use this trick.

```rust
trait Storage {
    fn get(&self, key: &str) -> Option<&[u8]>;
    fn collect_into<C: FromIterator<Vec<u8>>>(&self) -> C
    where
        Self: Sized;
}
```

`Drop` is the exception: it is object-safe by design so every vtable carries a drop slot — every `dyn Trait` is implicitly `dyn Drop`. **SemVer trap:** adding a method to a published trait that takes `Self` by value, returns `Self`, or is generic silently flips the trait to non-object-safe — a major-version break even with a default impl.

**Real-world examples to recognize on sight.** `Clone` is non-object-safe because `clone(&self) -> Self`. `Extend` is non-object-safe because `extend<T: IntoIterator>(&mut self, iter: T)` is generic. `FromIterator` is non-object-safe because `from_iter(iter)` has no `self`. `Iterator` itself *is* object-safe — its generic methods (`collect`, `sum`, `map`, etc.) all carry `where Self: Sized`. `std::io::Read` and `std::io::Seek` are individually object-safe so `Box<dyn Read + Seek>` works for the common "I have a reader that can also seek" case.

When a generic method on your trait is unavoidable, three options preserve object safety:

1. **Lift the generic to the trait** — `trait Foo<I> { fn extend(&mut self, iter: I); }`. Each `I` is a distinct trait; loses some flexibility.
2. **Use dynamic dispatch in the signature** — `fn extend(&mut self, iter: &mut dyn Iterator<Item = X>)`. Forces dynamic dispatch on every caller.
3. **`where Self: Sized` exemption** — disables the method through `dyn Trait` but keeps the trait object-safe overall.

## Ergonomic Trait Impls

Rust does not auto-implement traits for references. `fn run<T: Worker>(w: T)` rejects `&Worker` even when `Worker` is implemented for the pointee — the trait's `&mut self` or `self` methods cannot dispatch through `&T`. When you define a new trait whose receivers permit it, provide blanket forwarding impls:

```rust
impl<T: Worker + ?Sized> Worker for &T { /* &self only */ }
impl<T: Worker + ?Sized> Worker for &mut T { /* &self + &mut self */ }
impl<T: Worker + ?Sized> Worker for Box<T> { /* all receivers */ }
impl<T: Worker + ?Sized> Worker for Arc<T> { /* &self only */ }
```

Pick the impls that match your method receivers. `&T` forwards `&self`-only traits; `&mut T` adds `&mut self`; `Box<T>` and `Rc<T>`/`Arc<T>` can additionally forward methods on owned receivers via `*self`-style dispatch. Standard library trait hierarchies follow this pattern precisely — that is why generic code "just works" with smart pointers.

For iterable collections, implement `IntoIterator` for `&MyType` and `&mut MyType` (in addition to `MyType`) so `for x in &c` and `for x in &mut c` work, matching `Vec`, `HashMap`, and `BTreeMap`. Missing either is a real friction point users notice immediately.

## Wrapper Types and Deref Discipline

A **transparent wrapper** is one whose entire purpose is to add a small piece of behavior around an inner type: `Arc<T>`, `MutexGuard<'_, T>`, `Cow<'_, T>`. For these, provide:

- `Deref` (and `DerefMut` where applicable) so dot-method dispatch forwards
- `AsRef<Inner>` so `&Wrapper` can be passed where `&Inner` is accepted
- `From<Inner>` and a corresponding `Into<Inner>` for wrapping/unwrapping

An **opaque wrapper** intentionally hides the inner type. Do not implement `Deref` — users would expect cheap, transparent forwarding and you would surprise them.

**Deref must be cheap.** If accessing the target requires non-trivial work (allocation, locking, hashing), give it an explicit method instead. `Deref` is invoked implicitly through the dot operator; users will not suspect a `.field` access of doing real work.

**Deref-as-OOP anti-pattern.** When `T: Deref<Target = U>` and both `T` and `U` carry inherent methods, `t.foo()` is unambiguous to the compiler but ambiguous to the reader. `Vec::push` is safe because slices will not gain `push`; an inherent method on a wrapper around a *user-controlled* type may clash with one the user later adds. Mitigations: prefer static/associated functions (`Wrapper::foo(t)`) on the wrapper, or avoid inherent methods on the wrapper entirely.

**`Borrow` vs `AsRef` vs `Deref`.**

- `AsRef<T>` — "I can cheaply produce a `&T`." Many-to-many relationship; no semantic requirements beyond "reference conversion."
- `Borrow<T>` — `AsRef<T>` plus identical `Hash`, `Eq`, and `Ord` between wrapper and inner. That is why `HashSet<String>::get` accepts `&str` via `Borrow`. Wrong if your wrapper changes those semantics (e.g., case-insensitive string).
- `Deref<Target = T>` — implicit, dot-operator forwarding. Used for smart pointers and transparent wrappers.

Use `Borrow` for keyed lookup, `AsRef` for cheap conversion-style API arguments, `Deref` only for transparent pointer-shaped wrappers. A common review mistake: implementing `Borrow<str>` for a wrapper around `String` that normalizes the inner string before hashing — `Borrow` requires identical hash output between wrapper and inner; this is a latent bug that produces silent hash-map lookup misses.

The `Borrow` blanket impl exists for `T`, `&T`, and `&mut T`, which is why bounds like `K: Borrow<Q>` accept whichever form the caller has on hand. That is the mechanism behind `HashMap::get` accepting either `&String` or `&str` when keys are `String`. Do not use `Borrow` as a generic "can be referenced as" trait — that role is `AsRef`'s.

## Borrowed vs Owned in APIs

Three signatures, none strictly better — each shifts cost between caller and callee:

```rust
fn frobnicate1(s: String) -> String;
fn frobnicate2(s: &str) -> Cow<'_, str>;
fn frobnicate3(s: impl AsRef<str>) -> impl AsRef<str>;
```

The first demands an owned `String` (caller may have to allocate) and promises an owned `String` back. The second borrows but locks the return to `Cow` forever — moving away from `Cow` is a breaking change. The third hides the most and constrains the caller the least, but also promises the least — downstream code cannot rely on receiving a `String` or `&str` specifically.

Decision rule for argument shape:

1. If the body needs to own the value (store it as `self`, send across threads, return it), accept `T` — not `&T` + clone inside. Cloning inside hides allocation cost from the caller.
2. If the body only reads, accept `&T`. Exception: small `Copy` scalars (`i32`, `bool`) cost the same by value; pass by value for readability.
3. Large `Copy` arrays (`[u8; 8192]`) are still expensive — flag pass-by-value.
4. If sometimes ownership, sometimes not — return `Cow<'_, T>` (`String::from_utf8_lossy` is the prototype: borrows on success, allocates only on the error path).
5. If lifetimes are making an API painful for cheap-to-clone data, take ownership deliberately.

**Push allocation to the caller.** A function that needs ownership should accept `T` and let the caller decide whether they have a fresh value or need to clone. Hidden internal cloning makes profiling lie.

**`impl Into<String>` argument pattern** is justified only when the function actually moves the string into `self`. Using it on a function that immediately calls `.as_ref()` is a misleading signature — switch to `&str`.

Symmetric trap: returning `String` when the function sometimes already has a borrowed slice forces an unnecessary allocation on the happy path. `Cow<'_, str>` is the right answer when the borrowed case is common.

## Fallible and Blocking Destructors

`Drop::drop(&mut self)` cannot return `Result`, cannot `.await`, and cannot reliably spawn async work because the executor may be shutting down. For I/O-flavored types whose cleanup can fail:

- Provide best-effort `Drop` that swallows errors and does what it can synchronously
- Provide an explicit destructor — `fn close(self) -> Result<(), CloseError>` (or `async fn close(self)`) — and **document it prominently**

```rust
impl Connection {
    pub fn close(self) -> Result<(), CloseError> {
        // graceful shutdown, surfaces errors
    }
}
```

**The move-out trap.** Once you implement `Drop`, you cannot move fields out of `&mut self` in another method, because the destructor still runs and requires all fields intact. Three workarounds in increasing complexity:

1. **`Option`-wrapped inner.** `pub struct Outer(Option<Inner>);` — both `close` and `Drop` use `Option::take`. Inner has no `Drop`. Tax: every method unwraps the `Option`.
2. **Per-field `Option` or `std::mem::take`.** Replace each field with `Option<F>` or swap a default in during destruction. Works when fields have cheap defaults. Tax: every access becomes `.as_ref().unwrap()`. Jon recommends this as the default.
3. **`ManuallyDrop<Inner>`.** Derefs to `Inner` cleanly (no unwraps). `Drop` calls `ManuallyDrop::take`. **Unsafe** — taking twice or using after take is UB. Use only when the type is small enough to verify by reading.

**Async destructor caveats.** Do not call `block_on(async_close())` inside `Drop` — it deadlocks single-threaded executors and panics on multi-threaded runtimes mid-shutdown. Provide `async fn close(self)` and document the leak risk if it is not awaited.

## Naming Conventions as Review Checks

Users guess behavior from names. Mismatches are real bugs.

- **Iteration.** `iter(&self)` returns an iterator. `iter_mut(&mut self)`. `into_iter(self)` consumes. A method called `iter` that takes `self` is a bug.
- **Getters.** A plain getter is `fn name(&self) -> &T`, never `get_name`. Reserve `get_` for interesting behavior — `HashMap::get` returns `Option<&V>` because the key may be missing; that is non-trivial.
- **Conversion cost taxonomy.**
  - `as_*` — cheap, borrowed-to-borrowed reference conversion. `Vec::as_slice`, `String::as_str`. **No allocation.**
  - `to_*` — possibly expensive, borrowed-to-owned. `str::to_string`, `Path::to_owned`. May allocate.
  - `into_*` — consuming, owned-to-owned. `String::into_bytes`.
- **`try_` prefix.** A normally-infallible operation that may fail (`Vec::try_reserve`, `BufWriter::try_into_inner`). Always returns `Result`.
- **`SomethingError`.** A type with this suffix is expected to `impl std::error::Error` and appear in `Result`s. Conversely, anything implementing `Error` should be named `*Error`.
- **`new`, `with_*`, `from_*`.** `new` is the unsurprising primary constructor. `with_capacity(n)` configures one knob. `from_*` is an infallible conversion-as-constructor (`String::from_utf8` is fallible, hence the variant `from_utf8_unchecked`).
- **Pairs.** `is_empty()` is paired with `len()`. `contains_key()` is paired with `get()`. Inconsistent pairs (`empty()` returning a bool, `length()` instead of `len()`) violate intuition.
- **Unchecked / dangerous variants.** Suffixes like `_unchecked` or `_dangerous` signal "skips a check the safe version performs" and demand `unsafe`. Standard examples: `slice::get_unchecked`, `str::from_utf8_unchecked`. Use these names deliberately as a documentation hint — they make readers stop and consult the safety contract.

Corollary: reusing a familiar name with mismatched semantics is worse than inventing a fresh name. A method named `iter` that takes `self` will cause users to write `for x in c.iter() { ... }` followed by a second call that fails because `c` was moved.

## Standard Derive Priority

Implement these eagerly on public types because foreign users cannot add them later (coherence). Jon's ordered priority:

1. **`Debug`** — every public type. Hand-write the impl if `#[derive(Debug)]` would propagate `T: Debug` to a phantom generic. Use `f.debug_struct`, `f.debug_tuple`, `f.debug_list` helpers.
2. **`Send`, `Sync`, `Unpin`** — these are auto-traits, but if your type is *not* one of them, document why prominently. A non-`Send` type cannot live in `Mutex` or in async runtimes.
3. **`Clone`** — most types should clone. If yours cannot, document.
4. **`Default`** — when "zero-state" is obvious.
5. **`PartialEq`** — gates `assert_eq!` in tests. Worth deriving even when equality is rare.
6. **`Eq`, `Hash`** — for collection keys; `Eq` carries reflexivity, so only derive when semantics agree.
7. **`PartialOrd`, `Ord`** — only when meaningful ordering exists. Don't derive on enums where variant order is arbitrary.
8. **`Serialize`, `Deserialize`** — gate behind a `serde` cargo feature: `#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]`. Forcing the dependency is rude.

**`Copy` is deliberately absent from the priority list.** It changes move semantics, surprises users who expected `.clone()`, and is brittle: adding any non-`Copy` field later (a `String`, an `Arc`) silently removes `Copy` and breaks every caller relying on it. Reserve `Copy` for plain scalar-like newtypes where it is genuinely natural.

## Hidden Contracts

Two categories of subtle SemVer hazards.

**Re-exports.** Any foreign type appearing in your public interface — return type, argument, associated type — makes that crate's major version part of your contract:

```rust
// your crate
pub fn iter<T>() -> itercrate::Empty<T> { /* ... */ }
// downstream wires it into:
struct Wrapper { inner: itercrate::Empty<()> }
```

When you bump `itercrate` from 1.x to 2.x, *your* crate still compiles, but downstream code holding `itercrate1::Empty` cannot accept your new `itercrate2::Empty` — they are different types. **Bumping a major version of a re-exported dependency is a breaking change for you.** Mitigations:

- Wrap the foreign type in a newtype, exposing only the operations you want
- Return `impl Trait` with a narrow bound so the concrete type is invisible
- Use David Tolnay's "SemVer trick" when one foreign type genuinely did not change across the boundary

The newtype mitigation looks like:

```rust
pub struct Iter<T>(itercrate::Empty<T>);
impl<T> Iterator for Iter<T> { /* forward */ }
pub fn iter<T>() -> Iter<T> { Iter(itercrate::empty()) }
```

Downstream now depends on `Iter`, not on `itercrate::Empty` directly — you can swap `itercrate` for a different implementation without breaking anyone. The `impl Trait` variant pushes this even further: `pub fn iter<T>() -> impl Iterator<Item = T>` exposes nothing about the underlying type.

The SemVer trick (David Tolnay): if a foreign type genuinely did not change between *its* 1.0 and 2.0, you can release a 1.x patch of your own crate that depends on the *foreign* 2.0 and re-exports the type from 2.0. Both `foreign1.x::Type` and `foreign2.x::Type` then resolve to the same item, even though other things in the foreign crate did break.

**Auto-trait propagation.** `Send`, `Sync`, `Unpin`, `UnwindSafe`, and `RefUnwindSafe` are inferred from fields. They also propagate through `-> impl Trait` and `async fn` return types — callers can rely on the returned future being `Send` even though its concrete type is hidden. Result: changing a private field's type can silently flip a public type's auto-trait set.

```rust
// Before: A: Send because B: Send
pub struct A { private: B }
// After: B now holds Rc<T>, so A: !Send. SILENT BREAKING CHANGE.
```

**Compile-time auto-trait test** is the standard defense — a zero-cost test that fails to compile when a public type loses an expected auto-trait:

```rust
fn is_normal<T: Sized + Send + Sync + Unpin>() {}

#[test]
fn assert_normal() {
    is_normal::<MyType>();
    is_normal::<MyFuture>();
}
```

Run it in CI. Variants for `!Send` types replace the bounds with `Sized + Unpin` only, etc.

The same pattern applies to futures returned from `async fn` — if your public API returns a `Send` future today, a test like the following catches the day someone adds a non-`Send` local across an `.await`:

```rust
fn assert_send_future<F: Future + Send>(_: F) {}
#[test]
fn future_is_send() {
    assert_send_future(my_async_fn(/* args */));
}
```

**`#[doc(hidden)]` does not hide auto-traits.** Hidden items that user code can produce (via macros or sealed-trait helper types) still propagate `Send`/`Sync`/`Unpin` observably. Hidden inherent methods are usually fine to change; hidden auto-trait status is not. The same applies to sealed-trait method signatures: even though no one can implement the trait, the signatures appear in the vtable / generic instantiations of downstream code.

## Generic Arguments and Dispatch

Generic arguments relax the caller's requirements: instead of demanding a specific type, accept anything that satisfies the bounds. Start fully generic with no bounds; add bounds only when the body actually needs an operation. Make an argument generic if you can imagine multiple types a user would reasonably pass; keep it concrete otherwise.

Costs to weigh:

- **Monomorphization bloat.** Each instantiation gets its own codegen copy. Worry in hot code or when many concrete types instantiate the same generic.
- **Dynamic dispatch trade-off.** For arguments already taken by reference, swapping `impl Trait` for `&dyn Trait` cuts code size but forces vtable dispatch on every caller. The decision is made on the caller's behalf — fine for code paths that are never perf-sensitive, painful for library hot loops.
- **Dynamic dispatch is limited.** It works for single-trait bounds (`T: AsRef<str>`) but not compound bounds (`T: Hash + Eq`) — there is no single vtable shape for two traits. Compound bounds must stay generic.
- **Asymmetry.** Generic callers can opt into dynamic dispatch themselves by passing `&dyn Trait`. The reverse is not true — if you take a trait object, callers cannot recover static dispatch.

**Migrating concrete to generic is not free.** Changing `fn foo(v: &Vec<usize>)` to `fn foo(v: impl AsRef<[usize]>)` looks backward-compatible, but callers using inference (`foo(&things.iter().collect())`) break: previously the compiler could infer `Vec`; now it knows only "some `T: AsRef<[usize]>`" and has many candidates. Treat such migrations as semver-minor with a deprecation period.

Practical rule for reviewers: prefer `impl Trait` in argument position for simple bounds, generic parameters when the same type is referenced twice or the caller needs turbofish, and `&dyn Trait` only when you can demonstrate the call site is never performance-sensitive. Take a trait object as an argument only as a deliberate choice — it removes the caller's ability to opt back into static dispatch.

## Review Checks

Format: `[FILE:LINE] ISSUE_TITLE — short description and the fix.` See [api-design.md](../../rust-best-practices/references/api-design.md) for higher-level SemVer rules referenced below.

Object safety:

- `[FILE:LINE] Trait method returns Self — breaks object safety` — add `where Self: Sized` if `dyn Trait` is intended, or rewrite to take `Box<Self>` and return `Box<dyn Trait>`.
- `[FILE:LINE] Trait method has generic parameter — breaks object safety` — lift the generic to the trait, accept `&mut dyn Iterator<Item = X>`, or add `where Self: Sized`.
- `[FILE:LINE] Trait method takes Self by value — breaks object safety` — gate with `where Self: Sized` or accept `Box<Self>`.
- `[FILE:LINE] Trait has associated constant — breaks object safety` — convert to a method with a default impl.
- `[FILE:LINE] Trait method has no self receiver — breaks object safety` — `fn from_x(x: X) -> Self` cannot dispatch via vtable. Add `where Self: Sized` or move to a free function.
- `[FILE:LINE] Trait uses Sized as supertrait — disables all dyn usage` — drop the supertrait unless you genuinely want to forbid trait objects.
- `[FILE:LINE] New trait method returns Self with default impl — silent SemVer-major break` — flag as breaking even though existing impls compile; object-safety changes.
- `[FILE:LINE] Adding non-defaulted method to published trait — breaks downstream impls` — provide a default or bump major.

Ergonomic impls:

- `[FILE:LINE] Trait with &self methods lacks blanket impl for &T` — add `impl<T: Foo + ?Sized> Foo for &T` so generic callers accept references.
- `[FILE:LINE] Trait lacks blanket impl for Box<T>/Arc<T>` — provide where receivers allow; missing means `Box<dyn Foo>` doesn't satisfy `T: Foo` bounds.
- `[FILE:LINE] Trait forwarding impl missing ?Sized` — `impl<T: Foo + ?Sized> Foo for &T` should accept `&dyn Foo`. Without `?Sized` it does not.
- `[FILE:LINE] Iterable type lacks IntoIterator for &Self` — `for x in &collection` should compile.
- `[FILE:LINE] Iterable type lacks IntoIterator for &mut Self` — `for x in &mut collection` should compile.

Wrappers and Deref:

- `[FILE:LINE] Deref on wrapper does non-trivial work (lock/allocate)` — switch to an explicit method; Deref must be cheap.
- `[FILE:LINE] Wrapper has inherent method shadowing Deref::Target method` — clash risk on user-controlled targets; prefer `Wrapper::method(w)` static form.
- `[FILE:LINE] Transparent wrapper missing From<Inner>/Into<Inner>` — add to let users freely wrap and unwrap.
- `[FILE:LINE] Transparent wrapper implements Deref but not AsRef<Inner>` — add `AsRef` for callers using `impl AsRef<Inner>`.
- `[FILE:LINE] Borrow<T> implemented but Hash/Eq differ from inner` — Borrow requires identical hash/eq. Use AsRef instead.
- `[FILE:LINE] Opaque wrapper implements Deref` — Deref should be reserved for transparent wrappers; provide named accessors instead.

Borrowed vs owned:

- `[FILE:LINE] Function takes &T then clones internally — push allocation to caller` — accept `T` so the caller controls allocation.
- `[FILE:LINE] Function accepts String where &str suffices` — caller forced to allocate. Switch to `&str` unless the value is stored.
- `[FILE:LINE] impl Into<String> argument never moved into self` — misleading signature; switch to `&str`.
- `[FILE:LINE] Function returns String where Cow<'_, str> fits` — the function sometimes can return borrowed data; consider Cow.
- `[FILE:LINE] Large [u8; N] array passed by value` — flag bulk Copy arrays moved by value; pass by reference.

Destructors:

- `[FILE:LINE] Drop impl performs fallible I/O — errors silently lost` — provide `fn close(self) -> Result<...>` and keep best-effort logic in Drop.
- `[FILE:LINE] Drop impl calls block_on(...)` — async destructors deadlock or panic. Provide `async fn close(self)`.
- `[FILE:LINE] Explicit close()/shutdown() not surfaced in module docs` — users will not find it. Add documentation pointer to the explicit destructor.
- `[FILE:LINE] Type implements Drop and attempts to move out of self in another method` — won't compile or uses workarounds; require Option/take/ManuallyDrop pattern.
- `[FILE:LINE] ManuallyDrop::take used without safety comment` — unsafe; document why double-take and use-after-take are impossible.

Naming:

- `[FILE:LINE] iter takes self instead of &self — violates convention` — `iter` should take `&self`. `into_iter` consumes.
- `[FILE:LINE] Getter named get_foo() — drop the get_ prefix` — plain getters are `fn foo(&self) -> &T`.
- `[FILE:LINE] as_* allocates — should be to_*` — `as_*` is cheap reference conversion; allocation belongs in `to_*`.
- `[FILE:LINE] to_* returns borrowed data — should be as_*` — borrowed-to-borrowed is `as_*`, borrowed-to-owned is `to_*`.
- `[FILE:LINE] Fallible operation lacks try_ prefix` — name it `try_foo` and return `Result`.
- `[FILE:LINE] Error type missing "Error" suffix` — types implementing `std::error::Error` should be named `SomethingError` (see [error-handling.md](error-handling.md)).
- `[FILE:LINE] Type named FooError does not implement std::error::Error` — implement Error or rename.

Standard derives:

- `[FILE:LINE] Public type missing Debug` — derive Debug or hand-write; document if intentionally absent.
- `[FILE:LINE] derive(Debug) adds spurious T: Debug bound on phantom generic` — hand-write Debug to skip the bound.
- `[FILE:LINE] Public type !Send/!Sync with no documented reason` — add a `// Not Send because ...` comment or rustdoc note.
- `[FILE:LINE] Type missing Clone in a domain where users will clone` — derive Clone or document why missing.
- `[FILE:LINE] Type missing Default where construction is obvious` — derive Default.
- `[FILE:LINE] Type missing PartialEq — blocks assert_eq!` — derive at minimum.
- `[FILE:LINE] derive(Copy) chosen for convenience` — Copy is a long-term commitment; removing it is a breaking change. Reconsider unless the type is plainly scalar.
- `[FILE:LINE] serde derive not gated behind a feature flag` — gate with `#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]`.

Hidden contracts:

- `[FILE:LINE] Re-exported foreign type in public API` — bumping that dependency's major becomes your breaking change. Consider newtype wrapping or returning `impl Trait`.
- `[FILE:LINE] Public type missing compile-time auto-trait test` — add `fn is_normal<T: Sized + Send + Sync + Unpin>() {}` and call it from a test.
- `[FILE:LINE] Public type silently became !Send by changing private field` — flag as breaking; add or update auto-trait test.
- `[FILE:LINE] async fn returns non-Send future from a public API marked .await-able across threads` — annotate the future's `Send` requirement or fix the offending field.
- `[FILE:LINE] doc(hidden) item in user-reachable position` — auto-traits and sealed-trait signatures are still observable through it; document.
- `[FILE:LINE] Sealed trait not documented as sealed` — users will try to implement it; document the seal in rustdoc.
- `[FILE:LINE] Public crate adds prelude with new trait method` — risks wildcard-import ambiguity; flag and consider versioning the prelude.
- `[FILE:LINE] -> impl Trait return type leaks an auto-trait change` — auto-traits propagate through `impl Trait`; verify Send/Sync expectations are preserved.

Generic arguments and dispatch:

- `[FILE:LINE] Public API takes &dyn Trait — forces dynamic dispatch on all callers` — prefer `impl Trait` or a generic parameter so callers may choose.
- `[FILE:LINE] Concrete Vec<T> argument where &[T] or impl AsRef<[T]> fits` — flag with caveat that switching to generic can break caller inference.
- `[FILE:LINE] Single-use-site generic` — unnecessary generics inflate codegen with no flexibility benefit.
- `[FILE:LINE] impl Trait used in argument position when turbofish is needed at call sites` — switch to an explicit generic parameter so callers can `foo::<T>(...)`.
- `[FILE:LINE] Generic with no bounds in body of function — body uses methods` — compile error, but flag intent: are bounds missing or is the generic unused?

Documentation expectations:

- `[FILE:LINE] Function panics but lacks # Panics rustdoc section` — document panic conditions.
- `[FILE:LINE] Function returns Result but lacks # Errors rustdoc section` — document each error variant and trigger condition.
- `[FILE:LINE] unsafe fn lacks # Safety section` — caller preconditions must be spelled out.
- `[FILE:LINE] Crate root lacks an end-to-end usage example` — module-level examples beat per-method examples for new users.
- `[FILE:LINE] Builder/Result-returning function lacks #[must_use]` — annotate so ignoring the result triggers a warning.

## Anti-Patterns to Flag

- Reusing a familiar name with mismatched semantics (`iter` taking `self`)
- `get_foo()` for plain getters; reserve `get_` for `Option`-returning or fallible reads
- `as_*` that allocates, `to_*` that returns borrowed data
- Deriving `Copy` reflexively to "save a clone"
- `serde` derives without a feature flag
- New trait without blanket impls for `&T`, `&mut T`, `Box<T>`
- Iterable type without `IntoIterator` for `&Self` and `&mut Self`
- `Deref` on a wrapper whose target work is expensive
- Inherent methods on a wrapper whose `Deref::Target` is user-controlled
- `Borrow<T>` used as a generic "I behave like `&T`" when `AsRef<T>` is the correct trait
- Trait method that returns `Self` or takes a generic — silently kills object safety
- Adding a method to a published trait that flips it to non-object-safe
- Internal cloning that hides allocation cost from the caller
- `block_on(async_cleanup())` inside `Drop`
- Silent error-swallowing in `Drop` with no explicit `close()` alternative
- Re-exporting foreign types and treating dependency major bumps as internal-only
- No compile-time auto-trait test for important public types
