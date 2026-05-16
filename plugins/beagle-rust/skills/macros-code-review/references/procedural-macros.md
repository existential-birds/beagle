# Procedural Macros

## Three Types

| Type | Annotation | Behavior |
|------|-----------|----------|
| Function-like | `#[proc_macro]` | `fn(TokenStream) -> TokenStream` -- replaces invocation |
| Attribute | `#[proc_macro_attribute]` | `fn(attr, item) -> TokenStream` -- replaces annotated item |
| Derive | `#[proc_macro_derive(Trait)]` | `fn(TokenStream) -> TokenStream` -- appends after item |

**Attribute macro gotcha:** The return replaces the item entirely. Forgetting to include the original item in the output deletes it silently.

**Derive macro constraint:** Cannot modify the annotated item. Output is appended. Helper attributes (`#[my_helper(skip)]`) are markers consumed by the derive, not independent macros.

## Parsing with `syn`

Minimize features to reduce compile time:

```toml
# BAD -- enables everything, slow to compile
syn = { version = "2", features = ["full"] }

# GOOD -- only what derive macros need
syn = { version = "2", features = ["derive"] }
```

Standard parsing pattern:

```rust
use syn::{parse_macro_input, DeriveInput};

#[proc_macro_derive(MyTrait)]
pub fn derive_my_trait(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = &input.ident;
    quote! {
        impl MyTrait for #name {
            fn method(&self) -> &'static str { ::core::stringify!(#name) }
        }
    }.into()
}
```

## Generating Code with `quote`

Interpolation with `#var` and repetition with `#(#items)*`:

```rust
let field_names: Vec<_> = fields.iter().map(|f| &f.ident).collect();
let tokens = quote! {
    impl ::core::fmt::Debug for #name {
        fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
            f.debug_struct(::core::stringify!(#name))
                #(.field(::core::stringify!(#field_names), &self.#field_names))*
                .finish()
        }
    }
};
```

## Span Handling

Spans tie generated tokens to source locations. Correct spans produce good error messages.

| Span | Resolution | Use For |
|------|------------|---------|
| `Span::call_site()` | At macro invocation | Generated items visible to callers |
| `Span::mixed_site()` | Variables at def site, types at call site | Private variables (matches `macro_rules!` hygiene) |
| `Span::def_site()` | At macro definition | Unstable/nightly only |

Always propagate input spans to related output tokens:

```rust
// BAD -- error points to macro definition
let method = Ident::new("process", Span::call_site());

// GOOD -- error points to the user's field
let method = Ident::new(&format!("process_{}", field_name), field_name.span());
```

## Error Reporting

A proc macro that panics crashes the compiler. Use `syn::Error` with spans instead:

```rust
// BAD -- unhelpful ICE
panic!("MyTrait requires at least one field");

// GOOD -- compiler error pointing to the struct
return syn::Error::new_spanned(&input.ident, "requires at least one field")
    .to_compile_error().into();
```

Collect multiple errors with `syn::Error::combine` instead of returning on first failure:

```rust
let mut errors = Vec::new();
for field in &fields {
    if !is_valid(field) {
        errors.push(syn::Error::new_spanned(field, "invalid field type"));
    }
}
if let Some(first) = errors.into_iter().reduce(|mut a, b| { a.combine(b); a }) {
    return first.to_compile_error().into();
}
```

## Compile-Time Cost

1. **Dependency weight** -- `syn` with `full` features takes tens of seconds to compile. Minimize features. Compile proc-macro crates in debug mode (execution speed rarely matters).

2. **Generated code volume** -- The macro saves typing, not compiler work. Large `quote!` blocks repeated across many invocations bloat compile times.

Mitigation: minimize `syn` features, use `proc-macro2` for testing, profile with `cargo build --timings`, prefer declarative macros for simpler cases.

## Testing

**`trybuild`** -- Compile-fail tests with expected `.stderr` output:

```rust
#[test]
fn compile_tests() {
    let t = trybuild::TestCases::new();
    t.pass("tests/pass/*.rs");
    t.compile_fail("tests/fail/*.rs");
}
```

**`proc-macro2`** -- Unit tests outside the compiler context. Use `proc_macro2::TokenStream` and compare `to_string()` output.

**`macrotest`** -- Snapshot-based expansion tests. Expands macros and compares against committed snapshots with `macrotest::expand("tests/expand/*.rs")`.

