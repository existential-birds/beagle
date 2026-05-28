# Prefetching with `<Link>` and `<PrefetchPageLinks>`

Remix's prefetch turns `<Link>` into a portal that fetches the target route's data, JS modules, and CSS **before** the user clicks — so the navigation feels instant. The mechanism is browser-native: Remix inserts `<link rel="prefetch">` tags as siblings of the anchor.

## `<Link prefetch>` modes

```tsx
import { Link } from "@remix-run/react";

<Link to="/dashboard" prefetch="none">    // default — never prefetch
<Link to="/dashboard" prefetch="intent">  // fires on hover/focus
<Link to="/dashboard" prefetch="render">  // fires when the link renders
<Link to="/dashboard" prefetch="viewport"> // fires when scrolled into view
```

| Mode | Trigger | Use for |
|---|---|---|
| `"none"` | Never | Sensitive links (logout), mutation-triggering loaders, analytics-instrumented routes |
| `"intent"` | Hover or focus | Default for nav menus, content cards, anywhere user hover signals intent |
| `"render"` | Immediately, when the link enters the React tree | Above-the-fold critical "next click" (e.g. paginated next-page button) |
| `"viewport"` | When the link scrolls into view (IntersectionObserver) | Long lists, infinite scrolls — prefetch only what's seen |

## When prefetch is harmful

- **Loaders with side effects** — page-view analytics, view counters, mutation-triggering reads. Hover-prefetch inflates the count. Either move side effects out of the loader (do them in an `action` or a separate beacon endpoint), or set `prefetch="none"` on those links.
- **`prefetch="render"` on a 200-row table** — each row fires a prefetch immediately. Network thrash, wasted bandwidth, possible upstream rate-limit hits. Use `"intent"` or `"viewport"` for long lists.
- **Logout / destructive routes** — even if the loader is GET-safe, hover-prefetch is wasted work and may show up in logs as suspicious traffic. Use `prefetch="none"`.
- **Routes behind paywalls** — prefetching content the user isn't entitled to load wastes server CPU; gate at the loader anyway, but skip prefetch.

## The double-data-request gotcha

When the user hovers a link with `prefetch="intent"`, the browser issues a prefetch request for the route's data. If the loader response has no `Cache-Control` header, the browser **does not cache the response**. When the user then clicks, the browser fires the **same request again** — defeating the prefetch entirely.

The fix: detect the `Purpose: prefetch` header in the loader and return a short `Cache-Control`:

```tsx
import { json, type LoaderFunctionArgs } from "@remix-run/node";

export async function loader({ request }: LoaderFunctionArgs) {
  const data = await getData(request);

  // Browsers and Remix use several header names for this — check all
  const purpose =
    request.headers.get("Purpose") ||
    request.headers.get("X-Purpose") ||
    request.headers.get("Sec-Purpose") ||
    request.headers.get("Sec-Fetch-Purpose") ||
    request.headers.get("X-Moz");

  const headers = new Headers();
  if (purpose === "prefetch") {
    // Cache just long enough that the click finds a hit
    headers.set("Cache-Control", "private, max-age=10");
  }
  return json(data, { headers });
}
```

Without this header, your CDN logs will show 2x the request count on every prefetched route — easy to miss in dev but obvious in production.

## CSS selector gotcha: `:last-of-type`, not `:last-child`

Remix injects the `<link rel="prefetch">` tags as **siblings** of the `<a>` element. Briefly, those prefetch tags become the last child of the parent — so any CSS rule like `nav a:last-child` momentarily misses its target during prefetch.

```css
/* BROKEN — prefetch tags break this */
nav a:last-child { margin-right: 0; }

/* CORRECT */
nav a:last-of-type { margin-right: 0; }
```

## `<PrefetchPageLinks>` — programmatic prefetch

When you want to prefetch a route without an associated `<Link>` (e.g. the most likely next page based on user behavior), use `<PrefetchPageLinks>`:

```tsx
import { PrefetchPageLinks, useLoaderData } from "@remix-run/react";

export default function ArticleList() {
  const { articles } = useLoaderData<typeof loader>();
  return (
    <>
      {articles.map((a) => <ArticleCard key={a.id} article={a} />)}
      {/* Preload the most likely next page */}
      <PrefetchPageLinks page={`/articles/${articles[0]?.slug}`} />
    </>
  );
}
```

Prefetches data, JS modules, and CSS for the target route.

**Gotcha**: the `page` prop must be an **absolute path** (starts with `/`). Relative paths silently fail — no warning, no prefetch.

```tsx
<PrefetchPageLinks page="articles/foo" />   // BROKEN — silently does nothing
<PrefetchPageLinks page="/articles/foo" />  // works
```

## Decision matrix

| Scenario | Choice |
|---|---|
| Header nav link to a static page | `prefetch="intent"` |
| Header nav link to a logged-out-only page (e.g. `/login` when already logged in) | `prefetch="none"` |
| Logout button | `prefetch="none"` |
| "Next page" pagination button above the fold | `prefetch="render"` |
| Row in a 100+ row table | `prefetch="viewport"` |
| Search result card | `prefetch="intent"` |
| Predictive prefetch (programmatic, no link) | `<PrefetchPageLinks page="/abs" />` |
| Loader has side effects (logs a view, increments a counter) | `prefetch="none"`, or fix the loader |

## Verifying prefetch works

In DevTools Network panel, filter by Initiator → "Other" or look for the `Purpose: prefetch` request header. On hover (with `prefetch="intent"`) you should see the data request fire **once** with `Purpose: prefetch`, then on click **no** additional request (cache hit). If you see two requests, your loader is missing the `Purpose: prefetch` cache header.

## What prefetch actually downloads

When prefetch fires for a route, Remix inserts three categories of `<link>` tags:

1. `<link rel="prefetch" as="fetch" href="/path?_data=routes/path">` — the loader's JSON data.
2. `<link rel="modulepreload" href="/build/routes/path-HASH.js">` — the route's JS module.
3. `<link rel="prefetch" href="/build/routes/path-HASH.css">` — the route's CSS, if any.

All three need cache headers (or browser caching defaults) to be effective. The data request is the most common to misconfigure because the loader controls its `Cache-Control` and most apps default to none.

## Interaction with `headers` export

Prefetch fires `GET` requests with the same headers as a normal navigation, including the `Purpose: prefetch` marker (and friends). Your `headers` export receives them like any other request; you can branch on `Purpose` inside the loader (as shown above), but the `headers` export itself doesn't usually need to differ — the loader's response headers are the lever.

If you cache the data response with a longer `max-age` on prefetch-marked requests than on regular requests, click navigations after a prefetch will reuse the cached entry — exactly what you want. Keep the value small (5-30s) so stale data doesn't outlive its usefulness.

## Mobile and slow networks

On mobile or slow connections, prefetch competes with the resources needed for the current page. Aggressive `prefetch="render"` on many links can starve the critical render path. Two mitigations:

- Use `prefetch="intent"` (only fires on hover/focus, which mobile users rarely trigger casually) for less-likely destinations.
- Use `prefetch="viewport"` for long lists so prefetch only fires for visible rows.

The browser also respects the `Save-Data` request header on metered connections — Remix-injected prefetch tags are still issued, but the browser may skip them. You can also gate prefetch in your own code based on `navigator.connection.effectiveType` if you need finer control.
