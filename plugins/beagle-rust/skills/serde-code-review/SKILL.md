---
name: serde-code-review
description: Reviews serde serialization code for derive patterns, enum representations, custom implementations, and common serialization bugs. Use when reviewing Rust code that uses serde, serde_json, toml, or any serde-based serialization format. Covers attribute macros, field renaming, and format-specific pitfalls.
---

# Serde Code Review

## Review Workflow

1. **Check Cargo.toml** — Note serde features (`derive`, `rc`) and format crates (`serde_json`, `toml`, `bincode`, etc.)
2. **Check derive usage** — Verify `Serialize` and `Deserialize` are derived appropriately
3. **Check enum representations** — Enum tagging affects wire format compatibility and readability
4. **Check field attributes** — Renaming, defaults, skipping affect API contracts
5. **Verify round-trip correctness** — Serialized data must deserialize back to the same value

## Output Format

Report findings as:

```text
[FILE:LINE] ISSUE_TITLE
Severity: Critical | Major | Minor | Informational
Description of the issue and why it matters.
```

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Derive patterns, attribute macros, field configuration | [references/derive-patterns.md](references/derive-patterns.md) |
| Custom Serialize/Deserialize, format-specific issues | [references/custom-serialization.md](references/custom-serialization.md) |

## Review Checklist

### Derive Usage
- [ ] `#[derive(Serialize, Deserialize)]` on types that cross serialization boundaries
- [ ] `#[derive(Debug)]` alongside serde derives (debugging serialization issues)
- [ ] Feature-gated derives when serde is optional: `#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]`

### Enum Representation
- [ ] Enum tagging is explicit (not relying on serde's default externally-tagged format when another is intended)
- [ ] Tag names are stable and won't collide with field names
- [ ] `#[serde(rename_all = "...")]` used consistently across the API

### Field Configuration
- [ ] `#[serde(skip_serializing_if = "Option::is_none")]` for optional fields (clean JSON output)
- [ ] `#[serde(default)]` for fields that should have fallback values during deserialization
- [ ] `#[serde(rename = "...")]` when Rust field names differ from wire format
- [ ] `#[serde(flatten)]` used judiciously (can cause key collisions)
- [ ] No `#[serde(deny_unknown_fields)]` on types that need forward compatibility

### Database Integration (sqlx)
- [ ] `#[derive(sqlx::Type)]` enums use consistent representation with serde
- [ ] Enum variant casing matches between serde (`rename_all`) and sqlx (`rename_all`)

### Correctness
- [ ] Round-trip tests exist for complex types (serialize → deserialize → assert_eq)
- [ ] `PartialEq` derived for types with round-trip tests
- [ ] No lossy conversions (e.g., `f64` → `i64` in JSON numbers)
- [ ] `Decimal` used for money/precision-sensitive values, not `f64`

## Severity Calibration

### Critical
- Enum representation mismatch between serializer and deserializer (data loss)
- Missing `#[serde(rename)]` causing API-breaking field name changes
- `#[serde(flatten)]` causing silent key collisions
- Lossy numeric conversions (`f64` precision loss for monetary values)

### Major
- Inconsistent `rename_all` across related types (confusing API)
- Missing `skip_serializing_if` causing null/empty noise in output
- `deny_unknown_fields` on types consumed by evolving APIs (breaks forward compatibility)
- Missing round-trip tests for complex enum representations

### Minor
- Unnecessary `#[serde(default)]` on required fields
- Using string representation for enums when numeric would be more efficient
- Verbose custom implementations where derive + attributes suffice

### Informational
- Suggestions to switch enum representation for cleaner wire format
- Suggestions to add `#[non_exhaustive]` alongside serde for forward compatibility

## Valid Patterns (Do NOT Flag)

- **Externally tagged enums** — serde's default, valid for many use cases
- **`#[serde(untagged)]` enums** — Valid when discriminated by structure, not by tag
- **`serde_json::Value` for dynamic data** — Appropriate for truly schema-less fields
- **`#[serde(skip)]` on computed fields** — Correct for derived/cached values
- **`#[serde(with = "...")]` for custom formats** — Standard for dates, UUIDs, etc.

## Before Submitting Findings

Load and follow `beagle-rust:review-verification-protocol` before reporting any issue.
