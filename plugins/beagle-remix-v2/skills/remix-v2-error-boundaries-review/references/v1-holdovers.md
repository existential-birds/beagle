# v1 Holdovers — `CatchBoundary`, `useCatch`, `v2_errorBoundary`

Remix v1 split error handling across two route-module exports:
`CatchBoundary` for thrown `Response`s and `ErrorBoundary` for runtime
errors. v2 collapsed them into a single `ErrorBoundary`. The
transition was previewed behind the `future.v2_errorBoundary` flag in
late v1 and the old API was **removed** in `remix@2.0.0`.

In a v2 codebase, any of the three markers below is dead code at
best, broken behavior at worst. Always flag them and label the finding
as a **v1 holdover** (not a generic error-handling issue) so the fix
is unambiguous: delete the v1 API and fold its logic into v2 shape.

## How to detect

Grep the route module — and, for `v2_errorBoundary`, the config —
for:

| Marker | Where to look | What it means |
|---|---|---|
| `export function CatchBoundary` / `export const CatchBoundary` | Any `app/routes/**/*.tsx` | v1 thrown-`Response` boundary. Silently ignored in v2. |
| `useCatch` | Any `app/**/*.ts(x)` import or call site | v1 hook for reading a thrown `Response`. Does not exist in `@remix-run/react` v2. |
| `v2_errorBoundary` | `remix.config.js`, `remix.config.ts`, `vite.config.ts` plugin options | v1 future flag, removed in v2.0.0. Triggers a startup warning. |
| `ThrownResponse`, `CatchBoundaryComponent` types | Any `app/**/*.ts(x)` | v1 types. Gone in v2. |
| `unstable_shouldReload` | Any `app/routes/**` | v1 revalidation API (out of scope here but commonly appears in the same files). |

## Anti-patterns to flag

### 1. `CatchBoundary` export

**Pattern**

```tsx
// app/routes/posts.$slug.tsx
import { useCatch } from "@remix-run/react";

export async function loader({ params }: LoaderFunctionArgs) {
  const post = await db.post.findUnique({ where: { slug: params.slug } });
  if (!post) throw new Response("Not found", { status: 404 });
  return json({ post });
}

export function CatchBoundary() {                       // v1 export
  const caught = useCatch();
  return <p>{caught.status} {caught.statusText}</p>;
}

export function ErrorBoundary({ error }: { error: Error }) { // v1 prop signature
  return <p>{error.message}</p>;
}
```

**Why bad**

- `CatchBoundary` is not a v2 route-module export. Remix silently
  ignores it; the function is dead code.
- `useCatch()` is not exported from `@remix-run/react` v2. The import
  fails at build time (`'useCatch' is not exported`).
- The thrown 404 now flows to `ErrorBoundary` (the v2 contract), but
  the `ErrorBoundary` here uses the v1 prop signature so `error` is
  `undefined` at runtime.

The route appears to handle 404s; in production the boundary crashes
or shows nothing.

**Fix — collapse to a single v2 `ErrorBoundary`**

```tsx
import { isRouteErrorResponse, useRouteError } from "@remix-run/react";

export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error)) {
    return <p>{error.status} {error.statusText}</p>;
  }
  if (error instanceof Error) {
    return <p>{error.message}</p>;
  }
  return <p>Unknown error</p>;
}
```

Delete the `CatchBoundary` export and the `useCatch` import entirely.

### 2. `useCatch` import (with or without `CatchBoundary`)

**Pattern**

```tsx
import { useCatch, useLoaderData } from "@remix-run/react";
```

**Why bad**

`useCatch` does not exist in `@remix-run/react@^2`. The import line
either fails the build (strict TS / no fallback shim) or imports
`undefined` (loose builds), leading to `TypeError: useCatch is not a
function` at runtime.

A `useCatch` import with no `CatchBoundary` export is still a v1
holdover — usually the file was partially migrated. The author
removed the boundary but forgot to delete the import or a stray hook
call.

**Fix**

Remove the import. Replace any `useCatch()` call with `useRouteError()`
and narrow with `isRouteErrorResponse(error)`.

### 3. `v2_errorBoundary` future flag

**Pattern**

```js
// remix.config.js
module.exports = {
  future: {
    v2_errorBoundary: true,        // removed in 2.0.0
    v2_routeConvention: true,
    v2_meta: true,
  },
};
```

**Why bad**

`future.v2_errorBoundary` was the opt-in flag for the unified boundary
during late v1. In `remix@2.0.0` the flag — and the old
`CatchBoundary` implementation — were both removed. Leaving the entry
in the config produces a startup warning (`Unrecognized future flag:
v2_errorBoundary`) but is otherwise inert. More importantly, its
presence signals the config was migrated by a copy-paste from a v1
upgrade guide rather than a v2-native setup; nearby flags
(`v2_routeConvention`, `v2_meta`, `v2_normalizeFormMethod`) are likely
also stale.

**Fix**

Delete the entry. Audit the rest of the `future` block — every v2
flag from the migration era is now the default behavior and should be
removed.

### 4. `ThrownResponse` / `CatchBoundaryComponent` type imports

**Pattern**

```tsx
import type { ThrownResponse, CatchBoundaryComponent } from "@remix-run/react";

type NotFound = ThrownResponse<404, { message: string }>;
```

**Why bad**

These types were exported from `@remix-run/react` in v1 to describe
the shape of `useCatch()` returns and the `CatchBoundary` component.
They are not exported in v2. Type-only imports fail in strict TS
builds.

**Fix**

Replace with the v2 equivalents — there is no direct successor to
`ThrownResponse` because `useRouteError()` returns `unknown` and is
narrowed via `isRouteErrorResponse`. Type your thrown payload at the
throw site instead:

```tsx
type ErrorPayload = { message: string };
throw json<ErrorPayload>({ message: "Not found" }, { status: 404 });
```

Inside the boundary, narrow `error.data` defensively (see
[throw-response.md](throw-response.md) anti-pattern #2).

## Cross-references

- v2 boundary shape (the migration target) → [boundary-shape.md](boundary-shape.md)
- Throw / `handleError` semantics → [throw-response.md](throw-response.md)
- Remix `remix@2.0.0` changelog (flag + `CatchBoundary` removal): https://github.com/remix-run/remix/blob/remix@2.0.0/packages/remix-react/CHANGELOG.md
- v1 → v2 migration guide: https://v2.remix.run/docs/start/v2
