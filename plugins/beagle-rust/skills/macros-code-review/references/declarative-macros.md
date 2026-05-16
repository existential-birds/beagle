# Declarative Macros

## Fragment Types

Each fragment type constrains what tokens the matcher will accept. Using the wrong type causes confusing parse errors or overly greedy matching.

| Fragment | Matches | Use When |
|----------|---------|----------|
| `:ident` | Identifier (`foo`, `my_var`) | Naming generated items, variables, or modules |
| `:expr` | Any expression (`x + 1`, `foo()`) | Values to compute or pass to functions |
| `:ty` | Type (`u32`, `Vec<String>`) | Type parameters for generics or trait impls |
| `:tt` | Single token tree (`foo`, `(a + b)`) | Catch-all when other fragments are too restrictive |
| `:path` | Path (`std::io::Error`, `crate::Foo`) | Importing or referencing items |
| `:pat` | Pattern (`Some(x)`, `1..=5`) | Match arms, `let` bindings |
| `:stmt` | Statement (`let x = 1;`) | Injecting statements into generated blocks |
| `:item` | Item (`fn`, `struct`, `impl`) | Generating top-level definitions |
| `:block` | Block (`{ ... }`) | Function bodies, closures |
| `:meta` | Attribute content (`derive(Debug)`) | Forwarding attributes |
| `:literal` | Literal value (`42`, `"hello"`) | Compile-time constants |
| `:vis` | Visibility (`pub`, `pub(crate)`, empty) | Controlling generated item visibility |
| `:lifetime` | Lifetime (`'a`, `'static`) | Lifetime-generic generated code |

### Common Fragment Mistakes

**`:expr` can be broader than intended** -- It matches full expressions, which can make some macro arms too permissive. Prefer narrower fragments like `:tt` when you need stricter syntax boundaries.

**`:ty` cannot be followed by `>`** -- After matching a type, the parser cannot distinguish `>` as closing a generic vs part of an expression. Structure matchers to avoid this ambiguity.

**`:pat` changed in edition 2021+** -- Now matches `|` patterns (e.g., `A | B`). Use `:pat_param` if you need the pre-2021 behavior that stops at `|`.

## Repetition Syntax

```rust
// Zero or more, comma-separated
$($item:expr),*

// One or more, semicolon-separated
$($stmt:stmt);+

// Zero or more with trailing separator tolerance
$($item:expr),* $(,)?

// Nested repetition (for key-value pairs)
$($key:expr => $value:expr),*
```

The separator goes **between** repetitions. To include a terminator **after each** repetition, place it inside the `$()`:

```rust
// Semicolon AFTER each, not between:
$($key:expr => $value:expr;)*
// Expands: key1 => val1; key2 => val2;
```

## Common Patterns

### Test Battery

Generate multiple test modules from a compact specification:

```rust
macro_rules! test_battery {
    ($($t:ty as $name:ident),* $(,)?) => {
        $(
            mod $name {
                use super::*;
                #[test]
                fn basic() { run_test::<$t>(Default::default()) }
                #[test]
                fn edge_case() { run_test::<$t>(edge_value()) }
            }
        )*
    }
}

test_battery!(u8 as u8_tests, u32 as u32_tests, i64 as i64_tests);
```

### Trait Impl for Many Types

```rust
macro_rules! impl_display_for_newtype {
    ($($t:ty),* $(,)?) => {
        $(
            impl ::core::fmt::Display for $t {
                fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
                    ::core::fmt::Display::fmt(&self.0, f)
                }
            }
        )*
    }
}
```

Note `::core::fmt::Display` -- not `std::fmt::Display`. Exported macros must use fully qualified paths.

### Counting (TT Munching)

Count items at compile time by recursively consuming tokens:

```rust
macro_rules! count {
    () => { 0usize };
    ($head:tt $($tail:tt)*) => { 1usize + count!($($tail)*) };
}
```

### Push-Down Accumulation

Build output incrementally across recursive calls:

```rust
macro_rules! reverse {
    ([] $($reversed:tt)*) => { ($($reversed)*) };
    ([$head:tt $($tail:tt)*] $($reversed:tt)*) => {
        reverse!([$($tail)*] $head $($reversed)*)
    };
}
// reverse!([a b c]) => (c b a)
```

## Hygiene Rules

### What IS Hygienic (Isolated)
Variables declared inside a macro exist in the macro's namespace. They cannot shadow or be shadowed by caller variables with the same name.

