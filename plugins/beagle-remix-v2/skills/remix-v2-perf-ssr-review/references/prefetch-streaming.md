# Prefetch & Streaming Review

Anti-patterns in `<Link prefetch>`, `<PrefetchPageLinks>`, `defer()`, `<Await>`, and `<Suspense>`.

## What to flag

### 1. `<Link prefetch="render">` on every link in a long list

`prefetch="render"` fires `<link rel="prefetch">` tags immediately on mount — one data request per link, plus JS and CSS for each target route. On a 200-row table this is 200 simultaneous prefetches: network thrash, wasted bandwidth, possible rate-limit hits.

**Bad:**
```tsx
{rows.map((row) => (
  <Link key={row.id} to={`/products/${row.id}`} prefetch="render">
    {row.name}
  </Link>
))}
```

**Good:** use `intent` (fires on hover) or `viewport` (fires when scrolled in):
```tsx
{rows.map((row) => (
  <Link key={row.id} to={`/products/${row.id}`} prefetch="intent">
    {row.name}
  </Link>
))}
```

**Report as:** `[FILE:LINE] PREFETCH_RENDER_ON_LIST` — `prefetch="render"` applied to a link rendered inside a list / `.map()`.

### 2. `<Link prefetch="intent">` on a link whose loader has side effects

Hover-prefetch fires the target route's loader. If the loader logs an analytics event, increments a counter, or has any side effect, hovering over the link inflates those metrics — and may even trigger work that should only happen on actual navigation.

**Bad:**
```tsx
// app/routes/article.$id.tsx
export async function loader({ params }: LoaderFunctionArgs) {
  await analytics.trackView(params.id); // side effect — fires on hover-prefetch
  return json(await getArticle(params.id));
}

// somewhere else:
<Link to={`/article/${id}`} prefetch="intent">...</Link>
```

**Good options:**
- Move the side effect to an `action` triggered by a beacon
- Detect `Purpose: prefetch` in the loader and skip the side effect:
  ```tsx
  export async function loader({ request, params }: LoaderFunctionArgs) {
    const purpose = request.headers.get("Purpose")
      ?? request.headers.get("Sec-Purpose")
      ?? request.headers.get("X-Purpose");
    if (purpose !== "prefetch") await analytics.trackView(params.id);
    return json(await getArticle(params.id));
  }
  ```
- Set `prefetch="none"` on the link

**Report as:** `[FILE:LINE] PREFETCH_INTENT_TO_SIDE_EFFECT_LOADER` — link with `prefetch="intent"`/`"render"`/`"viewport"` points to a route whose loader has side effects.

### 3. `<PrefetchPageLinks>` to a mutation-triggering route

`<PrefetchPageLinks>` programmatically prefetches data, JS, and CSS for a target route. If that route's loader has any side effect (or worse, if it actually triggers a mutation via redirect / cookie set), the prefetch fires the side effect on render — possibly N times if the component remounts.

**Bad:**
```tsx
<PrefetchPageLinks page="/api/track/view" /> // POST-like loader semantics
```

**Bad:**
```tsx
<PrefetchPageLinks page="/logout" /> // loader signs out, sets cookie
```

**Good:** reserve `<PrefetchPageLinks>` for cacheable read-only routes that the user is highly likely to navigate to next.

**Report as:** `[FILE:LINE] PREFETCH_PAGE_LINKS_TO_SIDE_EFFECT_ROUTE` — `<PrefetchPageLinks>` targets a route with side-effecting loader.

### 4. `defer()` for data that resolves in under ~50ms

Streaming adds protocol overhead: `<script>` tags appended to the HTML stream, an extra render pass for the suspense boundary, a brief flash of the skeleton. For data from in-memory cache or a fast local DB, this is net-negative — TTI worsens.

**Bad:**
```tsx
export async function loader() {
  const cached = inMemoryCache.get("hot-data"); // <1ms
  return defer({ data: Promise.resolve(cached) });
}
```

**Good:** `await` fast data:
```tsx
export async function loader() {
  const data = inMemoryCache.get("hot-data");
  return json({ data });
}
```

**Report as:** `[FILE:LINE] DEFER_ON_FAST_DATA` — `defer()` wraps a promise that resolves synchronously / from in-memory cache / from a sub-50ms call.

**Verify before flagging:** the data has to actually be fast. A `defer` on a cross-region DB call is correct. Look for `await` chains, network requests, or external API calls before flagging this — and prefer a softer "consider awaiting" note when unsure.

