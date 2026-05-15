---
name: remix-v2-data-flow
description: Remix v2 data loading and mutations. Use when writing loaders, actions, deferred data, revalidation logic, or pending state. Triggers on loader, action, useLoaderData, useActionData, json(), defer(), <Await>, shouldRevalidate, useRevalidator, useNavigation, useTransition (v1 holdover).
---

# Remix v2 Data Flow

## Quick Reference

**Loader + typed read**:
```tsx
import { json, type LoaderFunctionArgs } from "@remix-run/node";
import { useLoaderData } from "@remix-run/react";

export async function loader({ request }: LoaderFunctionArgs) {
  const invoices = await db.invoice.findMany();
  return json({ invoices });
}

export default function Invoices() {
  // typeof loader is a type ANNOTATION (not assertion) — drives SerializeFrom<T>.
  const { invoices } = useLoaderData<typeof loader>();
  return <InvoiceList invoices={invoices} />;
}
```

**Action + redirect-after-success (PRG)**:
```tsx
import { json, redirect, type ActionFunctionArgs } from "@remix-run/node";
import { useActionData, Form } from "@remix-run/react";

export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const parsed = NewProject.safeParse(Object.fromEntries(form));
  if (!parsed.success) return json({ errors: parsed.error.flatten().fieldErrors }, { status: 400 });
  const project = await db.project.create({ data: parsed.data });
  return redirect(`/projects/${project.id}`);
}
```

## Canonical APIs

Route modules export `loader` / `action`; components read results via `useLoaderData<typeof loader>()` and `useActionData<typeof action>()`. After every action, Remix automatically revalidates the loaders of all matching routes on the page, so the UI stays consistent with the server without manual cache invalidation.

Signatures:

- `loader: ({ request, params, context }: LoaderFunctionArgs) => Response | Promise<Response>` — server-only read, runs on SSR and on client navigations via fetch.
- `action: ({ request, params, context }: ActionFunctionArgs) => Response | Promise<Response>` — server-only handler for non-GET requests (POST/PUT/PATCH/DELETE).
- `json(data, init?: number | ResponseInit): TypedResponse<typeof data>` — ergonomic JSON `Response` wrapper with status/headers.
- `redirect(url, init?: number | ResponseInit): TypedResponse<never>` — 30x response; default 302.

Imports: `@remix-run/node` for server utilities (`json`, `redirect`, `defer`, type args) on Node; substitute `@remix-run/cloudflare` or `@remix-run/deno` for those targets. Hooks and components come from `@remix-run/react`.

## Type Annotations, Not Assertions

`useLoaderData<typeof loader>()` is a **type annotation**, not a `as`-style assertion. The generic feeds `SerializeFrom<typeof loader>`, which models the wire-format transformation: `Date` becomes `string`, `Map`/`Set` collapse, `undefined` fields are stripped, class methods vanish. If you call `data.createdAt.getFullYear()` on a `Date` field, that's a runtime bug — the type already says `string`.

## When `json()` Is Optional in v2

v2 did **not** change the underlying contract: loaders and actions must return a `Response`. `json()` is the ergonomic wrapper that sets `application/json` and lets you supply status / headers. Bare object returns work in v2 (Remix auto-wraps as `json()`), but `json()` is preferred for explicit status, headers, and clean `TypedResponse<T>` typing. Reach for `json()` whenever you need:

- A non-200 status code (e.g. `{ status: 400 }` for validation errors).
- Custom headers (caching, `Set-Cookie`).
- An explicit `TypedResponse<T>` for clean `useLoaderData<typeof loader>()` inference.

## Throwing for Short-Circuits

Throwing a `Response` from a loader or action exits the data function immediately. Use this for auth guards (`throw redirect("/login")`) and 404s (`throw new Response("Not Found", { status: 404 })` or `throw json({ message }, { status: 404 })`). Throwing a plain `Error` will not be classified as a route response by `useRouteError()` / `isRouteErrorResponse()`.

## Sensitive Data

Everything returned from a loader travels to the browser as JSON. Project to a safe DTO (`{ id, email, name }`) before returning; never return the full Prisma `User`, password hashes, API keys, or internal flags. Loaders execute server-only — but the *return value* is shipped to the client wholesale.

## Mutations Belong in Actions

Loaders run on every GET navigation and may be invoked speculatively by prefetch; they also re-run during automatic revalidation. Anything that mutates persistent state must live in `action`, reached via `<Form method="post">` or `useFetcher`. Calling `fetch()` directly from a component to hit a Remix route bypasses revalidation, pending state, and progressive enhancement — use `useFetcher().submit()` / `useFetcher().load()` instead.

## Routing Gotchas to Remember

