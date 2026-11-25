---
name: react-router-code-review
description: Reviews React Router v7 (and v6.4+ Data Router) code for proper data loading, mutations, error handling, and navigation patterns. Use when reviewing React Router routes, loaders, actions, error boundaries, or navigation logic.
---

# React Router Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| useEffect for data, missing loaders, streaming, params | [references/data-loading.md](references/data-loading.md) |
| Form vs useFetcher, action patterns, `data()` status | [references/mutations.md](references/mutations.md) |
| Missing error boundaries, `ErrorBoundary` / `errorElement` | [references/error-handling.md](references/error-handling.md) |
| navigate() vs Link, pending states | [references/navigation.md](references/navigation.md) |

## Review Checklist

- [ ] Data loaded via `loader` (or `clientLoader` in Framework Mode) not `useEffect`
- [ ] Route params accessed type-safely with validation
- [ ] Parallelizing independent fetches with `Promise.all`, and streaming non-critical promises directly (v7) or via `defer()` (v6.4+ legacy)
- [ ] Mutations use `<Form>` or `useFetcher` not manual fetch
- [ ] Actions handle both success (`redirect(...)`) and error (`data(..., { status: 400 })`) cases
- [ ] Error boundaries with `ErrorBoundary` (Framework/Data Mode) or `errorElement` (Data Mode) on routes
- [ ] Using `isRouteErrorResponse()` to check error types
- [ ] Navigation uses `<Link>` over `navigate()` where possible
- [ ] Pending states shown via `useNavigation()` or `fetcher.state`
- [ ] No navigation in render (only in effects, handlers, or loaders)

## Valid Patterns (Do NOT Flag)

These patterns are correct React Router usage - do not report as issues:

- **useEffect for client-only data** - Loaders run server-side in Framework Mode; localStorage, window dimensions, and browser APIs belong in `useEffect` (or `clientLoader`)
- **navigate() in event handlers** - Link is for declarative navigation; navigate() is correct for imperative navigation in callbacks/handlers
- **Type-safe loader data props/annotations** - `{ loaderData }: Route.ComponentProps` (Framework Mode) and `useLoaderData<typeof loader>()` (Data Mode) are type annotations, not unsafe assertions
- **Empty `ErrorBoundary` / `errorElement` at route level** - Route may intentionally rely on parent error boundary
- **Form without action prop** - Posts to current URL by convention; explicit action is optional
- **loader returning null** - Valid when data may not exist; null is a legitimate loader return value
- **Using fetcher.data without checking fetcher.state** - May be intentional when stale data is acceptable during revalidation

## Context-Sensitive Rules

Only flag these issues when the specific context applies:

| Issue | Flag ONLY IF |
|-------|--------------|
| Missing loader | Data is available at route entry (not post-mount interaction/subscription or browser-only state) |
| useEffect for data fetching | Data is NOT client-only (localStorage, browser APIs, window size) |
| Missing `ErrorBoundary` / `errorElement` | No parent route in the hierarchy has an error boundary |
| navigate() instead of Link | Navigation is NOT triggered by an event handler or conditional logic |

## Gates (before reporting any finding)

Run in order. **Pass each gate with evidence** (paths, line refs, or a one-line quote from code)—not intuition alone.

### Gate 1 — Scope the route surface

**Pass when:** You have repo path(s) to the route module, `routes` config entry, or layout that owns the behavior under review (write them in your notes before flagging).

### Gate 2 — Context-sensitive match

**Pass when:** For every issue that maps to **Context-Sensitive Rules**, the **Flag ONLY IF** condition is satisfied with a one-line rationale tied to the code; for other checklist items, you have a concrete code citation (path + line or short excerpt).

### Gate 3 — Non-issue patterns

**Pass when:** The behavior is not covered by **Valid Patterns (Do NOT Flag)** for that category.

### Gate 4 — Verification protocol

Load and follow the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md) when installed alongside sibling skills). **Pass when:** Its pre-report checklist (and any issue-type subsection that applies) is complete for each finding you will output.

## When to Load References

- Reviewing data fetching code → [references/data-loading.md](references/data-loading.md)
- Reviewing forms or mutations → [references/mutations.md](references/mutations.md)
- Reviewing error handling → [references/error-handling.md](references/error-handling.md)
- Reviewing navigation logic → [references/navigation.md](references/navigation.md)

## Review Questions

1. Is data loaded in loaders instead of effects?
2. Are mutations using Form/action patterns?
3. Are there error boundaries (`ErrorBoundary` / `errorElement`) at appropriate route levels?
4. Is navigation declarative with Link components?
5. Are pending states properly handled?