```rust
macro_rules! let_x {
    ($val:expr) => { let x = $val; };
}
let x = 1;
let_x!(2);       // This `x` is in the macro's namespace
assert_eq!(x, 1); // Caller's `x` is unchanged
```

### What is NOT Hygienic (Shared)
Types, modules, and functions defined in a macro are visible at the call site. This is by design -- macros commonly generate `impl` blocks, modules, and functions.

```rust
macro_rules! make_greeter {
    () => {
        fn greet() -> &'static str { "hello" }
    };
}
make_greeter!();
assert_eq!(greet(), "hello"); // Function is visible here
```

### Sharing Identifiers with the Caller

Pass identifiers in from the call site to affect caller scope:

```rust
macro_rules! set_var {
    ($var:ident, $val:expr) => { $var = $val; };
}
let mut x = 1;
set_var!(x, 42); // `x` originated at call site, so it refers to caller's `x`
assert_eq!(x, 42);
```

Any identifier from an `:expr` or `:ident` passed by the caller resolves in the caller's scope.

## Exported Macro Paths

For macros marked `#[macro_export]`, all paths must be absolute and crate-independent:

```rust
// BAD -- breaks for downstream users
macro_rules! bad_macro {
    ($val:expr) => { crate::MyType::new($val) };
}

// BAD -- breaks in no_std
macro_rules! also_bad {
    ($val:expr) => { ::std::vec![$val] };
}

// GOOD
#[macro_export]
macro_rules! good_macro {
    ($val:expr) => { $crate::MyType::new($val) };
}

// GOOD -- no_std compatible
#[macro_export]
macro_rules! good_vec {
    ($val:expr) => { ::alloc::vec![$val] };
}
```

## Review Checklist

1. Are fragment types appropriate for what they match? (`:expr` not used where `:tt` is safer?)
2. Do repetitions handle trailing separators? (`$(,)?` at end)
3. Are matchers ordered most-specific-first?
4. Do exported macros use `$crate::` and `::core::`/`::alloc::`?
5. Is there a `compile_error!` fallback for invalid patterns?
6. Does the macro output avoid `gen` as an identifier (edition 2024)?
7. Could this macro be replaced with generics?

## Hygiene Boundaries -- What Is Shared and What Is Local

Decl macros are **partially hygienic**. The split:

- **Variables (`let`-bindings)** are hygienic. A `let x = 1;` introduced inside a macro lives in the macro's own namespace and cannot collide with the caller's `x`.
- **Types, modules, functions, and macros** are **shared** with the caller. They resolve in the caller's scope, which is why a macro emitting `Vec::new()` fails when invoked in a scope without `Vec` imported.

```rust
macro_rules! demo {
    () => {
        let x = 1;          // hygienic -- own namespace
        let _v = Vec::new();// shared -- needs Vec in caller scope
    };
}
```

The fix for the shared half: use **absolute paths** (`::std::vec::Vec::new()`, `::core::result::Result`) or `$crate::...` for items defined in your own crate. Never rely on the caller having `use` for what your macro emits.

## `$crate` and Absolute Paths

`$crate` resolves to the **defining crate's root**, regardless of what name the caller imported your crate under. A macro that emits `$crate::MyType` works when the caller wrote `use my_lib as renamed;` or `extern crate my_lib as renamed;`. A macro that emits `my_lib::MyType` breaks immediately under renaming, and `crate::MyType` resolves to the caller's crate root (almost never what you want).

For standard-library references, prefer `::core::...` and `::alloc::...` over `::std::...`. The `core` and `alloc` crates are available in `no_std` contexts; `std` is not. A macro that hardcodes `::std::fmt::Display` is unusable in `no_std` downstreams even when `core::fmt::Display` would have sufficed.

## TT-Muncher Pattern

A TT-muncher recursively consumes one `tt` (or one chunk) per expansion until the input is empty. It is the escape hatch for syntax that no single fragment matcher captures cleanly.

```rust
// Recursion limit (default 128) hazard:
// every comma-separated arg costs one expansion.
macro_rules! sum {
    () => { 0 };
    ($head:expr $(, $tail:expr)*) => {
        $head + sum!($($tail),*)
    };
}
```

Default `#![recursion_limit = "128"]` caps input length. Raising the limit hides the real signal: at this scale, switch to a **procedural macro** (see [procedural-macros.md](procedural-macros.md)). Decl macros are a syntactic tool, not a token-stream parser.

