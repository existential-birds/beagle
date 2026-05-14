# Flat-Routes v2 Conventions

Remix v2 uses a **flat-file** routing convention. Every file under `app/routes/` becomes a route module; the filename itself encodes URL structure, nesting, and special behavior. Dots delimit URL segments, underscores mark pathless/index roles, dollar signs introduce dynamic segments, and brackets escape literal characters.

## Convention Table

| Convention            | Syntax                              | URL / Behavior                                     |
|-----------------------|--------------------------------------|----------------------------------------------------|
| Index route           | `_index.tsx`, `concerts._index.tsx` | Renders at the parent's exact URL                  |
| Dot delimiter         | `concerts.trending.tsx`             | `/concerts/trending` (also creates parent nesting) |
| Pathless layout       | `_auth.tsx`, `_auth.login.tsx`      | Shared layout with no URL segment                  |
| Dynamic segment       | `concerts.$city.tsx`                | `params.city`                                      |
| Splat (catch-all)     | `$.tsx`, `files.$.tsx`              | `params["*"]` (matches incl. slashes)              |
| Optional segment      | `($lang)._index.tsx`                | Matches `/` and `/en`; `params.lang` may be undefined |
| Escape literal        | `sitemap[.]xml.tsx`                 | `/sitemap.xml`                                     |
| Folder route          | `dashboard/route.tsx`               | `/dashboard`; other files in the folder are inert  |
| Opt-out of nesting    | `concerts_.mine.tsx`                | `/concerts/mine`, but does NOT inherit layout      |
| Resource route        | no `default` export                 | Returns non-HTML `Response`                        |

## Index Routes

`_index.tsx` (with the leading underscore) is the v2 index marker. It renders at the **parent's** URL — not its own. So:

```text
app/routes/
  _index.tsx              → /
  concerts.tsx            → /concerts  (layout)
  concerts._index.tsx     → /concerts  (inside the layout's <Outlet />)
```

A plain `index.tsx` (no underscore) in v2 is treated as a literal `/index` URL. Leftover `index.tsx` files post-upgrade silently produce wrong URLs.

## Dot Delimiter and Nested Layouts

Each dot in a filename creates both a URL slash and a parent/child relationship. The longest matching prefix wins as the parent layout:

```text
app/routes/
  concerts.tsx            → /concerts        (parent — renders <Outlet />)
  concerts._index.tsx     → /concerts        (child)
  concerts.$city.tsx      → /concerts/:city  (child)
  concerts.trending.tsx   → /concerts/trending
```

If a deeply dotted file has no parent module (e.g. `users.profile.settings.tsx` but no `users.tsx` or `users.profile.tsx`), the route still works — it just has no layout. That can confuse reviewers, so add the parent module or rename with trailing underscores to make the flat intent explicit.

## Pathless Layouts (`_name`)

A single leading underscore makes the segment **pathless** — it adds layout nesting without contributing to the URL:

```text
app/routes/
  _auth.tsx               (no URL segment; renders <Outlet />)
  _auth.login.tsx         → /login    (inherits _auth)
  _auth.signup.tsx        → /signup   (inherits _auth)
```

```tsx
// app/routes/_auth.tsx
import { Outlet } from "@remix-run/react";

export default function AuthLayout() {
  return <div className="auth-shell"><Outlet /></div>;
}
```

Watch out: `_auth._index.tsx` renders at `/` with the auth layout — almost never what was intended. Watch for accidental URL collisions when combining pathless parents with `_index`.

## Dynamic Segments (`$name`)

A segment beginning with `$` captures the URL value under that key in `params`:

```tsx
// app/routes/concerts.$city.tsx  →  /concerts/salt-lake-city
import type { LoaderFunctionArgs } from "@remix-run/node";

export async function loader({ params }: LoaderFunctionArgs) {
  // params.city is `string | undefined` — narrow before use
  if (!params.city) throw new Response("Not found", { status: 404 });
  return { city: params.city };
}
```

## Splat Route (`$.tsx`)

A literal `$` (no name) catches the rest of the URL, including embedded slashes. The value lives under the `"*"` key, not under `splat` or `rest`:

```tsx
// app/routes/files.$.tsx   →  /files/anything/here/even/slashes
export async function loader({ params }: LoaderFunctionArgs) {
  const path = params["*"]; // bracket access only — there is no named splat
  return new Response(await readBlob(path), {
    headers: { "Content-Type": "application/octet-stream" },
  });
}
```

## Optional Segments (`(segment)`)

Wrapping a segment in parentheses makes it optional:

```text
app/routes/($lang)._index.tsx   matches  /  and  /en
```

The key is always present in `params` — just possibly `undefined`. Don't assume it's omitted from the object. If zero-arg and one-arg behavior diverge significantly, prefer two explicit routes over one optional segment.

## Escaping Literal Characters

Only square brackets escape convention characters. Backslashes and quotes do **not** work:

```text
sitemap[.]xml.tsx           → /sitemap.xml
reports.$id[.pdf].tsx       → /reports/:id.pdf
```

Without the brackets, the dot becomes a nesting delimiter, and `sitemap.xml.tsx` would produce `/sitemap/xml`.

## Folder-Based Co-location

You can promote a folder to a route by placing `route.tsx` inside it. Every other file in the folder is **not** a route — it is colocated source the route imports:

```text
app/routes/
  dashboard/
    route.tsx              ← becomes the route module (/dashboard)
    queries.server.ts      ← NOT a route
    Chart.tsx              ← NOT a route
```

Without a `route.tsx`, the folder is ignored entirely. This pattern keeps server helpers, components, and tests next to the route module without polluting the URL space.

## Opt-Out of Layout Nesting (Trailing `_`)

A trailing underscore on a segment keeps the URL nested but **skips** layout inheritance:

```text
app/routes/
  concerts.tsx             → /concerts          (layout)
  concerts._index.tsx      → /concerts          (uses layout)
  concerts.$city.tsx       → /concerts/:city    (uses layout)
  concerts_.mine.tsx       → /concerts/mine     (does NOT use layout)
```

Use sparingly: a trailing underscore signals to readers that you're escaping a parent layout that exists. Don't add it when there's no parent layout to escape — it just creates noise.

## Resource Routes

A route module with **no** `default` export becomes a resource route — it returns a raw `Response` (PDF, JSON, RSS, webhook target) rather than HTML. See [resource-routes.md](resource-routes.md) for full coverage.

## Common Mistakes

- Using v1 `__double` underscore folders or plain `index.tsx` — both silently break in v2.
- Splat reader writing `params.splat` instead of `params["*"]`.
- Escaping a dot with a backslash (`sitemap\.xml.tsx`) instead of brackets.
- Trailing underscore on a route whose parent doesn't exist — pure noise.
- Importing `Outlet`/`Link`/`useLoaderData` from `react-router-dom` instead of `@remix-run/react`.
- Putting CSS, server helpers, or test files directly under `app/routes/` without folder convention — they get treated as routes. Either move into a `feature/` folder or add `ignoredRouteFiles` to `remix.config.js`.
