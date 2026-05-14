# Assets, Images, Fonts & CSS Review

Anti-patterns in `dangerouslySetInnerHTML`, image attributes, `links` preload, and stylesheet placement.

## What to flag

### 1. `dangerouslySetInnerHTML` with untrusted content

The literal definition of an XSS sink. Even "trusted" data fails: `JSON.stringify` does **not** escape `</script>` or U+2028 / U+2029 line separators, so an object containing the literal substring `</script>` breaks out of the script context.

**Bad (untrusted):**
```tsx
<div dangerouslySetInnerHTML={{ __html: post.body }} /> // user-authored content
```

**Bad (trusted but unsafe encoding):**
```tsx
<script
  dangerouslySetInnerHTML={{
    __html: `window.ENV = ${JSON.stringify(data.ENV)}`, // </script> in data breaks out
  }}
/>
```

**Good (sanitize untrusted HTML):**
```tsx
import sanitize from "isomorphic-dompurify";

<div dangerouslySetInnerHTML={{ __html: sanitize(post.body) }} />
```

**Good (serialize JS safely):**
```tsx
import serialize from "serialize-javascript";

<script
  dangerouslySetInnerHTML={{
    __html: `window.ENV = ${serialize(data.ENV, { isJSON: true })}`,
  }}
/>
```

**Report as:** `[FILE:LINE] UNSAFE_INNER_HTML` — `dangerouslySetInnerHTML` with untrusted input or `JSON.stringify` for script injection.

### 2. Below-the-fold images missing `loading="lazy"`

Without `loading="lazy"`, every `<img>` is fetched immediately on parse, bloating the critical path. For images below the fold (testimonials, footer logos, gallery items beyond initial viewport), this is wasted bandwidth and delayed LCP.

**Bad:**
```tsx
<img src="/screenshots/feature.png" alt="Feature screenshot" />
{/* in a section below the hero */}
```

**Good:**
```tsx
<img
  src="/screenshots/feature.png"
  alt="Feature screenshot"
  loading="lazy"
  decoding="async"
  width="1200"
  height="630"
/>
```

**Report as:** `[FILE:LINE] MISSING_LOADING_LAZY` — `<img>` rendered below the fold without `loading="lazy"`.

**Do not flag:**
- Above-the-fold images (hero, logo in header) — they should NOT be lazy
- Images marked `fetchpriority="high"`
- `<img>` inside `<picture>` where the `<picture>` source set is intentionally eager

### 3. Images missing `width` and `height` attributes

