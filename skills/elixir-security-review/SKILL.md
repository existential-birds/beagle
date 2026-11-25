---
name: elixir-security-review
description: Reviews Elixir code for security vulnerabilities including code injection, atom exhaustion, secret exposure, and BEAM process exposure. Use when reviewing code handling user input, external data, or sensitive configuration.
---

# Elixir Security Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| `Code.eval_string`, `binary_to_term`, `fragment` SQLi | [references/code-injection.md](references/code-injection.md) |
| `String.to_atom`, `Module.concat`, interpolation | [references/atom-exhaustion.md](references/atom-exhaustion.md) |
| `runtime.exs`, cookies, `@derive Inspect`, path traversal | [references/secrets.md](references/secrets.md) |
| ETS visibility, process dictionary, `format_status/1` | [references/process-exposure.md](references/process-exposure.md) |

## Review Checklist

### Critical (Block Merge)
- [ ] No `Code.eval_string/1` on user input
- [ ] No `:erlang.binary_to_term/1` without `[:safe]` (prefer `Plug.Crypto.non_executable_binary_to_term(data, [:safe])` on untrusted ETF payloads)
- [ ] No `String.to_atom/1`, `Module.concat/1,2`, or `:"...#{input}"` on external input
- [ ] No Ecto `fragment/1` string interpolation with untrusted input
- [ ] No hardcoded secrets in source code or compile-time `config/*.exs`

### Major
- [ ] ETS tables storing sensitive data use `:private` (not `:protected` or `:public`)
- [ ] No unredacted secrets in process dictionary, unredacted structs (`@derive {Inspect, except: [...]}`), or `GenServer` crash state (`format_status/1`)
- [ ] No dynamic module lookup/dispatch without explicit allowlist
- [ ] Path traversal prevented via `Path.safe_relative/1,2`

### Configuration & Sessions
- [ ] Secrets loaded in `config/runtime.exs` via `System.fetch_env!/1` (not baked at compile time)
- [ ] `Plug.Session` sets `encryption_salt` when storing sensitive data (signed-only cookies are readable)
- [ ] `:filter_parameters` configured for Phoenix logging

## Valid Patterns (Do NOT Flag)

- **`String.to_atom` / `Module.concat` on compile-time constants** - Fixed atoms created at compile time are safe
- **`Code.eval_string` in dev/test tooling** - May be needed for build/eval scripts
- **ETS `:public` or `:protected` tables** - Valid when storing non-sensitive shared data
- **`Plug.Crypto.non_executable_binary_to_term(data, [:safe])` or `binary_to_term(data, [:safe])`** - Explicitly safe option used

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|-------|--------------|
| `String.to_atom` / `Module.concat` | Input comes from external source (user, API, file) |
| `binary_to_term` | Data comes from untrusted source |
| ETS `:public` / `:protected` | Table contains sensitive secrets or session tokens |

## Hard gates (before reporting)

Complete **in order** for each finding you intend to report. Do not advance until the pass condition is satisfied.

1. **Location artifact** — The finding includes `[FILE:LINE]` (or a line range) that you copied from the current file contents; the path resolves in this repo.
2. **Scope read** — You read the full surrounding function or module section that contains the flagged code, not only a diff hunk or summary.
3. **External-data claim** (only if the finding depends on “user/untrusted input”) — You can name one concrete ingress (for example `conn.params`, `JSON.decode!/1` result, uploaded file path, message from another node) **or** you drop the finding because the value is compile-time, test-only, or internal per Context-Sensitive Rules.
4. **Protocol** — Pre-report steps in the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md)) are satisfied for this item (no finding if they are not).

## Before Submitting Findings

Use the issue format: `[FILE:LINE] ISSUE_TITLE` for each finding.

Hard gate 4 requires the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md)); use it as the full pre-report checklist and issue-type verification (it extends beyond this skill’s summary).