- **Only the deepest matching action runs.** Index routes nested under a layout collide unless you target them with `<Form action="/things?index" method="post" />`.
- **`useActionData` is scoped to the current route.** It cannot access action results from parent or child routes; to share, lift the action or use a `useFetcher` with `key`.
- **Headers from the leaf loader win.** Remix only uses the deepest matching `headers` export. Parent caching policies are ignored unless you explicitly merge `parentHeaders`.
- **Default revalidation revalidates ALL routes on the page after an action** — even those whose params didn't change. Use `shouldRevalidate` to opt out of expensive parent loaders.

## Pending State (v1 → v2)

`useTransition` is removed in v2 — use `useNavigation`. The `submission` object is flattened directly onto the navigation in v2 (and the fetcher likewise; both `nav.formData`/`nav.formMethod` and `fetcher.formData`/`fetcher.formMethod` are flat). `formMethod` is now **UPPERCASE** in v2 (`"POST"`, not `"post"`); comparisons like `nav.formMethod === "post"` silently never match. `fetcher.type` is also gone — branch on `fetcher.state` plus presence of `fetcher.formData`.

GET submissions go `idle → loading → idle`. POST flow goes `idle → submitting → loading → idle`. Spinners gated only on `"submitting"` will miss GET forms. GET submissions still populate `nav.formData` and `nav.formMethod === "GET"` during the `loading` phase, so filter-form pending UI should branch on `formData` presence, not on `state === 'submitting'`. For `useFetcher`, `submitting` applies to BOTH GET (`<fetcher.Form method='get'>` and `fetcher.submit(..., {method:'get'})`) and non-GET; only `fetcher.load()` skips `submitting`. This is the inverse of `useNavigation`, which skips `submitting` for GET.

## Gates (decision sequencing)

Answer **in order**. **Pass** means the condition is true; pick the API on the same line and **stop**.

### `loader` vs `useEffect`

1. **Is the data needed for correct first render** of this route (SSR, prefetch, automatic revalidation after actions)?
   - **Pass →** `loader` + `useLoaderData<typeof loader>()`. **Stop.**
   - **Fail →** Step 2.
2. **Is the fetch driven by post-mount user interaction, timer, or subscription** (not route entry)?
   - **Pass →** `useEffect` / event handlers. **Stop.**
   - **Fail →** Prefer loader + revalidation; do not mirror navigation inside an effect.

### `json()` vs raw `Response` vs `defer()`

1. **Do any returned fields need to stream** (slow query, expensive aggregation) while the page renders fast?
   - **Pass →** `defer({ critical: await…, slow: promiseWithoutAwait })` + `<Suspense><Await>…</Await></Suspense>`. **Stop.**
   - **Fail →** Step 2.
2. **Do you need a custom status code, custom headers, or explicit `TypedResponse<T>` typing**?
   - **Pass →** `json(data, init)` (or `redirect(url, init)` for 3xx). **Stop.**
   - **Fail →** Step 3.
3. **Do you need a non-JSON body** (binary, plain text, streamed file)?
   - **Pass →** Build a raw `new Response(body, init)`. **Stop.**
   - **Fail →** Default to `json(data)` — it's the documented v2 contract for object payloads.

### `<Form>` / route action vs `useFetcher`

1. **Should the URL or history stack change** (bookmark / share / back returns to prior screen)?
   - **Pass →** `<Form method="post">` posting to a route `action`. **Stop.**
   - **Fail →** Step 2.
2. **Mutation stays on the same route** (inline edit, list-row toggle, popover, optimistic UI)?
   - **Pass →** `useFetcher()` / `fetcher.Form` / `fetcher.submit()`. **Stop.**

## Additional Documentation

- **Loaders**: See [references/loaders.md](references/loaders.md) for `loader` signature, typed `useLoaderData`, `json()` vs raw `Response`, `redirect()`, throwing, sensitive-data filtering, params handling.
- **Actions**: See [references/actions.md](references/actions.md) for `action` signature, FormData parsing, `useActionData<typeof action>()`, zod/valibot validation, redirect-after-success.
- **Defer & Await**: See [references/defer-await.md](references/defer-await.md) for `defer()` + `<Await>` + `<Suspense>`, when streaming helps TTFB, error handling.
- **Revalidation & Pending State**: See [references/revalidation.md](references/revalidation.md) for automatic revalidation, `shouldRevalidate`, `useRevalidator`, `useNavigation` (plus v1 `useTransition` rename).

## v1 → v2 Quick Diff

| Concern              | v1                                  | v2                                               |
|----------------------|-------------------------------------|--------------------------------------------------|
| Navigation hook      | `useTransition()`                   | `useNavigation()`                                |
| Submission shape     | `transition.submission.formMethod`  | flat `nav.formMethod` / `nav.formData`           |
| `formMethod` casing  | `"post"`                            | `"POST"` (UPPERCASE)                             |
| Fetcher type field   | `fetcher.type === "actionSubmission"` | branch on `fetcher.state` + `fetcher.formData` |
| Loader args type     | `LoaderArgs` / `ActionArgs`         | `LoaderFunctionArgs` / `ActionFunctionArgs`      |
| Returning data       | `json(data)` required               | `json(data)` still the documented contract       |
