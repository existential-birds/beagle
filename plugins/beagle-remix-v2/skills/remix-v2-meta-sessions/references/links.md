# Links Reference

The Remix v2 `links` route export returns an array of `LinkDescriptor`
objects, mirroring the shape of `meta`. `<Links />` (from `@remix-run/react`)
placed inside `<head>` in `root.tsx` aggregates every matched route's links
into the document head.

## Imports

```ts
import type { LinksFunction } from "@remix-run/node";
```

A `LinkDescriptor` is one of two unions:

- `HtmlLinkDescriptor` — fields mirror the `<link>` element. Per Remix v2
  the `rel` type is `LiteralUnion<"alternate" | "dns-prefetch" | "icon" |
  "manifest" | "modulepreload" | "next" | "pingback" | "preconnect" |
  "prefetch" | "preload" | "prerender" | "search" | "stylesheet", string>`
  — any string is accepted at compile time; common non-literal values
  include `canonical` and `apple-touch-icon`. Other fields: `href`, `as`,
  `type`, `media`, `crossOrigin`, `imageSrcSet`, `imageSizes`,
  `integrity`, `disabled`, `hrefLang`.
- `PrefetchPageDescriptor` — `{ page: string }`. Tells Remix to preload the
  module graph and loader data for the given route path.

## Stylesheets

The most common use is route-scoped stylesheets:

```tsx
// app/routes/dashboard.tsx
import type { LinksFunction } from "@remix-run/node";
import dashboardStyles from "~/styles/dashboard.css";

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: dashboardStyles },
];
```

When the user navigates away from `/dashboard`, Remix removes its stylesheet
from the document head. Route-scoped stylesheets prevent CSS bleeding
between unrelated parts of the app.

## Preload, dns-prefetch, preconnect

```tsx
import type { LinksFunction } from "@remix-run/node";

export const links: LinksFunction = () => [
  { rel: "dns-prefetch", href: "https://cdn.example.com" },
  { rel: "preconnect", href: "https://cdn.example.com", crossOrigin: "anonymous" },
  {
    rel: "preload",
    as: "image",
    href: "/img/hero.jpg",
    imageSrcSet: "/img/hero-sm.jpg 480w, /img/hero-lg.jpg 1200w",
    imageSizes: "(max-width: 600px) 480px, 1200px",
  },
];
```

`imageSrcSet` and `imageSizes` mirror the responsive-image attributes from
`<img srcset>` / `<img sizes>`; together they let the browser pick the
right asset to preload for the current viewport.

## Page Preloads

`PrefetchPageDescriptor` triggers a module and loader-data preload for a route
the user is likely to visit:

```tsx
export const links: LinksFunction = () => [
  { page: "/dashboard" },
];
```

Use sparingly — every preloaded page fires its loaders. Reserve for
genuinely likely next-clicks (a marketing page that almost always leads to
`/signup`, for example).

## Canonical and Alternate

While `tagName: "link"` inside the `meta` export can emit `<link>`
elements, dedicated SEO-stable links (canonical, alternate) live better in
`links`:

```tsx
export const links: LinksFunction = () => [
  { rel: "canonical", href: "https://example.com/posts/intro" }, // canonical is not in the literal union; accepted via the open-string fallback
  { rel: "alternate", hrefLang: "fr", href: "https://example.com/fr/posts/intro" },
];
```

Per-request canonical URLs (those that depend on the request URL) still
belong in the `meta` export via `{ tagName: "link", rel: "canonical" }` so
they can read `location` and `data`.

## Favicons and Icons

```tsx
export const links: LinksFunction = () => [
  { rel: "icon", href: "/favicon.svg", type: "image/svg+xml" },
  { rel: "apple-touch-icon", href: "/apple-touch-icon.png" },
];
```

These typically live in `root.tsx`'s `links` export so they appear on
every page.

## Parent Aggregation Behavior

Unlike `meta`, `<Links />` **does** aggregate across the matched route
tree. Every matched route contributes its `links` descriptors to the
document head; on navigation, Remix removes the ones from routes that
are no longer matched.

This is the behavior most developers expect for stylesheets: the root
stylesheet stays, the dashboard stylesheet appears when you navigate to
`/dashboard`, and it disappears when you leave.

## Root Document Scaffolding

```tsx
// app/root.tsx
import { Links, LiveReload, Meta, Outlet, Scripts, ScrollRestoration } from "@remix-run/react";
import type { LinksFunction } from "@remix-run/node";
import globalStyles from "~/styles/global.css";

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: globalStyles },
  { rel: "icon", href: "/favicon.svg", type: "image/svg+xml" },
];

export default function App() {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
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

If `<Links />` is omitted from `<head>`, no stylesheets load and no preload
hints fire — the symptom is "css is broken in production" with no errors
in the console.
