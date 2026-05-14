# Streaming with `defer` and `<Await>`

Streaming lets a Remix route return its initial HTML quickly while slow promises resolve afterward, with the browser progressively rendering as each chunk arrives. Useful for routes where critical data (page title, hero content) is fast but secondary data (recommendations, related items, reviews) is slow.

## When streaming actually helps

Streaming improves **TTFB** (time to first byte) and **LCP** (largest contentful paint) only when:

1. The critical data is meaningfully faster than the secondary data (≥100ms gap).
2. The hosting platform supports streamed responses (Node, Cloudflare Workers with streaming, Vercel Edge with streaming — **not** all edge runtimes; many buffer the full response).
3. The slow data takes >50ms — otherwise the suspense skeleton flashes and net perceived performance regresses.

If those don't hold, await everything and return a `json()` response.

## Canonical `defer` shape

```tsx
import { defer, type LoaderFunctionArgs } from "@remix-run/node";
import { Await, useLoaderData } from "@remix-run/react";
import { Suspense } from "react";

export async function loader({ params }: LoaderFunctionArgs) {
  // Critical: await — needed for the initial paint, meta tags, SEO
  const product = await db.getProduct(params.id);

  // Secondary: kick off BEFORE any other await, pass the unresolved promise
  const reviewsPromise = db.getReviews(params.id); // NO await

  return defer({ product, reviews: reviewsPromise });
}

export default function Product() {
  const { product, reviews } = useLoaderData<typeof loader>();
  return (
    <>
      <ProductHeader product={product} />
      <Suspense fallback={<ReviewsSkeleton />}>
        <Await resolve={reviews} errorElement={<ReviewsError />}>
          {(r) => <ReviewList reviews={r} />}
        </Await>
      </Suspense>
    </>
  );
}
```

**Invariant**: every promise passed to `defer()` must be created **before** any subsequent `await` in the loader. Otherwise the loader still blocks on the slow call before returning, and streaming gains nothing.

```tsx
// BROKEN — reviewsPromise starts AFTER awaiting db.getOrders, so the loader
// doesn't return until orders finishes. Streaming achieves nothing.
const product = await db.getProduct(params.id);
const orders = await db.getOrders(params.id);    // blocks
const reviewsPromise = db.getReviews(params.id); // too late
return defer({ product, orders, reviews: reviewsPromise });
```

## Error handling in `<Await>`

Always pass `errorElement`. Without it, a rejected deferred promise bubbles to the route's `ErrorBoundary` and tears down the **whole route** — defeating the streaming benefit (the user already saw partial content, then it vanishes).

```tsx
import { Await, useAsyncError } from "@remix-run/react";
import { Suspense } from "react";

function ReviewsError() {
  const err = useAsyncError() as Error;
  return <p role="alert">Reviews unavailable: {err.message}</p>;
}

<Suspense fallback={<ReviewsSkeleton />}>
  <Await resolve={reviews} errorElement={<ReviewsError />}>
    {(r) => <ReviewList reviews={r} />}
  </Await>
</Suspense>
```

`useAsyncValue()` reads the resolved value. `useAsyncError()` reads the rejection.

## `abortDelay` — keep it low

```tsx
// app/entry.server.tsx
import { RemixServer } from "@remix-run/react";

export default function handleRequest(/* ... */) {
  return /* renderToPipeableStream */(
    <RemixServer context={remixContext} url={request.url} abortDelay={5000} />
    // ...
  );
}
```

Default is 5000ms. **Don't bump it to 30s "to be safe"** — slow upstream calls then hold the connection open, exhausting server worker pools and pushing p99 latency through the floor. If upstreams are slow, set per-call timeouts inside the loader:

```tsx
const reviewsPromise = Promise.race([
  db.getReviews(params.id),
  new Promise((_, reject) =>
    setTimeout(() => reject(new Error("reviews timeout")), 3000)
  ),
]);
```

## Interaction with `headers` export

Streaming and `Cache-Control` interact awkwardly:

- The HTTP response headers go out **before** any deferred data resolves — so `headers` must commit to a caching policy without knowing whether the slow data succeeds.
- If you cache a deferred response and a deferred promise rejected, the cached HTML contains the partial-then-error UI for everyone.

Safer defaults:

```tsx
// Avoid public caching on deferred responses
export const headers: HeadersFunction = () => ({
  "Cache-Control": "private, no-store",
});
```

Or only `defer` on routes where every deferred promise is idempotent and resilient.

## TypeScript: `<Await resolve={...}>` types

`useLoaderData<typeof loader>()` returns `Promise<T>` for deferred fields. Pass that promise directly to `<Await resolve={...}>` — **don't** call `.then()` on it during render:

```tsx
const { reviews } = useLoaderData<typeof loader>();
// reviews: Promise<Review[]>

// CORRECT
<Await resolve={reviews}>{(r) => <ReviewList reviews={r} />}</Await>

// WRONG — calling .then() in render kicks off another async chain every render
<Await resolve={reviews.then((r) => r.filter(/*...*/))}>
```

If you need to transform, do it in the loader before passing through `defer`:

```tsx
const reviewsPromise = db.getReviews(params.id).then((r) => r.filter(visible));
return defer({ reviews: reviewsPromise });
```

## Streaming and CSS-in-JS

Emotion, styled-components, and similar libraries with default config in `entry.server.tsx` require collecting styles during a **full server render** — incompatible with streaming. The page can't stream until rendering completes. Use Tailwind, Vanilla Extract, CSS Modules, or a CSS-in-JS library with documented streaming support.

## CSP and streaming

Streaming appends `<script>` chunks to the HTML to resolve deferred promises in the browser. These trip strict Content Security Policy:

- Easy escape: allow `'unsafe-inline'` for `script-src` (degrades CSP value).
- Hard but correct: thread a nonce through `<RemixServer>`, `<Scripts>`, `<ScrollRestoration>`, and `<LiveReload>`, and set `script-src 'self' 'nonce-...'`.

## Anti-patterns

- **`<Suspense>` wrapping awaited data** — Suspense never triggers; dead code that misleads future readers. Remove the boundary, or move the field to `defer`.
- **`defer` for data that comes from an in-memory cache** — protocol overhead (extra script tags, extra render pass) makes TTI worse for sub-50ms data.
- **Mounting `<Await>` without `<Suspense>`** — React throws.
- **`await Promise.all([...])` of deferred fields in the loader before `defer`** — same as creating the promise after an `await`: kills streaming.
- **High `abortDelay`** — exhausts worker pools.

## Deferring multiple values

```tsx
return defer({
  product,                              // awaited
  reviews: db.getReviews(params.id),    // promise
  related: db.getRelated(params.id),    // promise
  recommendations: db.getRecs(params.id), // promise
});
```

Each is independently rendered through its own `<Await>`. Order them by likely resolution time so the fastest chunks appear first.
