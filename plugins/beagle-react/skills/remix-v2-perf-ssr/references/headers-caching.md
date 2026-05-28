# HTTP Caching with the `headers` Route Export

Remix v2 has no built-in framework cache. All caching is plain HTTP, which means the `headers` route export and the loader's response headers are the only knobs — and they control two different responses.

## Two cache scopes per route

Every Remix route serves two response types:

1. **Document response** — full server-rendered HTML, returned on hard navigations and initial loads. `Cache-Control` here comes from the route's `headers` export.
2. **Data response** — JSON returned for `?_data=` requests on client-side navigations. `Cache-Control` here comes from the headers on the `Response`/`json()` the loader returns.

They can and usually should differ. A long-form blog post might cache the document for 1 hour at the CDN but cache the data for 5 minutes — so client-side navigations re-fetch sooner while reused HTML stays cheap.

## `HeadersFunction` signature

```tsx
import type { HeadersFunction } from "@remix-run/node";

export const headers: HeadersFunction = ({
  loaderHeaders,   // Headers from the loader's Response
  parentHeaders,   // Headers the parent route would have sent
  actionHeaders,   // Headers from the action's Response (if this was a POST)
  errorHeaders,    // Headers from the boundary, when an error renders
}) => {
  return {
    "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
  };
};
```

All four `*Headers` properties are `Headers` instances — use `.get(key)`, `.has(key)`, `.entries()`. The return value can be a `Headers`, a `HeadersInit`, or a plain object.

## Stale-While-Revalidate (SWR) pattern

```tsx
import type { HeadersFunction, LoaderFunctionArgs } from "@remix-run/node";
import { json } from "@remix-run/node";

export async function loader({ params }: LoaderFunctionArgs) {
  const post = await cms.getPost(params.slug);
  return json(post, {
    headers: {
      "Cache-Control":
        "public, max-age=60, s-maxage=3600, stale-while-revalidate=86400",
    },
  });
}

export const headers: HeadersFunction = ({ loaderHeaders }) => ({
  "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
});
```

Directive cheat sheet:

| Directive | Audience | Effect |
|---|---|---|
| `max-age=N` | browser + CDN | Fresh for N seconds. CDN obeys unless `s-maxage` overrides. |
| `s-maxage=N` | CDN only | Fresh for N seconds at the shared cache; overrides `max-age` there. |
| `stale-while-revalidate=N` | CDN | After freshness expires, serve stale for up to N more seconds while refreshing in background. |
| `public` | both | Cacheable by shared caches. **Refused by most CDNs if `Set-Cookie` is present**. |
| `private` | browser only | Per-user; CDN must not cache. |
| `no-store` | both | Never cache. Use for personalized data. |

## Parent/child merge — the notorious gotcha

**Default behavior: only the deepest matched route's `headers` runs.** If a leaf route has no `headers` export, Remix walks up to the nearest ancestor that does. This is the biggest source of cache misconfiguration in Remix v2 apps.

Concrete failure mode:

```tsx
// app/routes/_layout.tsx — parent layout
export const headers: HeadersFunction = () => ({
  "Cache-Control": "public, max-age=300, s-maxage=3600",
});

// app/routes/_layout.dashboard.tsx — child renders per-user data
// NO headers export!
export async function loader({ request }: LoaderFunctionArgs) {
  const user = await requireUser(request);
  return json({ user, balance: await getBalance(user.id) });
}
```

Result: the dashboard HTML — which contains user-specific data — gets cached at the CDN for an hour with the parent's `public, s-maxage=3600` headers, and **every visitor sees the first cache fill's data**. Severe data-leak bug.

### Two defenses

**1. Leaf-only headers (recommended):**
Never export `headers` from layout/parent routes. Only leaves declare caching policy. Every personalized route then defaults to `no-store` if you forget — failing closed, not open.

**2. Defensive merging in the child:**
If a parent must set headers, every child must explicitly merge — picking the most conservative (smallest `max-age`, `private` over `public`):

```tsx
import type { HeadersFunction } from "@remix-run/node";
import { parseCacheControl } from "~/utils/cache";

export const headers: HeadersFunction = ({ loaderHeaders, parentHeaders }) => {
  const loader = parseCacheControl(loaderHeaders.get("Cache-Control"));
  const parent = parseCacheControl(parentHeaders.get("Cache-Control"));

  // Never widen a parent's caching policy from a child
  const maxAge = Math.min(loader["max-age"] ?? 0, parent["max-age"] ?? 0);

  return {
    "Cache-Control": `private, max-age=${maxAge}`,
  };
};
```

