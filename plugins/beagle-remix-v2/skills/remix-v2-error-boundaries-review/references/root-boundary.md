# Root ErrorBoundary — Document Scaffolding

The root `ErrorBoundary` in `app/root.tsx` is the last-resort boundary
for any error that bubbles past every nested boundary (or fires before
any nested boundary can mount). Unlike nested boundaries, it re-mounts
the **entire document** — so it owns `<html>`, `<head>`, and `<body>`
shells and must render the framework tags itself.

Three common bugs make the root boundary worse than no boundary at
all: missing entirely (Remix renders its generic page), present but
without `<Meta />` / `<Links />` / `<Scripts />` (white screen of
death after first error), or present but reading `useLoaderData()`
(infinite error loop when the root loader is the thing that threw).

## Canonical shape

```tsx
// app/root.tsx
import {
  isRouteErrorResponse,
  Links,
  Meta,
  Scripts,
  useRouteError,
  useRouteLoaderData,
} from "@remix-run/react";

export function ErrorBoundary() {
  const error = useRouteError();
  // Defensive: root loader may have thrown.
  const rootData = useRouteLoaderData<typeof loader>("root");

  return (
    <html lang="en">
      <head>
        <title>Application error</title>
        <Meta />
        <Links />
      </head>
      <body>
        <main className="error-shell">
          {isRouteErrorResponse(error) ? (
            <>
              <h1>{error.status} {error.statusText}</h1>
              <p>{typeof error.data === "string" ? error.data : "Request failed."}</p>
            </>
          ) : error instanceof Error ? (
            <>
              <h1>Something went wrong</h1>
              <p>{error.message}</p>
            </>
          ) : (
            <h1>Unknown error</h1>
          )}
          {rootData?.user ? <p>Signed in as {rootData.user.email}</p> : null}
        </main>
        <Scripts />
      </body>
    </html>
  );
}
```

`<Meta />` and `<Links />` keep critical head tags (charset, viewport,
CSS) in the document. `<Scripts />` boots the client runtime so the
user can navigate away. Missing any of these turns the error page into
a dead-end.

## Anti-patterns to flag

### 1. No root `ErrorBoundary` at all

**Pattern**

`app/root.tsx` exports `Layout` (or just a default `App`) and
`loader`, but no `ErrorBoundary`.

**Why bad**

Any error that escapes every nested boundary hits Remix's built-in
fallback — a hard-coded "Application Error" page with no branding,
status, or recovery affordance. Production stack traces are stripped
by default, so users see a generic message and developers see nothing
unless `handleError` is wired. First-impression error states matter:
this is the single most likely page a frustrated user will see.

**Fix**

Always export `ErrorBoundary` from `app/root.tsx` with the canonical
shape above.

### 2. Root boundary missing `<Meta />`, `<Links />`, or `<Scripts />`

**Pattern**

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  return (
    <html>
      <body>
        <h1>Something went wrong</h1>
        <p>{error instanceof Error ? error.message : "Unknown"}</p>
      </body>
    </html>
  );
}
```

**Why bad**

The root boundary re-mounts the whole document. Without `<Scripts />`
the client bundle never boots — `<Link>`, `<Form>`, navigation, even
`window.history.back()` fall back to native browser behavior. Without
`<Links />` all stylesheets vanish (unstyled error page). Without
`<Meta />` the charset, viewport, and per-route meta tags are missing
(mobile rendering breaks, SEO tags lost).

The cascade is silent: dev mode with HMR will often hide it because
HMR injects scripts; production builds expose the dead shell.

**Fix**

Render all three:

```tsx
<head><Meta /><Links /></head>
<body>{ ...error UI... }<Scripts /></body>
```

If your project uses a `Layout` component that already renders these,
the root `ErrorBoundary` can render `<Layout>...</Layout>` instead —
but verify the Layout component does not itself crash on missing
loader data.

### 3. Root boundary calls `useLoaderData()`

**Pattern**

```tsx
export async function loader() {
  const user = await getUserOrThrow(request);          // may throw
  return json({ user });
}

export function ErrorBoundary() {
  const { user } = useLoaderData<typeof loader>();    // throws if loader threw
  return <p>Sorry, {user.name}. Something broke.</p>;
}
```

**Why bad**

If the root loader is the thing that threw — and root loaders often
include auth, feature flags, theme — `useLoaderData()` inside the
boundary throws *again*. Remix sees a second error during boundary
render and falls back to its built-in error page. The carefully
designed root boundary never appears.

Even when the boundary fires from a child route error (not a root
loader error), the boundary becomes brittle: any future change that
makes the root loader throw silently breaks the error page.

**Fix**

Use `useRouteLoaderData("root")` and handle `undefined`:

```tsx
const rootData = useRouteLoaderData<typeof loader>("root");
// rootData may be undefined if root loader threw.
{rootData?.user ? <p>Signed in as {rootData.user.email}</p> : <p>Please sign in.</p>}
```

`useRouteLoaderData` returns `undefined` rather than throwing when the
data isn't available — making the boundary resilient to loader
failure at any level.

### 4. Root boundary without `<html>` / `<body>` wrappers

**Pattern**

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  return <div className="error">Something went wrong</div>;
}
```

**Why bad**

The root boundary owns the entire document. Returning a bare `<div>`
means Remix renders that `<div>` *as* the document — no `<html>`, no
`<head>`, no `<body>`. The browser tolerates this in quirks mode but
charset declaration, language attribute, and head tags are gone. The
page renders unstyled and accessibility tools report the document is
malformed.

Note: nested route `ErrorBoundary` exports correctly render *inside*
the document (parent layouts still apply), so they should **not**
include `<html>` / `<body>`. The wrapper requirement is specific to
the root boundary.

**Fix**

Always wrap root-boundary output in `<html><head>...</head><body>...</body></html>`
with `<Meta />`, `<Links />`, and `<Scripts />`.

## Cross-references

- Boundary shape and narrowing → [boundary-shape.md](boundary-shape.md)
- Throw vs return semantics → [throw-response.md](throw-response.md)
- Remix root route docs: https://remix.run/docs/en/main/file-conventions/root
- Error handling guide: https://remix.run/docs/en/main/guides/errors
