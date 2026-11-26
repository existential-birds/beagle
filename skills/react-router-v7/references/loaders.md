# Data Loading Patterns

## Contents

- [Basic Loader](#basic-loader)
- [Parallel Data Loading](#parallel-data-loading)
- [Streaming Promises](#streaming-promises)
- [Search Params in Loaders](#search-params-in-loaders)
- [useSearchParams Hook](#usesearchparams-hook)
- [Revalidation Control](#revalidation-control)
- [Framework Mode Loaders](#framework-mode-loaders)
- [Client Loaders & HydrateFallback](#client-loaders--hydratefallback)

---

## Basic Loader

```tsx
import { useLoaderData, type LoaderFunctionArgs } from "react-router";

async function teamLoader({ params, request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q");
  const team = await fetchTeam(params.teamId!, query);
  return { team, name: team.name };
}

{
  path: "/teams/:teamId",
  loader: teamLoader,
  Component: Team,
}

function Team() {
  const data = useLoaderData<typeof teamLoader>();
  return <h1>{data.name}</h1>;
}
```

## Parallel Data Loading

Nested routes load data in parallel automatically:

```tsx
createBrowserRouter([
  {
    path: "/",
    loader: rootLoader,    // Loads in parallel
    children: [
      {
        path: "project/:id",
        loader: projectLoader, // Loads in parallel with rootLoader
      },
    ],
  },
]);
```

## Streaming Promises

In React Router v7, `defer()` is removed—return unawaited promises directly in plain objects alongside awaited critical data, and render with `<Suspense>` + `<Await>` (or React 19 `use()`):

```tsx
import { Suspense } from "react";
import { Await } from "react-router";
import type { Route } from "./+types/product";

export async function loader({ params }: Route.LoaderArgs) {
  // Kick off non-critical promise BEFORE awaiting critical data
  const reviewsPromise = getReviews(params.pid);
  const product = await getProduct(params.pid);
  return { product, reviews: reviewsPromise };
}

export default function Product({ loaderData }: Route.ComponentProps) {
  return (
    <div>
      <h1>{loaderData.product.name}</h1>
      <Suspense fallback={<p>Loading reviews...</p>}>
        <Await resolve={loaderData.reviews} errorElement={<p>Failed to load reviews.</p>}>
          {(reviews) => <ReviewList reviews={reviews} />}
        </Await>
      </Suspense>
    </div>
  );
}
```

## Search Params in Loaders

```tsx
import { Form, useLoaderData, type LoaderFunctionArgs } from "react-router";

async function searchLoader({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q") ?? "";
  const page = url.searchParams.get("page") || "1";
  return { results: await search(query, parseInt(page, 10)) };
}

{
  path: "/search",
  loader: searchLoader,
  Component: SearchPage,
}

function SearchPage() {
  const { results } = useLoaderData<typeof searchLoader>();
  return (
    <Form method="get">
      <input type="text" name="q" />
      <button type="submit">Search</button>
    </Form>
  );
}
```

## useSearchParams Hook

```tsx
import { useSearchParams } from "react-router";

function SearchPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const query = searchParams.get("q");

  return (
    <input
      value={query || ""}
      onChange={(e) => setSearchParams({ q: e.target.value })}
    />
  );
}
```

## Revalidation Control

```tsx
import type { ShouldRevalidateFunctionArgs } from "react-router";

function shouldRevalidate({ currentUrl, nextUrl }: ShouldRevalidateFunctionArgs) {
  return currentUrl.pathname !== nextUrl.pathname;
}

createBrowserRouter([
  {
    path: "/data",
    shouldRevalidate,
    loader: dataLoader,
  },
]);
```

## Framework Mode Loaders

```tsx
// app/routes/product.tsx
import type { Route } from "./+types/product";

export async function loader({ params }: Route.LoaderArgs) {
  const product = await getProduct(params.pid);
  return { product };
}

export default function Product({ loaderData }: Route.ComponentProps) {
  return <div>{loaderData.product.name}</div>;
}
```

## Client Loaders & HydrateFallback

Use `clientLoader` in Framework Mode to fetch in the browser (e.g., `localStorage`, IndexedDB, or client auth) or augment SSR data. Export `HydrateFallback` when initial SSR should wait for `clientLoader.hydrate = true as const`:

```tsx
// app/routes/preferences.tsx
import type { Route } from "./+types/preferences";

export async function clientLoader({ serverLoader }: Route.ClientLoaderArgs) {
  const serverData = await serverLoader();
  const localPrefs = JSON.parse(localStorage.getItem("prefs") ?? "{}");
  return { ...serverData, localPrefs };
}
clientLoader.hydrate = true as const;

export function HydrateFallback() {
  return <div>Loading preferences...</div>;
}

export default function Preferences({ loaderData }: Route.ComponentProps) {
  return <pre>{JSON.stringify(loaderData.localPrefs)}</pre>;
}
```
