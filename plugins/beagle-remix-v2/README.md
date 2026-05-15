# beagle-remix-v2

Remix v2 (route modules + React Router v6) code review and best-practice skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

> **Scope**: This plugin targets **Remix v2** (`@remix-run/*` v2.x). It does **not** cover Remix 3 (the new web-standards monorepo). For React Router v7 framework-mode (the merged Remix v2 codebase shipped under the React Router name), see `beagle-react:react-router-v7`.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-remix-v2@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **review-remix-v2** | `/beagle-remix-v2:review-remix-v2` | Comprehensive Remix v2 code review. Detects Remix v2 in package.json, loads relevant review skills, runs verification protocol. |

## Skills

### Knowledge skills (auto-invoked when writing Remix v2 code)

| Skill | Description |
|-------|-------------|
| **remix-v2-routing** | Flat-routes v2 conventions, `_layout`/`_index`/`$param`, `root.tsx` scaffold, resource routes |
| **remix-v2-data-flow** | `loader`, `action`, `useLoaderData`, `useActionData`, `defer`/`Await`, revalidation, `useNavigation` |
| **remix-v2-forms** | `<Form>`, `useFetcher`, `useSubmit`, optimistic UI, intent-based multi-action, multipart upload |
| **remix-v2-perf-ssr** | `headers`/caching policy, streaming via `defer`+`<Await>`, `.server.ts`/`.client.ts` split, hydration safety, `<Link prefetch>`/`<PrefetchPageLinks>` |
| **remix-v2-meta-sessions** | v2 `meta` array API, `links`, `createCookieSessionStorage`, auth gates, CSRF |

### Code-review skills (loaded by the umbrella reviewer)

| Skill | Description |
|-------|-------------|
| **remix-v2-routing-review** | Reviews route-file naming, nested layouts, resource-route shape, v1-holdover detection |
| **remix-v2-data-flow-review** | Reviews loaders/actions for mutations-in-loader, missing validation, leaked server fields, missing pending state |
| **remix-v2-forms-review** | Reviews mutation primitives: flags manual `fetch()`, native `<form>`, wrong `useNavigation`/`useFetcher` choice |
| **remix-v2-error-boundaries-review** | Reviews `ErrorBoundary` (v2 unified), `isRouteErrorResponse` narrowing, v1 `CatchBoundary` holdovers |
| **remix-v2-perf-ssr-review** | Reviews caching headers, prefetch hygiene, server/client split, hydration mismatches |
| **remix-v2-meta-sessions-review** | Reviews v2 meta array shape, cookie security flags, auth-in-loader, CSRF wiring |

## See Also

- [beagle-core](../beagle-core) — Shared workflows, verification protocol, and git commands
- [beagle-react](../beagle-react) — React, React Router v7, shadcn/ui, Tailwind, Vitest, Zustand
- [beagle marketplace](https://github.com/existential-birds/beagle) — Full plugin marketplace
