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
