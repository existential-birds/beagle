# Root Shell Smells (`app/root.tsx`)

`app/root.tsx` owns the entire document. The six elements (`<Meta />`, `<Links />`, `<Outlet />`, `<ScrollRestoration />`, `<Scripts />`, and `<LiveReload />` for Classic Compiler only) are load-bearing. Each smell below is a missing or misplaced shell element that breaks a documented Remix feature.

See [remix-v2-routing root.md](../../remix-v2-routing/references/root.md) for the canonical scaffold and the `Layout` export pattern.

---

## Missing `<Meta />` in `<head>`

**Pattern**: `app/root.tsx` renders a `<head>` block without `<Meta />`.

```tsx
// app/root.tsx — smell
export default function App() {
  return (
    <html lang="en">
      <head>
        <title>My App</title>
        <Links />
      </head>
      <body>{/* ... */}</body>
    </html>
  );
}
```

**Why bad**: Without `<Meta />`, every `meta` export from descendant routes is silently dropped. `<title>`, `og:`, `twitter:`, viewport, and description tags from route modules never reach the document.

**Fix**: Add `<Meta />` to `<head>` (it may sit alongside hand-written tags).

---

## Missing `<Links />` in `<head>`

**Pattern**: `app/root.tsx` omits `<Links />`.

**Why bad**: Stylesheet, preload, and icon `links` exports from descendant routes never render. CSS doesn't reach the browser, and the page flashes unstyled or never styles at all.

**Fix**: Include `<Links />` in `<head>`.

---

## Missing `<Scripts />` in `<body>`

**Pattern**: `app/root.tsx` renders without `<Scripts />`.

**Why bad**: The Remix runtime and route-module bundles never load. Server HTML renders, but the app never hydrates — no client loaders, no client actions, no SPA navigation, no prefetch. Forms still submit because the browser handles them natively, but everything Remix-specific is dead.

**Fix**: Include `<Scripts />` in `<body>`, after `<Outlet />` and `<ScrollRestoration />`.

---

## Missing `<ScrollRestoration />`

**Pattern**: `app/root.tsx` omits `<ScrollRestoration />` (or places it *after* `<Scripts />`).

**Why bad**: Back/forward navigation doesn't restore scroll. New navigations don't reset to top. Placing it after `<Scripts />` lets hydration clobber the scroll-restore script. Place it before `<Scripts />`.

**Fix**: First element in `<body>` after `<Outlet />`, before `<Scripts />`.

---

## Conditional `<LiveReload />` (Classic Compiler vs Vite)

**Pattern A — Classic Compiler, conditionally rendered**: `{process.env.NODE_ENV === "development" && <LiveReload />}`.

**Why bad**: `<LiveReload />` already no-ops in production. The conditional is dead weight and signals the author doesn't trust the framework.

**Fix (Classic Compiler)**: Render `<LiveReload />` unconditionally.

**Pattern B — Vite plugin, `<LiveReload />` still rendered**: The project uses `@remix-run/dev/vite` (default for new v2 apps) and `app/root.tsx` still imports and renders `<LiveReload />`.

**Why bad**: `<LiveReload />` is for the Classic Compiler only. Vite has its own HMR and the Remix element is dead weight (or a runtime warning) under Vite.

**Fix (Vite)**: Delete the `LiveReload` import and the `<LiveReload />` element entirely.

See [routing/references/root.md](../../remix-v2-routing/references/root.md) for the Vite-vs-Classic-Compiler split.

---

## Root `ErrorBoundary` without document shell

**Pattern**: An `ErrorBoundary` export in `app/root.tsx` that returns a bare fragment or `<div>`.

```tsx
// app/root.tsx — smell
export function ErrorBoundary() {
  const error = useRouteError();
  return <h1>Application Error</h1>;
}
```

**Why bad**: The root `ErrorBoundary` replaces the **entire** document (it is not mounted inside `<Outlet />`). Without `<html>`, `<head>`, `<body>`, `<Meta />`, `<Links />`, `<Scripts />`, and `<ScrollRestoration />`, the error page renders unstyled, unhydrated, and without the document shell — often as a stark white page with raw text.

**Fix**: Return the full document, or use the `Layout` export pattern (Remix >= 2.4) so `Layout` wraps `ErrorBoundary` automatically. See [routing/references/root.md](../../remix-v2-routing/references/root.md#layout-export-remix-v2--24).

---

## Verification

For each root-shell finding:

1. Quote the missing/misplaced element from `app/root.tsx`.
2. Confirm the project's compiler — Classic vs Vite — by checking `vite.config.ts` or `remix.config.js`. `<LiveReload />` is correct on Classic and wrong on Vite; do not flag without confirming.
3. Confirm Remix version. The `Layout` export is >= 2.4; on older versions the hand-rolled `Document` wrapper is the correct fix.
4. For `ErrorBoundary` flags, confirm the boundary actually returns a fragment / partial DOM, not a full document.
