---
name: sqlx-code-review
description: "Reviews sqlx database code for compile-time query checking, connection pool management, migration patterns, and PostgreSQL-specific usage. Use when reviewing Rust code that uses sqlx, database queries, connection pools, or migrations. Covers offline mode, type mapping, and transaction patterns."
---

# sqlx Code Review

## Review Workflow

1. **Check Cargo.toml** — Note sqlx version (`0.8` vs `0.9+`), features (`runtime-tokio`, `tls-rustls`/`tls-native-tls`, `postgres`/`mysql`/`sqlite`, `uuid`, `chrono`, `json`, `migrate`), and Rust edition (2024 changes RPIT lifetime capture and reserves lowercase `gen`)
2. **Check query patterns** — Compile-time checked (`query!`, `query_as!`) vs runtime (`query`, `query_as`)
3. **Check pool configuration** — Connection limits, timeouts, idle settings
4. **Check migrations** — File naming, reversibility, data migration safety
5. **Check type mappings** — Rust types align with SQL column types

## Gates (evidence before severity)

Complete in order; do not assign **Critical** / **Major** until the gate for that claim is passed.

1. **Scope** — Identify the crate under review (`Cargo.toml` path) and the `.rs` files (or directory) you opened. **Pass:** At least one concrete path you inspected is named.
2. **sqlx / compile claims** — Before asserting issues about `query!` / `query_as!`, offline mode, `.sqlx/`, `sqlx.toml` (`0.9+`), `DATABASE_URL`, or Cargo features: open the relevant `Cargo.toml` and, if applicable, `sqlx.toml` or documented env. **Pass:** The finding cites a line or you state that those files were absent / out of scope.
3. **Finding anchors** — Each reported issue includes `[FILE:LINE]` per **Output Format**. **Pass:** No Critical or Major without a line reference.
4. **Protocol** — Load and complete the [review-verification-protocol](../review-verification-protocol/SKILL.md) skill **after** gates 1–3 and **before** final severity labels. **Pass:** Protocol steps satisfied for each retained finding.

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
| Query macros, bind parameters, result mapping | [references/queries.md](references/queries.md) |
| Migrations, pool config, transaction patterns | [references/migrations.md](references/migrations.md) |

## Review Checklist

### Query Patterns
- [ ] Compile-time checked queries (`query!`, `query_as!`) used where possible
- [ ] Offline mode configured properly (`.sqlx/` + `SQLX_OFFLINE=true` in `sqlx 0.8+`, or `sqlx.toml` in `sqlx 0.9+`) or `DATABASE_URL` set for compile-time checking
- [ ] No string interpolation in queries (SQL injection risk) — use bind parameters (`$1`, `$2`)
- [ ] `query_as!` maps to named structs, not anonymous records, for public APIs
- [ ] `.fetch_one()`, `.fetch_optional()`, `.fetch_all()` chosen appropriately
- [ ] `.fetch()` (streaming) used for large result sets

### Connection Pool
- [ ] `PgPool` shared via `Arc` or framework state (not created per-request)
- [ ] Pool size configured for the deployment (not left at defaults in production)
- [ ] Connection acquisition timeout set
- [ ] Idle connection cleanup configured
- [ ] Async pool singletons use framework state (`State<PgPool>`) or `tokio::sync::OnceCell::get_or_try_init` (never `LazyLock` + `Handle::current().block_on`)

### Transactions
- [ ] `pool.begin()` used for multi-statement operations
- [ ] Transaction committed explicitly (not relying on implicit rollback on drop)
- [ ] Errors within transactions trigger rollback before propagation
- [ ] Nested transactions use savepoints (`tx.begin()`) if needed

### Type Mapping
- [ ] `sqlx::Type` derives match database column types
- [ ] Enum representations consistent between Rust, serde, and SQL
- [ ] `Uuid`, `DateTime<Utc>`, `Decimal` types used (not strings for structured data)
- [ ] `Option<T>` used for nullable columns
- [ ] `serde_json::Value` used for JSONB columns
- [ ] No struct fields or identifiers named lowercase `gen` — reserved keyword in edition 2024 (use `r#gen` with `#[sqlx(rename = "gen")]` or choose a different name)

### Edition 2024 Compatibility
- [ ] Functions returning `-> impl Stream` or `-> impl Future` account for RPIT lifetime capture changes (all in-scope lifetimes captured by default; use `+ use<'a>` when excluding unrelated lifetimes)
- [ ] Async repository/store traits use native `async fn` in traits where applicable (no `#[async_trait]` needed since Rust 1.75 unless `dyn Trait` is required; note `sqlx::FromRow` and `sqlx::Type` are synchronous traits)
- [ ] Prefer `#[expect(unused)]` over `#[allow(unused)]` for compile-time query fields only used in some code paths (self-cleaning lint suppression, stable since 1.81)

### Migrations
- [ ] Migration files follow naming convention (`YYYYMMDDHHMMSS_description.sql`)
- [ ] Destructive migrations (DROP, ALTER DROP COLUMN) are reversible or have data backup plan
- [ ] No data-dependent schema changes in same migration as data changes
- [ ] `sqlx::migrate!()` called at application startup

## Severity Calibration

### Critical
- String interpolation in SQL queries (SQL injection)
- Missing transaction for multi-statement writes (partial writes on error)
- Connection pool created per-request (connection exhaustion)
- Missing bind parameter escaping

### Major
- Runtime queries (`query()`) where compile-time (`query!()`) could verify correctness
- Missing transaction rollback on error paths
- Enum type mismatch between Rust and database
- Unbounded `.fetch_all()` on potentially large tables
- Field or identifier named lowercase `gen` without `r#gen` escape (edition 2024 compile failure)

### Minor
- Pool defaults used in production without tuning
- Missing `.fetch_optional()` (using `.fetch_one()` then handling error for "not found")
- Overly broad `SELECT *` when only specific columns needed
- Missing indexes for queried columns (flag only if query pattern is clearly slow)
- Using `#[allow(unused)]` instead of `#[expect(unused)]` for query fields (prefer self-cleaning lint suppression)

### Informational
- Suggestions to use `query_as!` for type-safe result mapping
- Suggestions to add database-level constraints alongside Rust validation
- Migration organization improvements

## Valid Patterns (Do NOT Flag)

- **Runtime `query()` for dynamic queries** — Compile-time checking doesn't work with dynamic SQL
- **`sqlx::FromRow` derive** — Valid alternative to `query_as!` for reusable row types
- **`TEXT` columns for enum storage** — Valid with `sqlx::Type` derive, simpler than custom SQL types
- **`.execute()` ignoring row count** — Acceptable for idempotent operations (upserts, deletes)
- **Shared DB with other languages** — e.g., Elixir owns migrations, Rust reads. This is a valid architecture.
- **`r#gen` with `#[sqlx(rename = "gen")]`** — Correct edition 2024 workaround for lowercase `gen` columns in database types
- **`+ use<'a>` on multi-lifetime query helper return types** — Precise RPIT lifetime capture (edition 2024)
- **`tokio::sync::OnceCell` for lazy async pool initialization** — Avoids blocking inside an async runtime
- **Native `async fn` in repository traits** — `async-trait` crate no longer needed for static dispatch (stable since Rust 1.75)

## Before Submitting Findings

Complete **Gates (evidence before severity)**, then load and follow the [review-verification-protocol](../review-verification-protocol/SKILL.md) skill before reporting any issue.
