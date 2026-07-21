---
name: elixir-docs-review
description: Reviews Elixir documentation for completeness, quality, and ExDoc best practices. Use when auditing @moduledoc, @doc, @spec coverage, doctest correctness, and cross-reference usage in .ex files.
---

# Elixir Documentation Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| @moduledoc, @doc quality, anti-patterns | [references/doc-quality.md](references/doc-quality.md) |
| @spec, @type, @typedoc coverage | [references/spec-coverage.md](references/spec-coverage.md) |

## Review Checklist

### Module Documentation
- [ ] All public modules have @moduledoc
- [ ] First-line summary is concise (one line, used by tools as summary)
- [ ] @moduledoc includes ## Examples where appropriate
- [ ] @moduledoc false only on internal/implementation modules

### Function Documentation
- [ ] All public functions have @doc
- [ ] All public functions have @spec
- [ ] @doc describes return values clearly
- [ ] Multi-clause functions documented before first clause
- [ ] Function head declared when arg names need clarification

### Doctests
- [ ] Doctests present for pure, deterministic functions
- [ ] No doctests for side-effectful operations (DB, HTTP, etc.)
- [ ] Doctests actually run (module included in test file)

### Cross-References
- [ ] Module references use backtick auto-linking (`MyModule`)
- [ ] Function refs use proper arity format (`function/2`)
- [ ] Type refs use t: prefix (`t:typename/0`)
- [ ] No plain-text references where auto-links are possible

### Metadata
- [ ] @since annotations on new public API additions
- [ ] @deprecated with migration guidance where appropriate

## Valid Patterns (Do NOT Flag)

- **@doc false on callback implementations** - Documented at behaviour level
- **@doc false on protocol implementations** - Protocol docs cover the intent
- **Missing @spec on private functions** - @spec optional for internals
- **Short @moduledoc without ## Examples on simple utility modules** - Not every module needs examples
- **Using @impl true without separate @doc** - Inherits documentation from behaviour

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|-------|--------------|
| Missing @moduledoc | Module is public AND not a protocol impl |
| Missing @spec | Function is public AND exported |
| Missing doctests | Function is pure AND deterministic |
| Generic @doc | Doc restates function name without adding value |

## Gates (sequenced — do not skip)

Work in order, once over the assembled finding list. Budget: max **1** pass. Stop when each gate has a recorded outcome. Tie-break: ship the remainder as questions, or drop them — do not re-run the gates.

1. **Scope lock** — You listed the exact `.ex`/`.exs` file paths (or `Module` names) under review; no vague “the project” scope.
2. **Full-context read** — For each candidate issue, you read the full surrounding definition (all clauses for multi-clause functions; full `@moduledoc` block for module-level claims), not only a diff hunk or search snippet.
3. **Evidence bundle** — Every draft finding uses the `[FILE:LINE] ISSUE_TITLE` header (line range allowed) **and** includes a verbatim quote or pointer to the `@doc` / `@spec` / doctest text in question. `Module.function/arity` may appear as supporting context but does not replace the `[FILE:LINE]` anchor. For “doctest fails” claims, cite `mix test` output for the relevant file or line, or the exact error string.
4. **Protocol before report** — `beagle-core:review-verification-protocol`'s Pre-Report Verification Checklist is applied **once** to the issue list before it is finalized — not once per finding, and not after shipping. Reporting is `beagle-core:verification-budget` tier REVERSIBLE.

## When to Load References

- Reviewing @moduledoc or @doc quality, seeing anti-patterns -> doc-quality.md
- Reviewing @spec, @type, or @typedoc coverage -> spec-coverage.md
