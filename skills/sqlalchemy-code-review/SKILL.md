---
name: sqlalchemy-code-review
description: Reviews SQLAlchemy 2.0 and Alembic code for session lifecycle, Mapped relationships, N+1 queries, bulk DML, and safe migrations. Use when reviewing SQLAlchemy models, queries, async sessions, or Alembic revisions.
---

# SQLAlchemy Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Session lifecycle, `async_sessionmaker`, async sessions | [references/sessions.md](references/sessions.md) |
| `Mapped` / `relationship()`, lazy loading, N+1, `selectinload` | [references/relationships.md](references/relationships.md) |
| `select()` vs `query()`, ORM overhead, `insert()`/`update()` bulk ops | [references/queries.md](references/queries.md) |
| Alembic patterns, `autocommit_block()`, reversible data migrations | [references/migrations.md](references/migrations.md) |

## Review Checklist

- [ ] Sessions use context managers (`with`, `async with`) from configured `sessionmaker`/`async_sessionmaker`
- [ ] No session sharing across requests or threads
- [ ] Async sessions use `async_sessionmaker` with `expire_on_commit=False` (no removed 1.x `autocommit` parameter)
- [ ] Models use SQLAlchemy 2.0 `Mapped[T] = mapped_column(...)` typing
- [ ] `relationship()` uses appropriate `lazy` strategy (`lazy="raise"` or explicit `selectinload`/`joinedload`)
- [ ] No lazy loading in loops (N+1 queries)
- [ ] Using SQLAlchemy 2.0 `select()` syntax, not legacy `query()`
- [ ] Bulk operations use Core `insert()` / `update()`, not ORM add/update loops
- [ ] Migrations are reversible with working `downgrade()`
- [ ] Data migrations use `op.execute(sa.text(...))` or Core `table()`/`column()`, not ORM models
- [ ] Concurrent index builds use `with op.get_context().autocommit_block():` (`postgresql_concurrently=True`)
- [ ] Migration dependencies properly ordered

## Gates (SQLAlchemy-specific)

Run **once per SQLAlchemy-related finding**, after anchoring **`file:line`** per `review-verification-protocol` ([review-verification-protocol](../review-verification-protocol/SKILL.md)) and **before** the finding ships. If a step's pass condition is not met, **do not** assert the finding as written—gather evidence, withdraw, downgrade severity, or rephrase as a question.

### Gate 1 — Session scope and lifecycle

| Step | Action | **Pass condition** |
|------|--------|---------------------|
| 1a | Open the module where the session is created or injected (not from memory). | **`file:line`** for `Session`, `sessionmaker`, `async_sessionmaker`, or the factory/`Depends()` that yields a session. |
| 1b | If claiming leak, cross-request sharing, or missing cleanup: trace the session's scope (context manager, `try`/`finally`, middleware). | **Scoped region** cited with a **`file:line` range**, or withdraw if scope is correct after the read. |

### Gate 2 — N+1, lazy loading, eager loads

| Step | Action | **Pass condition** |
|------|--------|---------------------|
| 2a | Identify the loop or repeated call site (ORM attribute access, `execute` in a loop). | **`file:line`** for the loop or hot path. |
| 2b | If claiming N+1: name the relationship or query pattern emitted per iteration. | **Relationship or per-iteration SQL pattern** with **`file:line`**, or rephrase as a question if unclear. |

### Gate 3 — Migrations (Alembic)

| Step | Action | **Pass condition** |
|------|--------|---------------------|
| 3a | Open the revision file (e.g. under `versions/`, or the project's Alembic layout). | **Repo-relative path** + **`file:line`** for `revision` / `upgrade` / `downgrade`. |
| 3b | If claiming broken `downgrade()` or risky data migration: point at the `op.*` / `op.execute()` involved. | **Snippet or line range** in that file for each claimed op, or withdraw. |

## When to Load References

- Reviewing session creation/cleanup → `references/sessions.md`
- Reviewing model relationships → `references/relationships.md`
- Reviewing database queries → `references/queries.md`
- Reviewing Alembic migration files → `references/migrations.md`

## Review Questions

1. Are all sessions created from a reused factory and managed with context managers?
2. Are relationships configured (`Mapped`, `lazy="raise"`, `selectinload`/`joinedload`) to avoid N+1 queries?
3. Are queries using SQLAlchemy 2.0 `select()` syntax and `insert()`/`update()` for bulk DML?
4. Are all migrations reversible, parameterized, and using `autocommit_block()` for concurrent indexes?
