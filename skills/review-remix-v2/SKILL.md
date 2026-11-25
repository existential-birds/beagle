---
name: review-remix-v2
description: Reviews legacy Remix v2 (@remix-run/*) codebases for routing, data flow, forms, error boundaries, meta/sessions, and SSR/caching traps. Remix v2 is EOL and superseded by React Router v7; use only when maintaining existing @remix-run/* applications.
---

# Remix v2 Maintenance Code Review

> **EOL & Migration Status:** Remix v2 (`@remix-run/*`) is End-of-Life and superseded by React Router v7 (`react-router-v7`). Use this skill strictly for maintaining existing `@remix-run/*` applications. Note `v3_*` future flags (`v3_fetcherPersist`, `v3_relativeSplatPath`, `v3_lazyRouteDiscovery`, `v3_singleFetch`, `v3_throwAbortReason`) or React Router v7 migration readiness as **Informational** only when relevant. Never prescribe Remix v1 (`CatchBoundary`, `useTransition`) or Next.js (`"use client"`) patterns.

## Arguments

- Path: Target directory or diff scope (default: current working directory)

## Step 1: Identify Scope & Confirm Remix v2

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.(tsx?|jsx?|mjs|cjs|css)$|^(remix|vite)\.config\.'
grep -E '"@remix-run/(react|node|cloudflare|deno|serve)"' package.json | head -3
```

If `git diff` returns nothing, inspect staged/working-tree changes or ask for an explicit file list. If `package.json` contains no `@remix-run/*` package, stop—route to `react-router-code-review` or `review-frontend` instead. Check `vite.config.*` vs `remix.config.js` (including `@remix-run/v1-route-convention` and `future.v3_*` flags) before flagging compiler or routing issues.

Quick surface greps for targeted inspection:
- Routes & shells: `app/routes/` filenames, `app/root.tsx`
- Loaders/actions/boundaries: `grep -rE 'export (async )?function (loader|action|ErrorBoundary)|defer\(|useRouteError' app/`
- Forms/meta/sessions/headers: `grep -rE '<Form|useFetcher|export (const|function) (meta|headers)|commitSession' app/`

## Step 2: Load Verification Protocol

Load the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md) when installed alongside sibling skills) before making any substantive severity judgment. Do not classify or write findings until this gate clears.

## Step 3: Consolidated Remix v2 Review Checklist

### 1. Routing & Root Shell (`app/routes/`, `app/root.tsx`)
- **Flat-routes v2 grammar**: Index routes use `_index.tsx` (not `index.tsx` unless `@remix-run/v1-route-convention` is wired). Pathless layouts use single `_` (`_auth.tsx`). Dotted children (`users.profile.tsx`) require `<Outlet />` in `users.tsx` or trailing-underscore opt-out (`users_.profile.tsx`, valid only when a parent layout exists). Literal dots escape with brackets (`sitemap[.]xml.tsx`); splat routes read `params["*"]`, never `params.splat`.
- **Resource routes**: Non-HTML `Response` routes (JSON/PDF/RSS/webhooks) must have **no** `default` export. Parent loaders do **not** run for resource routes, so auth checks must live inside the resource route's own `loader`/`action`. Callers using `<Link>` must pass `reloadDocument` (or use `<a>`).
- **Root document shell**: `app/root.tsx` must render `<Meta />`, `<Links />`, `<Outlet />`, `<ScrollRestoration />` *before* `<Scripts />`, and omit `<LiveReload />` under Vite (`@remix-run/dev/vite`). Root `ErrorBoundary` replaces the whole document—use `Layout` (Remix `>=2.4`) or return the complete `<html>` shell with `<Scripts />`.
  - Under Classic Compiler (`remix.config.js`), `<LiveReload />` already no-ops in production—do not wrap it in `NODE_ENV === "development"`.
  - Under Vite, remove `<LiveReload />` completely; Vite handles HMR natively.

### 2. Data Flow & Streaming (`loader`, `action`, `shouldRevalidate`)
- **Pure loaders & throws**: Never mutate inside `loader`; move writes to `action`. Short-circuit 401/403/404 with `throw new Response(...)` or `throw json(...)`—returning `json(..., { status: 404 })` skips `ErrorBoundary`.
- **Streaming (`defer()` / `<Await>`)**: Pre-`v3_singleFetch`, start slow unawaited promises *before* any `await` in `loader` so `defer()` streams immediately, and wrap every `<Await>` in `<Suspense>` with `errorElement` so rejections degrade locally:
  ```tsx
  const reviewsPromise = db.getReviews(params.id); // kick off BEFORE await
  const product = await db.getProduct(params.id);
  return defer({ product, reviews: reviewsPromise });
  ```
  Under `v3_singleFetch`, `json()`/`defer()` are deprecated in favor of raw object returns and `data()`.
- **Navigation state & revalidation**: `nav.formMethod` / `fetcher.formMethod` are UPPERCASE (`"POST"`, `"GET"`); lowercase comparisons silently fail. `useNavigation()` skips `"submitting"` for GET navigations (`idle -> loading -> idle`), whereas `<fetcher.Form>` enters `"submitting"` even on GET (`fetcher.load()` skips it). Avoid blanket `shouldRevalidate = () => false` without checking `formAction`/`defaultShouldRevalidate`, and never call `useRevalidator().revalidate()` immediately after `<Form>`/`useFetcher` mutations.

### 3. Forms & Uploads (`<Form>`, `useFetcher`, `FormData`)
- **Primitive choice & pending state**: Use `<Form>` + `redirect()` (PRG) when URL/history changes; use `useFetcher()` for inline/per-row mutations. Derive pending and optimistic UI directly from `useNavigation()` (scoped with `navigation.formAction` when sibling nav exists) or per-row `fetcher.state`/`fetcher.formData`—never mirror into `useState`:
  ```tsx
  const optimistic = fetcher.formData
    ? fetcher.formData.get("favorited") === "true"
    : item.favorited;
  ```
- **Multi-action intent & uploads**: Prefer a single route `action` switching on `formData.get("intent")` over sprawling mutation-only sub-routes on the same resource. File-upload `<Form>` requires `encType="multipart/form-data"`. Cap `unstable_createMemoryUploadHandler({ maxPartSize })` on user-controlled uploads (or use disk/stream handlers for large files). Note that `<Form method="put|patch|delete">` is JS-only without progressive enhancement unless normalized as POST + `intent`.

### 4. Error Boundaries (`ErrorBoundary`, `entry.server.tsx`)
- **Unified v2 signature**: Declare `export function ErrorBoundary()` with **no props** (`({ error })` leaves `error` undefined at runtime). Call `useRouteError()` and narrow `isRouteErrorResponse(error)` *before* `error instanceof Error`:
  ```tsx
  export function ErrorBoundary() {
    const error = useRouteError();
    if (isRouteErrorResponse(error)) return <p>{error.status} {error.statusText}</p>;
    if (error instanceof Error) return <p>{error.message}</p>;
    return <p>Unknown error</p>;
  }
  ```
- **Root & server error boundary contracts**: Root `ErrorBoundary` must call `useRouteLoaderData("root")` defensively (never `useLoaderData()`, which fails if root `loader` threw). `entry.server.tsx` `handleError` fires only on uncaught runtime errors—not thrown `Response`s—and filtering `if (request.signal.aborted) return` is intentional.

### 5. Meta, Sessions & Auth (`meta`, `commitSession`, CSRF)
- **Meta v2 array contract (CRITICAL)**: `meta` must return `MetaDescriptor[]` (`[...]`). A v1 object literal (`() => ({ title })`) or shorthand (`{ "og:title": "..." }` instead of `{ property: "og:title", content }`) often typechecks in loose configs but **silently drops tags at runtime**. `meta` does NOT auto-merge parent tags—use `matches.flatMap((m) => m.meta ?? [])` or plain JSX `<meta>` tags in `root.tsx`. Always null-guard `data` in `meta` (404/error renders pass `undefined`).
  ```tsx
  export const meta: MetaFunction<typeof loader> = ({ data, matches }) => {
    const parent = matches.flatMap((m) => m.meta ?? []).filter((t) => !("title" in t));
    return [...parent, { title: data?.post?.title ?? "Not Found" }];
  };
  ```
- **Sessions, flash & auth**: Gate auth in `loader`/`action` via `throw redirect(...)`, never component render (which leaks SSR loader data before client redirect). Implement logout as an `action` (POST), never a `loader` (GET CSRF). Call `commitSession(session)` and attach `Set-Cookie` after every `session.set`/`unset`/`flash` **and** in loaders that read a `flash` value (to clear it):
  ```tsx
  const error = session.get("error"); // flash read mutates session
  return json({ error }, { headers: { "Set-Cookie": await commitSession(session) } });
  ```
- **CSRF cookie separation & cookie security**: With `remix-utils/csrf`, store tokens in a dedicated `createCookie("csrf", ...)` cookie—never share the session cookie. Ensure production session/CSRF cookies set `httpOnly: true` and `secure: process.env.NODE_ENV === "production"`, and keep `secrets` as a rotation-ready array from env (`[process.env.SESSION_SECRET!, ...]`, prepending new secrets ahead of old ones).

### 6. SSR, Caching & Server/Client Split (`headers`, `*.server.ts`)
- **`headers` inheritance & forwarding**: Only the **deepest** matched route's `headers` runs; a personalized child omitting `headers` inherits an ancestor's `Cache-Control: public, s-maxage=...` and leaks user HTML at the CDN. Resource routes ignore `headers` exports (set headers on the returned `Response`). Document `headers` must forward `loaderHeaders`:
  ```tsx
  export const headers: HeadersFunction = ({ loaderHeaders }) => ({
    "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
  });
  ```
- **Server/client split, `clientLoader` & prefetch**: Server-only libs, secret `process.env.*`, and top-level side effects (`new PrismaClient()`, `withAuth(loader)` HOF wrappers pinning server imports) belong in `*.server.ts` or `app/.server/` (Vite)—`typeof window === "undefined"` does not stop static import hoisting. Whitelist `window.ENV` and escape `</script>` (`serialize-javascript`), never raw `JSON.stringify`:
  ```tsx
  <script dangerouslySetInnerHTML={{ __html: `window.ENV = ${serialize(data.ENV, { isJSON: true })}` }} />
  ```
  Check `clientLoader.hydrate` + `HydrateFallback` to avoid unintended client round-trips or hydration mismatches. `<PrefetchPageLinks page="/..." />` requires a leading `/` and `prefetch="render"` should not appear inside long lists; loaders with side effects must inspect `Purpose` / `Sec-Purpose: prefetch` headers.

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|---|---|
| `index.tsx` or `__double` route | `@remix-run/v1-route-convention` is NOT wired in `remix.config.js` |
| Child omitting `headers` | An ancestor route actually exports a broader cache policy (e.g. `public`) |
| `Vary: Cookie` missing | Loader branches response on cookie/session AND response uses `public`/`s-maxage` |
| `useNavigation()` missing `formAction` | Component contains sibling links/forms that could trigger false pending states |
| Unbounded `unstable_createMemoryUploadHandler` | Endpoint accepts user-controlled uploads (not fixed-size internal artifacts) |
| `<Form method="put\|patch\|delete">` | Surface requires progressive enhancement (no-JS support) |
| Missing `csrf.validate(request)` | App uses `remix-utils/csrf` or public action lacks an `Origin` check |
| `meta` returning `[]` | Route is documented as requiring page-specific tags (otherwise inheritance is valid) |

## Do NOT Flag (Valid Remix v2 Patterns)

- Resource routes with no `default` export; routes omitting `ErrorBoundary` to cascade to a parent boundary; nested `ErrorBoundary` returning a bare fragment without `<html>`.
- `useLoaderData<typeof loader>()` / `useActionData<typeof action>()` (type annotations, not casts), bare `new Response(...)` returns, and `useEffect` for browser-only APIs (`localStorage`, `window`).
- `unstable_parseMultipartFormData` / `unstable_create*UploadHandler` (`unstable_` is permanent in v2), `sameSite: "lax"` when CSRF/Origin protection is present, and `secrets: [process.env.X!, ...]` when guarded by a startup env check.
- `meta` returning `[]`, `links` returning `[]`, `headers` returning `no-store`, `commitSession` in a loader reading flash state, or `handleError` returning early on `request.signal.aborted`.
- GET `<Form>` for search/filters, `navigate={false}` on `<Form>`, `<Form>` without `action` (posts to current URL), or `useRevalidator()` for focus/polling/SSE.

## Verification Gates & Output Format

1. **Scope & Protocol**: Record Step 1 target files, detect `@remix-run/*` + compiler config (`vite.config.*` vs `remix.config.js`), and load `review-verification-protocol`.
2. **Evidence & Exemptions**: Every Critical/Major finding must cite an existing `FILE:LINE` with a verbatim quote, verify parent/root route context before claiming omissions, and clear all **Context-Sensitive Rules** and **Do NOT Flag** exemptions.
3. **Single-Pass Convergence**: Report all issues across routing, data flow, forms, errors, meta/sessions, SSR/caching, types, and security in one pass. Requests for net-new modules, dependencies, or test suites are **Informational**, not blocking. Re-reviews verify prior fixes only.

### Severity Defaults
- **Critical**: v1 `meta` object literal in v2 route, root `ErrorBoundary` missing `<Scripts />`, `Cache-Control: public` on auth/session route, leaked secret env in client graph.
- **Major**: `return json(..., { status: 404 })` instead of `throw`, `ErrorBoundary({ error })` prop signature, missing `commitSession` after `session.set`/`flash`, unbounded memory upload, `useNavigation` vs `useFetcher` mismatch.
- **Minor / Informational**: `v3_*` future flags / React Router v7 upgrade readiness, missing test coverage (one Minor item), optional `<Await>` error-boundary defense-in-depth on Response-only routes.

```markdown
## Review Summary
[1-2 sentence overview]

## Issues

### Critical (Blocking)
1. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Major (Should Fix)
2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)
N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Informational (For Awareness)
N. [FILE:LINE] SUGGESTION_TITLE
   - Suggestion: ...
   - Rationale: ...

## Good Patterns
- [FILE:LINE] Pattern description (preserve this)

## Verdict
Ready: Yes | No | With fixes 1-N (Critical/Major only; Minor/Informational ignored)
Rationale: [1-2 sentences]
```

## Upgrade Readiness (Informational Only)

When maintaining an active Remix v2 app, note missing `v3_*` future flags (`v3_fetcherPersist`, `v3_relativeSplatPath`, `v3_lazyRouteDiscovery`, `v3_singleFetch`, `v3_throwAbortReason`) or deprecated `json()`/`defer()` usage under `v3_singleFetch` as **Informational** items pointing toward React Router v7 (`react-router-v7`)—never as blocking findings on legacy maintenance PRs.

## Post-Fix Verification

```bash
npm run lint && npm run typecheck && npm run test
```

## Rules

- Load `review-verification-protocol` before judging severity.
- Cite `FILE:LINE` and verbatim code for every finding; check parent routes and `root.tsx` before claiming omissions.
- Keep Remix v2 semantics distinct from React Router v7 (`@remix-run/*` vs `react-router`, `json()`/`defer()` vs `data()`/raw returns).
- Re-reviews verify prior fixes only—never introduce unrelated findings or re-flag unfixed Minor/Informational items.