Without explicit dimensions, the browser reserves zero space until the image loads, causing layout shift (CLS hit). Set the intrinsic dimensions (the file's actual width/height in pixels), even when the CSS resizes the image.

**Bad:**
```tsx
<img src="/avatar.png" alt="" className="w-12 h-12 rounded-full" />
```

**Good:**
```tsx
<img
  src="/avatar.png"
  alt=""
  width="48"
  height="48"
  className="w-12 h-12 rounded-full"
/>
```

**Report as:** `[FILE:LINE] MISSING_IMG_DIMENSIONS` — `<img>` rendered without `width` and `height` attributes.

**Do not flag:** images sized via CSS aspect-ratio with explicit `style={{ aspectRatio: "16/9" }}` and `width="100%"` — that's an alternative CLS-safe pattern.

### 4. Critical fonts/CSS not preloaded via `links` export

`<link rel="preload">` for the document font and the route-critical CSS gets them on the wire during the HTML parse phase, ahead of when the layout engine discovers them. Without preload, fonts arrive late and the page either FOUTs (flash of unstyled text) or FOITs (flash of invisible text).

**Bad (no preload):**
```tsx
// app/root.tsx
export const links: LinksFunction = () => [
  { rel: "stylesheet", href: appStyles },
];
```

**Good:**
```tsx
import interVar from "~/fonts/InterVariable.woff2";
import appStyles from "~/styles/app.css?url";

export const links: LinksFunction = () => [
  // Preload critical font BEFORE the stylesheet so the browser knows it's needed
  {
    rel: "preload",
    as: "font",
    type: "font/woff2",
    href: interVar,
    crossOrigin: "anonymous", // required for cross-origin / signed-URL fonts
  },
  { rel: "stylesheet", href: appStyles },
];
```

**Report as:** `[FILE:LINE] MISSING_CRITICAL_PRELOAD` — root or route-critical font/CSS loaded without an accompanying `rel="preload"` link.

**Do not flag:** preload omission on a route that uses only system fonts (no custom font file).

### 5. `<link rel="stylesheet">` injected in body instead of `links` export

Stylesheets injected inside the document body (typically via `<link>` rendered in a component) ship after parse begins, causing FOUC and re-layout. Remix routes a stylesheet through the `links` export so it lands in the document `<head>` during SSR.

**Bad:**
```tsx
export default function Page() {
  return (
    <>
      <link rel="stylesheet" href="/styles/page.css" />
      <Content />
    </>
  );
}
```

**Good:**
```tsx
import pageStyles from "~/styles/page.css?url";

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: pageStyles },
];

export default function Page() {
  return <Content />;
}
```

**Report as:** `[FILE:LINE] STYLESHEET_IN_BODY` — `<link rel="stylesheet">` rendered inside a component body instead of via the `links` export.

### 6. Missing `crossOrigin` on font preload

Fonts are always fetched in CORS mode (per the Fetch spec). A preload without `crossOrigin="anonymous"` is treated as a separate request from the font's actual load — so the preload is wasted and the font is fetched twice.

**Bad:**
```tsx
{ rel: "preload", as: "font", type: "font/woff2", href: interVar }
```

**Good:**
```tsx
{
  rel: "preload",
  as: "font",
  type: "font/woff2",
  href: interVar,
  crossOrigin: "anonymous",
}
```

**Report as:** `[FILE:LINE] FONT_PRELOAD_MISSING_CROSSORIGIN` — font preload without `crossOrigin="anonymous"`.

### 7. Missing `decoding="async"` on large images

`decoding="async"` lets the browser decode the image off the main thread, keeping the interaction-ready threshold (FID/INP) tighter on image-heavy pages.

**Suggested pattern:**
```tsx
<img
  src="/hero.jpg"
  alt="Hero"
  width="1600"
  height="900"
  decoding="async"
  fetchPriority="high"
/>
```

**Report as:** `[FILE:LINE] MISSING_DECODING_ASYNC` — large image (>500px on either axis) without `decoding="async"`.

Not a high-severity issue; flag only on hero / gallery / above-the-fold images.

## Verify before flagging

- For "below-the-fold image without `loading=lazy`," confirm the image is actually below the fold. Hero images, logos, anything in the header should NOT be lazy. When unsure, check the JSX hierarchy and CSS — an image inside a `<header>` or above any `<main>` content is likely above the fold.
- For "missing `width`/`height`," confirm the project does NOT use a build-time image processor (`unpic`, `remix-image`, `sharp`-via-loader) that injects dimensions. If the project has a wrapper component, defer to that.
- For "missing critical preload," confirm the project uses a custom font file (look in `~/fonts/` or `app/fonts/`). System-font-only projects don't need font preload.
- For "stylesheet in body," confirm the `<link>` is inside a default-exported component (rendered into body), not inside `<head>` via a `Layout` component or `<Meta>`/`<Links>` placeholders.
- For "unsafe innerHTML," confirm the data flowing in is genuinely untrusted (user input, CMS body, markdown) or genuinely unsafe-encoded (`JSON.stringify` in a `<script>`). HTML built from compile-time constants is fine.

## Verbatim quote requirements

Findings on this surface require a verbatim quote of:
- the `<img>` / `<link>` / `dangerouslySetInnerHTML` JSX being flagged, AND
- the surrounding context (above/below fold, inside `links` export vs component body, trusted vs untrusted data source).

A finding like "images here need lazy loading" with no JSX or fold context is not reportable.
