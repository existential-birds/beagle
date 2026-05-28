# Defer & Await Review Reference

Anti-patterns and review prompts for `defer()`, `<Await>`, and `<Suspense>` in Remix v2. See [beagle-react:remix-v2-data-flow](../../remix-v2-data-flow/SKILL.md) for canonical streaming patterns.

## 1. `defer` for already-fast data

**Smell**:

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const product = db.product.findUnique({ where: { id: params.id! } }); // ~5ms query
  return defer({ product });
}
```

**Why bad**: `defer` exists to let the page render before slow data is ready. Streaming has overhead: an unresolved chunk, `<Suspense>` boundary work, an extra wire round-trip for the chunk. For sub-50ms queries this is pure overhead with no perceived-latency win — and it forces the consumer to add `<Suspense>` + `<Await>` for nothing.

**Fix**: Await it and return via `json`:

```tsx
const product = await db.product.findUnique({ where: { id: params.id! } });
return json({ product });
```

**Rule of thumb**: Use `defer` when (a) at least one promise is materially slower than the page's critical path *and* (b) the page can render usefully without it. Single-query routes should almost never `defer`.

## 2. Awaiting in the loader what should be deferred

**Smell**:

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const product = await db.product.findUnique({ where: { id: params.id! } });
  const reviews = await db.review.findMany({ where: { productId: params.id! } }); // slow!
  return defer({ product, reviews });
}
```

**Why bad**: `await`-ing the slow promise before constructing `defer` defeats the entire purpose — nothing streams. The page waits on `reviews` exactly as it would with `json`. `defer` only streams promises that are passed **unresolved**.

**Fix**: Drop the `await` on the slow query so the promise itself flows through `defer`:

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const product = await db.product.findUnique({ where: { id: params.id! } });
  const reviews = db.review.findMany({ where: { productId: params.id! } }); // no await
  return defer({ product, reviews });
}
```

The component reads `reviews` as a promise via `useLoaderData<typeof loader>()` and renders it inside `<Suspense><Await>`.

## 3. `<Await>` without a surrounding `<Suspense>`

**Smell**:

```tsx
return (
  <>
    <ProductHeader product={product} />
    <Await resolve={reviews}>
      {(rs) => <ProductReviews reviews={rs} />}
    </Await>
  </>
);
```

**Why bad**: `<Await>` suspends while its promise is pending. Without a `<Suspense>` ancestor, React has nothing to render as fallback and the page crashes. The docs say `<Await>` "must be rendered inside of a `<React.Suspense>` or `<React.SuspenseList>` parent."

**Fix**:

```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await resolve={reviews}>
    {(rs) => <ProductReviews reviews={rs} />}
  </Await>
</Suspense>
```

## 4. Missing `errorElement` on `<Await>`

**Smell**:

```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await resolve={reviews}>
    {(rs) => <ProductReviews reviews={rs} />}
  </Await>
</Suspense>
```

**Why bad**: If the deferred promise rejects (DB error, timeout), the rejection bubbles up to the route's `ErrorBoundary` and replaces the entire page with the error UI. The whole point of streaming was to keep the rest of the page useful while one section loads — a missing `errorElement` throws that away.

**Fix**: Provide an inline error fallback so only the slow section degrades:

```tsx
<Suspense fallback={<ReviewsSkeleton />}>
  <Await
    resolve={reviews}
    errorElement={<p role="alert">Could not load reviews.</p>}
  >
    {(rs) => <ProductReviews reviews={rs} />}
  </Await>
</Suspense>
```

## 5. `defer` returning sensitive fields

**Smell**:

```tsx
return defer({ user: db.user.findUnique({ where: { id } }) });
```

**Why bad**: Deferred promises serialize to the client the same way `json` returns do — the resolved value is streamed as JSON. Returning a raw ORM record exposes password hashes, API keys, and `internal_*` fields once the promise resolves.

**Fix**: Project to a DTO *inside* the promise chain so the resolved shape is safe:

```tsx
return defer({
  user: db.user
    .findUnique({ where: { id } })
    .then((u) => u && { id: u.id, email: u.email, name: u.name }),
});
```

## Review prompts

- Is every `defer({ ... })` call accompanied by at least one promise passed **without** `await`?
- For every `await` inside a loader that returns `defer`, is the awaited promise on the critical path (fast, must be ready before render)?
- Is every `<Await resolve={...}>` wrapped in a `<Suspense fallback={...}>` ancestor?
- Does every `<Await>` declare an `errorElement` so promise rejection degrades only that section?
- Do deferred promises resolve to DTO shapes, or do they resolve to raw ORM records with sensitive fields?
- Could the route be simplified to `json(...)` because no single query is slow enough to justify streaming?
