# Caching Headers Review

Anti-patterns in the `headers` route export and `Cache-Control` policy.

## What to flag

### 1. Route serves data but exports no `headers` function

The default Remix response carries no `Cache-Control` — CDN cache is effectively off and every navigation hits origin. Make caching a deliberate decision per route, even when the answer is "do not cache."

**Bad:**
```tsx
// app/routes/blog.$slug.tsx
export async function loader({ params }: LoaderFunctionArgs) {
  return json(await cms.getPost(params.slug));
}
// no headers export — silent uncached document
```

**Good:**
```tsx
export const headers: HeadersFunction = ({ loaderHeaders }) => ({
  "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
});
```

**Report as:** `[FILE:LINE] MISSING_HEADERS_EXPORT` — route serves cacheable content but does not declare a cache policy.

### 2. Child route omits `headers`, parent's policy silently drops

In Remix v2 only the **deepest matched route's** `headers` function runs. If the child route does not export one, the parent's headers are NOT inherited — they are dropped. The route ends up with no cache headers at all, defeating the parent's policy without an error.

**Bad:**
```tsx
// app/routes/_layout.tsx
export const headers: HeadersFunction = () => ({
  "Cache-Control": "public, max-age=300, s-maxage=3600",
});

// app/routes/_layout.dashboard.tsx
export async function loader() { return json({ user: await getUser() }); }
// no headers export — parent's Cache-Control is dropped, not inherited
```

**Good (define on leaf):**
```tsx
// app/routes/_layout.dashboard.tsx
export const headers: HeadersFunction = () => ({
  "Cache-Control": "private, no-store",
});
```

**Report as:** `[FILE:LINE] CHILD_DROPS_PARENT_HEADERS` — child route lacks `headers` export; parent's `Cache-Control` is silently discarded.

**Verify before flagging:** confirm a parent route in the matched chain actually exports `headers` (grep the route tree for `export const headers` or `export function headers`).

### 3. `Cache-Control: public` on an auth'd or personalized response

`public` allows shared caches (CDNs, corporate proxies) to store and serve the response to other users. On any response that varies by user — dashboards, account pages, anything reading session — this leaks one user's HTML to others.

**Bad:**
```tsx
export const headers: HeadersFunction = () => ({
  "Cache-Control": "public, max-age=300", // dashboard data!
});
```

**Good:**
```tsx
export const headers: HeadersFunction = () => ({
  "Cache-Control": "private, max-age=0, must-revalidate",
});
```

**Report as:** `[FILE:LINE] PUBLIC_CACHE_ON_AUTH_ROUTE` — `public` directive on a route that reads session/user data.

**Verify before flagging:** check that the loader actually reads session/user state (look for `getSession`, `requireUserId`, `authenticator.isAuthenticated`, cookie-keyed reads).

### 4. Missing `Vary: Cookie` when caching cookie-dependent responses

If the response body changes based on a cookie (e.g. theme preference, session, feature flag) and the CDN caches it, every visitor sees the first cached variant. `Vary: Cookie` tells the cache to key on the cookie header.

**Bad:**
```tsx
export const headers: HeadersFunction = () => ({
  "Cache-Control": "public, max-age=60, s-maxage=3600",
  // no Vary — CDN caches one variant for everyone
});
```

**Good:**
```tsx
export const headers: HeadersFunction = () => ({
  "Cache-Control": "public, max-age=60, s-maxage=3600",
  "Vary": "Cookie",
});
```

**Report as:** `[FILE:LINE] MISSING_VARY_COOKIE` — cacheable response varies by cookie but `Vary: Cookie` is not set.

Note: `Vary: Cookie` is coarse — most CDNs treat any cookie change as a cache miss. Prefer a narrow custom header (e.g. `Vary: X-Theme`) plus an edge function that normalizes the cookie to that header, if CDN cache hit rate matters.

### 5. `Set-Cookie` returned alongside `Cache-Control: public`

Most CDNs refuse to cache responses that carry a `Set-Cookie` header. Fastly and Cloudflare strip it silently; some CDNs cache the cookie itself, which is worse — every visitor gets the first user's session.

**Bad:**
```tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const session = await getSession(request);
  session.set("lastVisit", Date.now());
  return json(data, {
    headers: {
      "Cache-Control": "public, max-age=300",
      "Set-Cookie": await commitSession(session),
    },
  });
}
```