## Common Patterns

### Derive with Helper Attributes

```rust
#[proc_macro_derive(Builder, attributes(builder))]
pub fn derive_builder(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    // Look for #[builder(default)] on fields via field.attrs
}
```

### Attribute Macro for Test Generation

```rust
#[proc_macro_attribute]
pub fn test_with_db(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let input_fn = parse_macro_input!(item as syn::ItemFn);
    let fn_name = &input_fn.sig.ident;
    let fn_body = &input_fn.block;
    quote! {
        #[test]
        fn #fn_name() {
            let db = setup_test_db();
            let result = ::std::panic::catch_unwind(|| #fn_body);
            teardown_test_db(db);
            if let Err(e) = result { ::std::panic::resume_unwind(e); }
        }
    }.into()
}
```

## Review Checklist

1. Is `syn` configured with minimal features?
2. Do generated tokens carry spans from input tokens?
3. Does the macro use `syn::Error` (not `panic!`) for invalid input?
4. Are multiple errors collected and reported together?
5. Is the volume of generated code reasonable?
6. Are there `trybuild` or `macrotest` tests?
7. Does generated code use `::core::`/`::alloc::` paths for `no_std` compatibility?
8. Does the attribute macro preserve the input item?
9. Is `Span::call_site()` used only for intentionally public identifiers?
10. Does generated code avoid `gen` as an identifier (edition 2024)?

See also [declarative-macros.md](declarative-macros.md).

## Span Hygiene in Proc-Macros

Three `proc_macro2::Span` constructors with distinct semantics. Choose deliberately:

- **`Span::call_site()`** — span of the macro invocation site (caller's location). Identifiers minted with this span resolve in the **caller's scope**. Use only when you want generated tokens to "look like the user wrote them" (errors pointing at user input, identifiers intended to respect the caller's namespace, items the user must be able to reference by name).
- **`Span::def_site()`** — span of the macro definition site. Identifiers resolve in the **macro crate's scope**. Use for helper items the macro introduces that must NOT clash with caller identifiers. **Unstable on stable Rust** (only fully usable on nightly `proc_macro::Span`); `proc_macro2::Span::def_site()` falls back to `call_site` on stable.
- **`Span::mixed_site()`** — a compromise matching `macro_rules!` hygiene: variables are hygienic (resolve in macro scope), but types, modules, and macros resolve in caller scope. **Default for most proc-macro work.** Use `mixed_site` by default; reach for `call_site` only when explicitly pointing at user code.

```rust
use proc_macro2::Span;
use syn::Ident;

// BAD: helper variable in caller scope -- collides with caller's `tmp`
let helper = Ident::new("tmp", Span::call_site());

// GOOD: variable hygienic, types still resolve at caller
let helper = Ident::new("tmp", Span::mixed_site());
let ty: syn::Type = syn::parse_quote!(::core::option::Option<#ident>);
```

## Error Reporting via `syn::Error`

Point at user code with precise spans instead of panicking:

- `syn::Error::new(span, "...")` — error at the given span.
- `syn::Error::new_spanned(node, "...")` — error spanning the entire AST node; prefer this when you have a `syn::Field`, `syn::Variant`, `syn::Type`.
- Convert with `.to_compile_error()` (returns `proc_macro2::TokenStream`) or `.into_compile_error()` (consumes).
- `syn::Error` is iterable — `combine()` multiple errors and emit them together for one-pass diagnostics.

```rust
let mut acc: Option<syn::Error> = None;
for field in fields.iter() {
    if field_is_invalid(field) {
        let e = syn::Error::new_spanned(field, "unsupported field type");
        match acc { Some(ref mut a) => a.combine(e), None => acc = Some(e) }
    }
}
if let Some(e) = acc { return e.to_compile_error().into(); }
```

## `parse_quote!` vs `quote!`

`quote!` produces a `proc_macro2::TokenStream` — the standard final return value. `syn::parse_quote!` produces a `syn::T` for any `T: syn::parse::Parse` (annotate the binding to drive inference). Use `parse_quote!` when subsequent code manipulates the result as a `syn::Type`, `syn::Expr`, `syn::WhereClause`, etc.

Pitfall: `parse_quote!` panics on parse failure. For fallible parses use `syn::parse2(quote! { ... })` explicitly and handle the `Result`.

```rust
let where_clause: syn::WhereClause = syn::parse_quote!(where #ty: ::core::fmt::Debug);
let ts: proc_macro2::TokenStream = quote! { impl Trait for #name {} };
```

## Compile-Time Cost Drivers

Proc macros are the biggest contributor to slow Rust builds. Audit:

- **`syn` feature flags** — `features = ["full"]` costs 30-50% more compile time than `["derive"]` or `["parsing"]` alone. Many crates pull `["full"]` reflexively; check what your macro actually parses.
- **Derive fan-out** — `#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Hash)]` on 100 types is 600 macro expansions. Each expansion runs the proc-macro code AND produces tokens the compiler must parse and check.
- **Attribute macros on async fn** — `tracing::instrument`, `tokio::main`, `async_trait` each expand the function body, growing AST size and multiplying downstream type-check work.
- **Switch to function-like when use is rare** — if a derive is used once or twice in a crate, a function-like macro called explicitly avoids the derive-registration overhead.

## trybuild for UI Tests

See [../../rust-testing-code-review/references/advanced-testing.md](../../rust-testing-code-review/references/advanced-testing.md) for full trybuild patterns. Key proc-macro caveat: `.stderr` outputs are **rustc-version-sensitive**. Pin a stable rustc in CI for trybuild jobs and use `TRYBUILD=overwrite` only on intentional rustc upgrades — never as a blanket fix for failing UI tests.

## Additional Review Checks ([FILE:LINE] format)

- [FILE:LINE] CALL_SITE_FOR_HELPER_VAR — Proc macro mints a helper variable via `Ident::new("tmp", Span::call_site())`. Caller with a same-named variable triggers ambiguity. Use `Span::mixed_site()`.
- [FILE:LINE] DEF_SITE_ON_STABLE — Proc macro uses `Span::def_site()` from `proc_macro::Span` on stable rustc. Won't compile. Use `proc_macro2::Span::mixed_site()` until `def_site` stabilizes.
- [FILE:LINE] PANIC_FOR_USER_ERROR — Proc macro uses `panic!`/`unwrap()`/`expect()` on invalid user input. Crashes the compiler with an ICE and loses spans. Return `syn::Error::new_spanned(node, "...").to_compile_error()` instead.
- [FILE:LINE] EARLY_RETURN_ON_FIRST_ERROR — Macro returns on the first `syn::Error` instead of accumulating with `combine()`. Users iterate compile-fix-compile-fix per error; combine and emit once.
- [FILE:LINE] QUOTE_ASSIGNED_TO_SYN_TYPE — `let ty: syn::Type = quote! { ... };` won't compile (`quote!` produces `TokenStream`). Use `syn::parse_quote!` for the syn AST type, or `syn::parse2(quote!{...})` for fallible parses.
- [FILE:LINE] SYN_FEATURES_FULL_UNNEEDED — `syn = { version = "2", features = ["full"] }` enabled when the macro only parses `DeriveInput`. Switch to `features = ["derive"]` to cut compile time 30-50%.
- [FILE:LINE] DERIVE_WITHOUT_TRYBUILD — Derive macro ships without `trybuild` compile-fail tests. Error-message regressions and accepted-but-broken inputs go unnoticed. Add `tests/ui/` with paired `.stderr` fixtures.
- [FILE:LINE] PROC_MACRO_TESTS_NIGHTLY_ONLY — Trybuild/UI tests pinned to `nightly` rustc only. Stable users hit different diagnostic wording; regressions surface as user bug reports. Run trybuild on the stable toolchain the crate supports.
- [FILE:LINE] ATTR_MACRO_LOSES_BODY_SPAN — Attribute macro re-emits the user's `fn` body but rebuilds tokens without preserving the original span. Errors inside the body point at the macro's source, not the user's code. Use `parse_quote_spanned!` or propagate `block.span()`.
- [FILE:LINE] PROC_MACRO_REEXPORT_PROC_MACRO_TYPES — Macro re-exports `proc_macro::TokenStream`/`proc_macro::Span` instead of `proc_macro2` equivalents. Downstream consumers (e.g., other macros wrapping yours, unit tests) can't link against `proc_macro` outside a proc-macro crate. Use `proc_macro2` for shared APIs; convert at the entry point only.