### 5. `<Await>` without an enclosing `<Suspense>`

`<Await>` requires a `<Suspense>` boundary to render its fallback. Without one, the throw bubbles up to the route's `ErrorBoundary` (which is not the streaming behavior anyone wants) or, in some configurations, crashes the entire route on the server before streaming begins.

**Bad:**
```tsx
<Await resolve={reviews} errorElement={<ReviewsError />}>
  {(r) => <ReviewList reviews={r} />}
</Await>
```

**Good:**
```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await resolve={reviews} errorElement={<ReviewsError />}>
    {(r) => <ReviewList reviews={r} />}
  </Await>
</Suspense>
```

**Report as:** `[FILE:LINE] AWAIT_WITHOUT_SUSPENSE` — `<Await>` rendered without an enclosing `<Suspense>`.

### 6. `<Await>` without `errorElement`

A rejected deferred promise inside `<Await>` without `errorElement` bubbles to the route's `ErrorBoundary` — tearing down the entire route, including the parts that already rendered successfully. That defeats the streaming benefit (graceful degradation of slow secondary data).

**Bad:**
```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await resolve={reviews}>
    {(r) => <ReviewList reviews={r} />}
  </Await>
</Suspense>
```

**Good:**
```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await resolve={reviews} errorElement={<ReviewsError />}>
    {(r) => <ReviewList reviews={r} />}
  </Await>
</Suspense>
```

**Report as:** `[FILE:LINE] AWAIT_WITHOUT_ERROR_ELEMENT` — `<Await>` has no `errorElement` prop; rejection tears down the entire route.

### 7. `defer()` where the promise is created AFTER an `await`

The point of `defer` is that the loader returns before slow data resolves. If the slow promise is created after an `await`, the loader still blocks on the prior `await` — streaming gains nothing.

**Bad:**
```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const product = await db.getProduct(params.id);
  const reviews = await db.getReviews(params.id); // awaited!
  return defer({ product, reviews });             // not actually deferred
}
```

**Bad (subtle — promise created after await):**
```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const product = await db.getProduct(params.id);
  const reviews = db.getReviews(params.id); // created AFTER await — sequential
  return defer({ product, reviews });
}
```

**Good (kick off slow promise before any await):**
```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const reviewsPromise = db.getReviews(params.id); // BEFORE any await
  const product = await db.getProduct(params.id);
  return defer({ product, reviews: reviewsPromise });
}
```

**Report as:** `[FILE:LINE] DEFER_PROMISE_AFTER_AWAIT` — deferred promise created after an `await`; loader still blocks.

### 8. `<RemixServer abortDelay>` set to a very high value

`abortDelay` (default 5000ms) caps how long the server holds the connection open waiting for deferred promises before aborting and sending what's resolved. Setting it to 30s "to be safe" holds slow upstream calls open, exhausts server worker pools, and pushes latency p99 sky-high.

**Bad:**
```tsx
<RemixServer context={remixContext} url={request.url} abortDelay={30_000} />
```

**Good:** keep near the default; set per-call timeouts inside loaders instead:
```tsx
<RemixServer context={remixContext} url={request.url} />
```

**Report as:** `[FILE:LINE] HIGH_ABORT_DELAY` — `abortDelay` >10s on `<RemixServer>`.

## Verify before flagging

- For "prefetch render on list," confirm the link is inside an iterator (`.map()`, a loop). A single prefetch="render" on a high-priority above-the-fold nav link is fine.
- For "prefetch to side-effect loader," confirm the loader actually has side effects. Read the loader body. A pure read loader with `prefetch="intent"` is the correct pattern.
- For "defer on fast data," confirm the deferred promise resolves synchronously / from cache / from a sub-50ms call. When unsure, prefer a softer "consider awaiting" note.
- For "Await without Suspense / errorElement," confirm both wrappers are missing from the same `<Await>` instance, not from a different one in the same file.
- For "defer after await," confirm the promise is genuinely created after the await — not just used in JSX after an await.

## Verbatim quote requirements

Findings on this surface require a verbatim quote of:
- the `<Link prefetch="...">` / `<PrefetchPageLinks page="...">` / `defer({ ... })` / `<Await ...>` call being flagged, AND
- for loader-side-effect claims: the loader body that contains the side effect.

A finding like "prefetch is misconfigured here" with no JSX or loader quote is not reportable.
