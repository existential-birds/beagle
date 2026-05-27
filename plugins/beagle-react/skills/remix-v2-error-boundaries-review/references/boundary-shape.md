# ErrorBoundary Shape — Export, Hook, Narrowing

The v2 `ErrorBoundary` is a route-module export with no props. It reads
the thrown value through `useRouteError()` and must narrow correctly to
distinguish thrown `Response`s from runtime `Error`s. Most boundary
bugs are shape mistakes: props leak in from v1 examples, narrowing
covers one case but not the other, or a route that can throw exports
nothing at all.

## Canonical shape

```tsx
// app/routes/posts.$slug.tsx
import { isRouteErrorResponse, useRouteError } from "@remix-run/react";

export function ErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    return (
      <section>
        <h1>{error.status} {error.statusText}</h1>
        <p>{typeof error.data === "string" ? error.data : "Request failed."}</p>
      </section>
    );
  }
  if (error instanceof Error) {
    return (
      <section>
        <h1>Something went wrong</h1>
        <p>{error.message}</p>
      </section>
    );
  }
  return <h1>Unknown error</h1>;
}
```

Three narrowing branches in this order, no props, hook-driven.

## Anti-patterns to flag

### 1. Missing `ErrorBoundary` on a route that can throw

**Pattern**

```tsx
// app/routes/admin.users.$userId.tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const user = await db.user.findUnique({ where: { id: params.userId } });
  if (!user) throw new Response("Not found", { status: 404 });
  return json({ user });
}

export default function UserDetail() {
  const { user } = useLoaderData<typeof loader>();
  return <UserCard user={user} />;
}
// No ErrorBoundary export.
```

**Why bad**

The thrown 404 bubbles to the nearest ancestor with a boundary —
usually `app/root.tsx`. A whole-document re-render replaces the admin
chrome (nav, sidebar, breadcrumbs) for what should be an inline "user
not found" state. If `app/root.tsx` also lacks a boundary, the user
sees Remix's generic "Application Error" page.

**Fix**

Export a local `ErrorBoundary` that renders inline recovery UI inside
the admin shell:

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error) && error.status === 404) {
    return <p>User not found. <Link to="/admin/users">Back to list</Link></p>;
  }
  if (error instanceof Error) return <p>Failed to load user: {error.message}</p>;
  return <p>Unknown error.</p>;
}
```

**Exemption**: If the route deliberately delegates to a parent boundary
that already renders a good fallback, do *not* flag. Verify the parent
boundary exists and handles this route's error shape before exempting.

### 2. Props on `ErrorBoundary` (v1 carryover)

**Pattern**

```tsx
export function ErrorBoundary({ error }: { error: Error }) {
  return <div>{error.message}</div>;
}
```

**Why bad**

In v2 the boundary receives **no props**. `error` is `undefined` at
runtime, so `error.message` throws inside the boundary — causing an
infinite error loop. TypeScript will not catch this because the prop
type is unconstrained.

**Fix**

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  // ...narrow...
}
```

### 3. Narrowing only with `instanceof Error`

**Pattern**

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (error instanceof Error) {
    return <p>Error: {error.message}</p>;
  }
  return <p>Unknown error</p>;
}
```

**Why bad**

Thrown `Response`s are unwrapped to an internal `ErrorResponse`, which
is **not** an `Error` instance. A loader that does `throw json({ message: "Forbidden" }, { status: 403 })`
hits the `"Unknown error"` branch and the 403 status, statusText, and
payload are all lost. The user sees a generic message; the developer
sees no clue what happened.

**Fix**

Check `isRouteErrorResponse(error)` first, then `instanceof Error`:

```tsx
if (isRouteErrorResponse(error)) {
  return <p>{error.status}: {String(error.data)}</p>;
}
if (error instanceof Error) {
  return <p>Error: {error.message}</p>;
}
return <p>Unknown error</p>;
```

### 4. Narrowing only with `isRouteErrorResponse`

**Pattern**

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error)) {
    return <p>{error.status} {error.statusText}</p>;
  }
  return <p>Something went wrong</p>;
}
```

**Why bad**

A real bug — null deref, failed DB call, render-time exception —
surfaces as an `Error` instance, not an `ErrorResponse`. With no
`instanceof Error` branch the boundary falls through to the generic
fallback and the developer loses the message and stack at the UI
layer.

**Severity rule**

- **ADVISORY** if the route demonstrably only throws `Response`s
  (loader/action use `throw json` / `throw new Response` exclusively
  *and* the rendered component is trivial / non-crashing).
- **WARN** otherwise — most routes can render-crash.

**Fix**

Add the `instanceof Error` branch:

```tsx
if (isRouteErrorResponse(error)) return <p>{error.status} {error.statusText}</p>;
if (error instanceof Error)      return <p>Error: {error.message}</p>;
return <p>Something went wrong</p>;
```

### 5. Calling `useLoaderData()` inside `ErrorBoundary`

**Pattern**

```tsx
export function ErrorBoundary() {
  const data = useLoaderData<typeof loader>();
  return <p>Failed for {data.user.name}.</p>;
}
```

**Why bad**

The boundary may be rendering *because the loader threw* — in which
case `useLoaderData()` itself throws, causing a second error and a
boundary loop. Even when the boundary fires from a render-time crash
(not a loader throw), relying on loader data inside the boundary
couples the fallback to a code path that just proved it can fail.

**Fix**

Use `useRouteLoaderData("<route-id>")` and treat the result as possibly
`undefined`, or render a fallback that does not depend on loader data.

## Cross-references

- Throwing patterns (return-vs-throw, `handleError`) → [throw-response.md](throw-response.md)
- Root boundary specifics (`<Meta />`, `<Links />`, `<Scripts />`) → [root-boundary.md](root-boundary.md)
- v1 markers (`CatchBoundary`, `useCatch`) → [v1-holdovers.md](v1-holdovers.md)
- Remix v2 docs: https://remix.run/docs/en/main/route/error-boundary