**Good:** keep cookie-setting in actions; loaders should be cookie-free:
```tsx
// loader: no cookie
export async function loader({ request }: LoaderFunctionArgs) {
  return json(await getData(request), {
    headers: { "Cache-Control": "public, max-age=300" },
  });
}
```

**Report as:** `[FILE:LINE] SET_COOKIE_WITH_PUBLIC_CACHE` — loader sets a cookie and declares `public` caching; CDN will either drop the cache or leak the cookie.

### 6. Document `headers` not forwarded from loader

The `headers` export controls the **document** response. The loader's `Cache-Control` controls the **data** response (the `?_data=` JSON fetched on client navigation). These are two separate caches. If the `headers` export does not forward `loaderHeaders`, the document is uncached even when the loader said `public, s-maxage=3600`.

**Bad:**
```tsx
export async function loader() {
  return json(data, {
    headers: { "Cache-Control": "public, s-maxage=3600" },
  });
}

export const headers: HeadersFunction = () => ({
  // forgot to forward — document is uncached
});
```

**Good:**
```tsx
export const headers: HeadersFunction = ({ loaderHeaders }) => ({
  "Cache-Control": loaderHeaders.get("Cache-Control") ?? "no-store",
});
```

**Report as:** `[FILE:LINE] DOCUMENT_HEADERS_NOT_FORWARDED` — loader sets `Cache-Control` but document `headers` export does not forward it.

### 7. Child route widens parent's cache policy

When merging in a child, pick the **smaller** `max-age` / `s-maxage`. A child that widens the parent's policy can cause stale data to be served beyond what the parent expected.

**Bad:**
```tsx
// parent: max-age=60
// child:
export const headers: HeadersFunction = () => ({
  "Cache-Control": "public, max-age=3600", // wider than parent
});
```

**Good:** take the minimum:
```tsx
export const headers: HeadersFunction = ({ loaderHeaders, parentHeaders }) => {
  const loader = parseCacheControl(loaderHeaders.get("Cache-Control"));
  const parent = parseCacheControl(parentHeaders.get("Cache-Control"));
  const maxAge = Math.min(loader["max-age"] ?? 0, parent["max-age"] ?? 0);
  return { "Cache-Control": `private, max-age=${maxAge}` };
};
```

**Report as:** `[FILE:LINE] CHILD_WIDENS_PARENT_CACHE` — child route's `max-age` exceeds parent's.

### 8. Missing `Save-Data` consideration on heavy responses

Clients on metered connections send `Save-Data: on`. Responses that bundle large payloads (images, video poster frames, analytics scripts) should branch on this header to return lighter variants. Not strictly a bug; flag only on routes that ship measurably heavy payloads.

**Suggested pattern:**
```tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const saveData = request.headers.get("Save-Data") === "on";
  const data = saveData ? await getLightVariant() : await getFullVariant();
  return json(data, { headers: { "Vary": "Save-Data" } });
}
```

**Report as:** `[FILE:LINE] MISSING_SAVE_DATA_BRANCH` — heavy response does not honor `Save-Data` hint.

## Verify before flagging

- For "missing `headers` export," confirm the route is not in a path explicitly marked uncacheable (auth area, admin area). Look for an enclosing layout that returns `no-store`.
- For "child drops parent headers," walk the route file tree and confirm a parent actually exports `headers`. If none does, the issue is "no caching configured" — a softer finding.
- For "`public` on auth'd route," confirm the loader reads session state. A route that happens to be under an auth layout but reads only public data may legitimately use `public`.
- For "missing `Vary: Cookie`," confirm the response body branches on a cookie. If the loader is cookie-independent (or short-circuits to a redirect when unauth'd), `Vary: Cookie` is not required.
- For "`Set-Cookie` + `public`," confirm both are set on the same response. A loader that conditionally sets the cookie only on first visit, with a redirect, is fine.

## Verbatim quote requirements

Findings on this surface require a verbatim quote of:
- the `headers` export (or its absence — quote the route module's exports and note the omission), AND
- the `Cache-Control` string (or `Set-Cookie`, `Vary`) being flagged.

A finding like "this route is missing a `headers` export" with no path or quote is not reportable.
