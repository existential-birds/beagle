# `links` Export — Preloading and Image Notes

The `links` export injects `<link>` tags into the document `<head>`. It's the canonical way to preload critical assets (fonts, CSS), prefetch next-page assets, and set page-level resource hints (`dns-prefetch`, `preconnect`).

## `LinksFunction` shape

```tsx
import type { LinksFunction } from "@remix-run/node";
import interVar from "~/fonts/InterVariable.woff2";
import appStyles from "~/styles/app.css?url";

export const links: LinksFunction = () => [
  // Preload a variable font — must be `crossOrigin: "anonymous"` for woff2 in most setups
  {
    rel: "preload",
    as: "font",
    type: "font/woff2",
    href: interVar,
    crossOrigin: "anonymous",
  },
  // Stylesheet
  { rel: "stylesheet", href: appStyles },
  // Favicon
  { rel: "icon", href: "/favicon.png", type: "image/png" },
  // Resource hint for an external API
  { rel: "preconnect", href: "https://api.example.com" },
  // Page link descriptor — Remix expands into the right prefetch tags
  { page: "/dashboard" },
];
```

Each entry is either an `HtmlLinkDescriptor` (standard `<link>` tag attributes) or a `PageLinkDescriptor` (`{ page: "/path" }`).

## Asset preload patterns

### Preload critical font

```tsx
{
  rel: "preload",
  as: "font",
  type: "font/woff2",
  href: interVar,
  crossOrigin: "anonymous",
}
```

Preloading fonts that are used immediately in the initial render eliminates the font-swap flash. Only preload fonts that are **actually used above the fold** — preloading an unused weight is wasted bandwidth.

### Stylesheet

```tsx
{ rel: "stylesheet", href: appStyles }
```

Use `?url` import (`import appStyles from "~/styles/app.css?url"`) to get a hashed URL pointing at the built CSS file.

### Resource hints

```tsx
// Just resolves DNS — cheap, useful when you'll connect later
{ rel: "dns-prefetch", href: "https://api.example.com" }

// Resolves DNS + opens TCP + TLS — more expensive, do this for hostnames
// you know you'll connect to during initial render
{ rel: "preconnect", href: "https://api.example.com" }
```

Don't `preconnect` to more than 3-4 hosts; it costs sockets.

### Page link descriptor

```tsx
{ page: "/dashboard" }
```

Remix expands this into the right combination of `<link rel="prefetch">` and `<link rel="modulepreload">` tags for the route's data, JS, and CSS. Equivalent to a `<PrefetchPageLinks page="/dashboard" />` but at the route's link level — fires on render of the route that exports it.

## Nested route inheritance

The `links` exports from every matched route in the route tree are **concatenated** into the document head. So a layout's `links` provides app-wide assets; a child route's `links` adds page-specific assets without losing the parent's.

```tsx
// app/root.tsx
export const links: LinksFunction = () => [
  { rel: "preload", as: "font", type: "font/woff2", href: interVar, crossOrigin: "anonymous" },
  { rel: "stylesheet", href: appStyles },
];

// app/routes/blog.tsx
export const links: LinksFunction = () => [
  { rel: "stylesheet", href: blogStyles },
];
```

Both stylesheets render in the head on a `/blog/*` route.

## Image handling — there is no built-in optimizer

Remix v2 has **no built-in image optimizer**, unlike Next.js. You're responsible for serving correctly sized images. Options:

- Process at build time with `sharp`, `unpic`, or `remix-image`.
- Use a third-party CDN with image transforms (Cloudinary, imgix, Cloudflare Images).
- Pre-render multiple sizes and use `<picture>` / `srcset`.

Two rules that apply regardless of how you serve images:

**1. Always set `width` and `height`.** Reserves layout space, eliminates Cumulative Layout Shift (CLS).

```tsx
<img src="/hero.jpg" alt="..." width={1200} height={800} />
```

**2. Use `loading="lazy"` for below-the-fold images.** Native browser lazy-loading; no JS required.

```tsx
<img src="/below-fold.jpg" alt="..." width={800} height={600} loading="lazy" />
```

Don't `loading="lazy"` above-the-fold images — they're needed for LCP, lazy-loading delays them.

## Common mistakes

- **Preloading a font that's not used above the fold** — wasted bandwidth, the file downloads but the user never sees it before the page is interactive.
- **Forgetting `crossOrigin: "anonymous"` on font preload** — browser issues the preload, then a second request for the actual font use because the credentials mode doesn't match.
- **Preloading every CSS file** — bundle the critical CSS into a single file, preload that one.
- **Image tag with no `width`/`height`** — layout shift, poor CLS score.
- **`loading="lazy"` on the hero image** — slows LCP.
- **Preconnecting to 10+ hosts** — opens too many sockets, may starve the connections you actually need.

## Resource hint cheat sheet

| Hint | Cost | When to use |
|---|---|---|
| `dns-prefetch` | Resolves DNS | Hostnames you might use later (analytics, fallback API) |
| `preconnect` | DNS + TCP + TLS handshake | Hostnames you definitely use during initial render |
| `prefetch` | Full resource download, low priority | Resources for the next page |
| `preload` | Full resource download, high priority | Resources used in current render but discovered late by the browser (fonts referenced in CSS, hero image referenced in inline style) |
| `modulepreload` | Module + dependency graph fetch | JS modules used in current render |