## When `headers` runs

| Trigger | Source headers passed |
|---|---|
| GET on the leaf route | `loaderHeaders`, `parentHeaders` |
| POST/PUT/PATCH/DELETE | `actionHeaders`, `loaderHeaders` (post-action loader run), `parentHeaders` |
| Error boundary rendered | `errorHeaders`, `parentHeaders` |
| Resource route | The route's `headers` export does NOT run — set headers directly on the loader's `Response`. |

## Combining with `Set-Cookie`

CDNs refuse to cache responses with `Set-Cookie` when `Cache-Control` is `public`. Two safe shapes:

```tsx
// Shape A: cookie-setting loader returns private/no-store
return json(data, {
  headers: {
    "Set-Cookie": await commitSession(session),
    "Cache-Control": "private, no-store",
  },
});

// Shape B: move cookie-setting into the action, keep loaders cookie-free
// so loaders can return public caching headers safely.
```

## `Vary` header

When response varies by `Accept-Language`, `Cookie`, or `Accept`, declare it explicitly so the CDN keys its cache entries correctly:

```tsx
export const headers: HeadersFunction = ({ loaderHeaders }) => ({
  "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
  Vary: "Accept-Language",
});
```

Be conservative with `Vary` — high cardinality (e.g. `Vary: User-Agent`) destroys hit rate.

## Debugging

- Production CDN logs are the source of truth. Don't trust dev — most local servers don't apply `Cache-Control`.
- Check both response types: `curl -I https://site.com/page` for the document, `curl -I 'https://site.com/page?_data=routes/page'` for the data.
- `Cache-Status` and `Age` response headers from your CDN tell you HIT/MISS and how long the entry has been cached.

## When to return `no-store`

- Authentication callback routes
- Routes that show user-specific data (account, dashboard, cart)
- Routes that set/read sensitive cookies
- API/resource routes returning per-request computed values
- Form action POST responses (Remix usually redirects these anyway)

When unsure, return `no-store` and measure. Caching personalized data is a much worse bug than missing a perf win.

## Per-route examples

### Marketing page — long cache, SWR

```tsx
export async function loader() {
  return json(await cms.getPage("home"), {
    headers: {
      "Cache-Control":
        "public, max-age=300, s-maxage=86400, stale-while-revalidate=604800",
    },
  });
}

export const headers: HeadersFunction = ({ loaderHeaders }) => ({
  "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
});
```

The CDN holds the page for a day, serving stale for a week while refreshing in the background. The browser caches for 5 minutes.

### Blog post — moderate cache, SWR

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const post = await cms.getPost(params.slug);
  return json(post, {
    headers: {
      "Cache-Control":
        "public, max-age=60, s-maxage=3600, stale-while-revalidate=86400",
    },
  });
}
```

### Authenticated dashboard — no cache

```tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const user = await requireUser(request);
  return json(
    { user, balance: await getBalance(user.id) },
    {
      headers: { "Cache-Control": "private, no-store" },
    }
  );
}

export const headers: HeadersFunction = () => ({
  "Cache-Control": "private, no-store",
});
```

### API/resource route — JSON with short cache

```tsx
// app/routes/api.products.tsx — resource route, no default component
export async function loader({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const products = await db.getProducts({
    category: url.searchParams.get("category"),
  });
  return json(products, {
    headers: { "Cache-Control": "public, max-age=60, s-maxage=300" },
  });
}
```

Resource routes do not run a `headers` export; set headers on the returned `Response`/`json()` only.

## ETags and conditional requests

For revalidation efficiency, return an `ETag` header. Modern clients send `If-None-Match` on revalidation; if the loader can cheaply check whether the ETag still matches, return `204` to skip the body:

```tsx
import { json } from "@remix-run/node";

export async function loader({ request }: LoaderFunctionArgs) {
  const post = await cms.getPost(params.slug);
  const etag = `"${post.id}-${post.updatedAt}"`;

  if (request.headers.get("If-None-Match") === etag) {
    return new Response(null, { status: 304 });
  }

  return json(post, {
    headers: {
      "Cache-Control": "public, max-age=60, s-maxage=3600",
      ETag: etag,
    },
  });
}
```

ETags are most useful when origin compute is cheap but bandwidth is not.
