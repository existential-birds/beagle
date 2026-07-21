---
name: elixir-code-review
description: Reviews Elixir code for idiomatic patterns, OTP basics, and documentation. Use when reviewing .ex/.exs files, checking pattern matching, GenServer usage, or module documentation.
---

# Elixir Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Naming, formatting, module structure | [references/code-style.md](references/code-style.md) |
| With clauses, guards, destructuring | [references/pattern-matching.md](references/pattern-matching.md) |
| GenServer, Supervisor, Application | [references/otp-basics.md](references/otp-basics.md) |
| @moduledoc, @doc, @spec, doctests | [references/documentation.md](references/documentation.md) |

## Review Checklist

### Code Style
- [ ] Module names are CamelCase, function names are snake_case
- [ ] Pipe chains start with raw data, not function calls
- [ ] Private functions grouped after public functions
- [ ] No unnecessary parentheses in function calls without arguments

### Pattern Matching
- [ ] Functions use pattern matching over conditionals where appropriate
- [ ] With clauses have else handling for error cases
- [ ] Guards used instead of runtime checks where possible
- [ ] Destructuring used in function heads, not body

### OTP Basics
- [ ] GenServers use handle_continue for expensive init work
- [ ] Supervisors use appropriate restart strategies
- [ ] No blocking calls in GenServer callbacks
- [ ] Proper use of call vs cast (sync vs async)

### Documentation
- [ ] All public functions have @doc and @spec
- [ ] Modules have @moduledoc describing purpose
- [ ] Doctests for pure functions where appropriate
- [ ] No @doc false on genuinely public functions

### Security
- [ ] No `String.to_atom/1` on user input (use `to_existing_atom/1`)
- [ ] No `Code.eval_string/1` on untrusted input
- [ ] No `:erlang.binary_to_term/1` without `:safe` option

## Valid Patterns (Do NOT Flag)

- **Empty function clause for pattern match** - `def foo(nil), do: nil` is valid guard
- **Using `|>` with single transformation** - Readability choice, not wrong
- **`@doc false` on callback implementations** - Callbacks documented at behaviour level
- **Private functions without @spec** - @spec optional for internals
- **Using `Kernel.apply/3`** - Valid for dynamic dispatch with known module/function

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|-------|--------------|
| Missing @spec | Function is public AND exported |
| Generic rescue | Specific exception types available |
| Nested case/cond | More than 2 levels deep |

## When to Load References

- Reviewing module/function naming → code-style.md
- Reviewing with/case/cond statements → pattern-matching.md
- Reviewing GenServer/Supervisor code → otp-basics.md
- Reviewing @doc/@moduledoc → documentation.md

## Gates — before reporting

Do these **in order**, once for the review batch. Budget: max **1** pass. Stop when each step has a recorded outcome for the finding list. Tie-break: ship the remainder as questions, or drop them — do not re-run the gates.

1. **Protocol loaded** — Load `beagle-core:review-verification-protocol` **once**, at review entry, plus this plugin's [Elixir delta](../review-verification-protocol/SKILL.md). Apply its Pre-Report Verification Checklist to the finding list as a whole. Reporting is `beagle-core:verification-budget` tier REVERSIBLE — no per-finding recitation of which subsection you satisfied. Only a verdict authorizing an IRREVERSIBLE action (deleting a module, function, or migration) earns the full per-finding evidence gate.
2. **Anchored evidence** — Each finding includes a concrete locator: `path:line` (or line range), or `Module.function/arity` plus a short quoted snippet from the file.
3. **Claims backed by artifacts** — For assertions like unused code, missing validation, or security risk, attach the supporting artifact (search results naming the patterns searched, file read scope) or downgrade the item to an explicit **question** / **uncertain** with what you did not verify.

## Before Submitting Findings

Record an outcome for each of **Gates — before reporting** above, then ship.
