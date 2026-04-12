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