## Fragment Matcher Types -- What Each Captures

- **`tt`** -- single token tree (one token, or a fully-balanced `()`/`[]`/`{}` group). Most permissive; the only matcher usable in TT-munchers.
- **`expr`** -- any expression. **Follow restriction:** can only be followed by `=>`, `,`, or `;`. Using `expr` where you later need `<` or `:` breaks the macro.
- **`pat`** vs **`pat_param`** -- 2021+ `pat` matches top-level `|` (`A | B`); `pat_param` keeps the pre-2021 behavior.
- **`ty`** -- a type expression. Cannot be followed by `<` (parser cannot distinguish generic-open from less-than).
- **`ident`** -- single identifier. Combine with `paste::paste!` to synthesize new identifiers.
- **`path`**, **`lifetime`**, **`literal`**, **`item`**, **`stmt`**, **`block`**, **`meta`**, **`vis`** -- as named.
- **`expr_2021`** -- explicit edition opt-in for new `expr` behavior (let-chains, etc.) when the surrounding crate is on an older edition.

The most common bug: reaching for `expr` because it "matches more" and then discovering follow-restriction blocks the next token.

## When NOT to Write a Decl Macro -- Jon's Decision Tree

1. Need to compute something at compile time over fixed types? -> **`const fn`**. No macro infrastructure, full type checking.
2. Need different implementations per type with the same code body? -> **generics with traits** (see [../../rust-best-practices/references/generics-dispatch.md](../../rust-best-practices/references/generics-dispatch.md)).
3. Need to abstract a syntactic pattern (`vec![]`, `println!`, mini-DSL)? -> **decl macro**.
4. Need to inspect, parse, or transform syntax (derive, attribute, code generation from struct shape)? -> **proc macro** (see [procedural-macros.md](procedural-macros.md)).

If you find yourself writing a TT-muncher to parse structured input, you have outgrown decl macros.

## Additional Review Checks ([FILE:LINE] format)

- [FILE:LINE] MACRO_NON_DOLLAR_CRATE_PATH -- `#[macro_export]` macro references an item from the defining crate via `my_lib::Foo` or `crate::Foo`. Breaks under crate renaming. Replace with `$crate::Foo`.
- [FILE:LINE] MACRO_HARDCODED_VEC_NEW -- Emits `Vec::new()` or `vec![]` without a path. Downstream callers without `Vec` in scope (or `no_std`) cannot use the macro. Use `::std::vec::Vec::new()` or `::alloc::vec::Vec::new()`.
- [FILE:LINE] MACRO_STD_WHERE_CORE_EXISTS -- Emits `::std::fmt::Display` / `::std::mem::replace` when `::core::fmt::Display` / `::core::mem::replace` are equivalent. Locks the macro out of `no_std` downstream crates.
- [FILE:LINE] TT_MUNCHER_NO_LIMIT_COMMENT -- Recursive `$head:tt $($tail:tt)*` pattern with no comment naming the `recursion_limit` hazard. At ~64 inputs the default limit becomes a problem; readers need to know.
- [FILE:LINE] TT_MUNCHER_NEAR_LIMIT -- TT-muncher invoked with input lengths approaching `recursion_limit`. Either raise the limit deliberately with a justifying comment or rewrite as a proc macro.
- [FILE:LINE] EXPR_MATCHER_WRONG_FRAGMENT -- Matcher uses `$x:expr` but the macro body needs to follow `$x` with a token outside `=>`/`,`/`;` (e.g., `$x:expr : $t:ty`). Follow restriction makes the macro fail to parse. Use `$x:tt` and validate downstream, or restructure the pattern.
- [FILE:LINE] DECL_MACRO_REIMPLEMENTS_CONST_FN -- Macro performs integer/string computation that a `const fn` would handle with full type checking and no expansion bloat. Replace with `const fn`.
- [FILE:LINE] DECL_MACRO_REIMPLEMENTS_GENERICS -- Macro varies only over types with identical code bodies. Replace with a generic function or trait impl; see [../../rust-best-practices/references/generics-dispatch.md](../../rust-best-practices/references/generics-dispatch.md).
- [FILE:LINE] DECL_MACRO_SHADOWS_CALLER_IDENTS -- Macro emits items (`fn`, `struct`, `mod`) whose names match identifiers commonly used in caller code. Because items are not hygienic, this silently shadows. Either prefix names with a macro-specific tag or document the contract.
