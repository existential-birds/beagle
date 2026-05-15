# Defer & Await — Streaming Loader Data

`defer()` lets a loader return a streamed/deferred response that may contain unresolved promises. The browser receives the critical data immediately; slow data resolves over the same HTTP connection and triggers a `<Suspense>` reveal when ready.

## When Streaming Helps TTFB

Defer pays off when:

- One query dominates the loader's wall-clock time (e.g. an aggregation, a third-party API call, a slow report) **and**
- The rest of the page is useful on its own (header, nav, primary record).

Defer does **not** help when:

- All queries are fast (you just add Suspense overhead for no win).
- The slow query *is* the critical first paint (no useful UI without it).
- You return a deferred promise but `await` it before constructing `defer()` — that defeats streaming entirely (see anti-pattern below).

## Signature

```ts
import { defer } from "@remix-run/node";

defer(data, init?: number | ResponseInit): TypedDeferredData;
// (numeric status shorthand was added in Remix 2.5+; pre-2.5 requires `defer(data, { status: 404 })`)
```

`data` may contain plain values *and* unresolved promises in any field. Remix serializes the resolved values eagerly and streams the rest.

## Canonical Pattern

```tsx
// app/routes/product.$id.tsx
import { defer, type LoaderFunctionArgs } from "@remix-run/node";
import { Await, useLoaderData } from "@remix-run/react";
import { Suspense } from "react";

export async function loader({ params }: LoaderFunctionArgs) {
  // Critical data is awaited so the page can't render meaningfully without it.
  const product = await db.product.findUnique({ where: { id: params.id } });

  // Slow data is NOT awaited — pass the raw promise so it can stream.
  const reviews = db.review.findMany({ where: { productId: params.id } });

  return defer({ product, reviews });
}

export default function ProductPage() {
  const { product, reviews } = useLoaderData<typeof loader>();

  return (
    <>
      <ProductHeader product={product} />

      <Suspense fallback={<ReviewsSkeleton />}>
        <Await resolve={reviews} errorElement={<p>Failed to load reviews</p>}>
          {(rs) => <ProductReviews reviews={rs} />}
        </Await>
      </Suspense>
    </>
  );
}
```

Three rules — all required:

1. **Don't await the slow promise** before passing it to `defer()`. The whole point is to ship the unresolved promise.
2. **Wrap every `<Await>` in a `<Suspense fallback={…}>`**. React throws without a fallback boundary; there's nothing to render while the promise is pending.
3. **Provide `errorElement`** on every `<Await>` (next section).

## Error Handling in `<Await>`

A rejected deferred promise without an `errorElement` bubbles to the nearest route `ErrorBoundary` — which kills the whole page instead of degrading just the slow section. Always provide an inline fallback:

```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await
    resolve={reviews}
    errorElement={<p role="alert">Reviews are temporarily unavailable.</p>}
  >
    {(rs) => <ProductReviews reviews={rs} />}
  </Await>
</Suspense>
```

If you want the error to reach a child `ErrorBoundary` instead of being swallowed inline, you can re-throw from a render-prop wrapper — but the default expectation is graceful, in-place degradation.

## Reading the Deferred Value

`useLoaderData<typeof loader>()` returns the promise field as `Promise<T>` in the component. You never `.then()` it manually — `<Await resolve={…}>` handles the unwrap and re-render. The render prop receives the resolved value:

```tsx
<Await resolve={reviews}>
  {(rs) => <ProductReviews reviews={rs} />}
</Await>
```

Inside the render prop, `rs` is fully typed via `SerializeFrom` — same serialization rules as a regular loader return (Dates become strings, etc.).

## Anti-Patterns

- **`await` before `defer`**: `const reviews = await db.review.findMany(...); return defer({ product, reviews });` makes `defer` behave exactly like `json` — nothing streams.
- **`<Await>` without `<Suspense>`**: React throws because there's no fallback.
- **Missing `errorElement`**: A single slow query failure tears down the whole route.
- **Streaming everything**: If every field is deferred, the user stares at fallbacks. Resolve the critical record synchronously; only defer the long tail.

## Compatibility Notes

- `defer()` requires a streaming-capable runtime adapter. Node (`@remix-run/node`) and Cloudflare (`@remix-run/cloudflare`) both support it. Some older serverless adapters buffer responses and break streaming — verify your deploy target supports HTTP streaming end-to-end before depending on `defer()` for TTFB.
- `defer()` returns a `TypedDeferredData<T>`, not a `TypedResponse`. You cannot wrap a `defer()` result in `json()` or vice versa — pick one per loader.

## When to Use Plain `json()` Instead

If the slow query is fast in practice (P95 < 100ms), or if the page is meaningless without it, just `await` it inside the loader and return `json()`. Defer adds a `<Suspense>` boundary and a render flicker — only worth it when the TTFB win is real.

## Multiple Deferred Fields

You can stream more than one field; each `<Await>` resolves independently as its promise settles.

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const product = await db.product.findUnique({ where: { id: params.id } });
  const reviews = db.review.findMany({ where: { productId: params.id } });
  const related = db.product.findRelated(params.id!);
  return defer({ product, reviews, related });
}

export default function ProductPage() {
  const { product, reviews, related } = useLoaderData<typeof loader>();
  return (
    <>
      <ProductHeader product={product} />
      <Suspense fallback={<ReviewsSkeleton />}>
        <Await resolve={reviews} errorElement={<p>Reviews unavailable.</p>}>
          {(rs) => <ProductReviews reviews={rs} />}
        </Await>
      </Suspense>
      <Suspense fallback={<RelatedSkeleton />}>
        <Await resolve={related} errorElement={<p>Related items unavailable.</p>}>
          {(items) => <RelatedProducts items={items} />}
        </Await>
      </Suspense>
    </>
  );
}
```

## Interaction with Revalidation

After every action, Remix re-runs loaders for matching routes — including loaders that returned `defer()`. The new deferred promises replace the old ones, and `<Await>` will re-suspend until the new ones resolve. You don't need to invalidate manually; the same `useLoaderData<typeof loader>()` call picks up the fresh promises.

## Picking the Right Tool

| Goal                                                | API                |
|-----------------------------------------------------|--------------------|
| One slow query, rest of page is useful immediately  | `defer()` + `<Await>` |
| All queries fast, want simple data + types          | `json()`           |
| Need explicit status / headers / typing             | `json(data, init)` |
| Auth guard / 404 short-circuit                      | `throw redirect()` / `throw new Response(...)` |
| Binary / streamed file body                         | Raw `new Response(stream, init)` |
