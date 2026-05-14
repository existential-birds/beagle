# Root Module (`app/root.tsx`)

`app/root.tsx` is the **only required route** in a Remix v2 app. It owns the entire document shell — `<html>`, `<head>`, `<body>` — and is the rendering ancestor of every other route. Routes mount inside `<Outlet />`.

## Canonical Scaffold

```tsx
// app/root.tsx
import {
  Links,
  LiveReload,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "@remix-run/react";

export default function App() {
  return (
    <html lang="en">
      <head>
        <Meta />
        <Links />
      </head>
      <body>
        <Outlet />
        <ScrollRestoration />
        <Scripts />
        <LiveReload />
      </body>
    </html>
  );
}
```

All six elements are load-bearing; omitting any of them breaks a documented Remix feature.

## The Six Required Elements

### `<Meta />`

Renders every `meta` export collected from the current route and all its ancestors. Place it in `<head>` so the browser sees `<title>`, `og:`, `twitter:`, and viewport tags before paint.

```tsx
// any route module
export const meta = () => [
  { title: "Concerts" },
  { name: "description", content: "Browse upcoming concerts." },
];
```

### `<Links />`

Renders every `links` export from the route tree. Use it for stylesheets, preloads, and icons. Place it in `<head>` so CSS is applied before first paint.

```tsx
// app/root.tsx (or any route)
import type { LinksFunction } from "@remix-run/node";
import styles from "./styles/app.css";

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: styles },
];
```

### `<Outlet />`

The mount point for child routes. The matched route — and any nested layouts — render here. Without `<Outlet />`, no route renders.

### `<ScrollRestoration />`

Restores scroll position on back/forward navigation and resets to top on new navigations. Place it as the **first** element in `<body>` after `<Outlet />` so the script runs before `<Scripts />` mounts.

### `<Scripts />`

Loads the Remix runtime and route module bundles. Without it, the app renders server HTML and never hydrates — links and forms still work via the browser, but loaders/actions never run client-side, prefetching is dead, and there is no SPA navigation.

### `<LiveReload />`

Connects to the dev server's reload socket. It **only does anything during development** — in production builds it no-ops, it does **not** throw. Ship it as-is; don't conditionally render it.

## Loader, Action, and ErrorBoundary

Like any other route module, `root.tsx` can export `loader`, `action`, `meta`, `links`, `headers`, and `ErrorBoundary`. The root `ErrorBoundary` is the last line of defense — it catches errors thrown anywhere below it when no descendant boundary handles them.

```tsx
// app/root.tsx
import { json } from "@remix-run/node";
import type { LoaderFunctionArgs } from "@remix-run/node";
import { isRouteErrorResponse, useLoaderData, useRouteError } from "@remix-run/react";

export async function loader({ request }: LoaderFunctionArgs) {
  return json({ user: await getUser(request) });
}

export function ErrorBoundary() {
  const error = useRouteError();
  return (
    <html lang="en">
      <head>
        <title>Oops</title>
        <Meta />
        <Links />
      </head>
      <body>
        {isRouteErrorResponse(error)
          ? <h1>{error.status} {error.statusText}</h1>
          : <h1>Application Error</h1>}
        <Scripts />
      </body>
    </html>
  );
}
```

Because the root `ErrorBoundary` replaces the **entire** document (not just the `<Outlet />` slot), it must render its own `<html>`, `<head>`, `<body>`, and the document elements — otherwise the error page has no styles, no scripts, and no scroll restoration.

## Layout Wrapper for `<head>` Reuse

To avoid duplicating the `<html>` shell between `App` and `ErrorBoundary`, extract a `Layout` component:

```tsx
function Document({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <Meta />
        <Links />
      </head>
      <body>
        {children}
        <ScrollRestoration />
        <Scripts />
        <LiveReload />
      </body>
    </html>
  );
}

export default function App() {
  return <Document><Outlet /></Document>;
}

export function ErrorBoundary() {
  const error = useRouteError();
  return <Document>{/* error UI */}</Document>;
}
```

## Common Mistakes

- **Missing `<Scripts />`**: App renders but never hydrates — feels like SSR-only.
- **`<ScrollRestoration />` after `<Scripts />`**: Hydration order can clobber scroll restore. Put `<ScrollRestoration />` first.
- **Conditionally rendering `<LiveReload />`**: Unnecessary — it no-ops in production. Just ship it.
- **`ErrorBoundary` without the document shell**: Error page renders unstyled and unhydrated.
- **Importing from `react-router-dom`**: Use `@remix-run/react` — the Remix re-export includes the loader/action wiring; the raw router package does not.
