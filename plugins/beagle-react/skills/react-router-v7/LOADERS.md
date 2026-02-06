# Data Loading Patterns

## Basic Loader

```tsx
{
  path: "/teams/:teamId",
  loader: async ({ params, request }) => {
    const url = new URL(request.url);
    const query = url.searchParams.get("q");
    const team = await fetchTeam(params.teamId, query);
    return { team, name: team.name };
  },
  Component: Team,
}

function Team() {
  const data = useLoaderData();
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

## Search Params in Loaders

```tsx
{
  path: "/search",
  loader: async ({ request }) => {
    const url = new URL(request.url);
    const query = url.searchParams.get("q");
    const page = url.searchParams.get("page") || "1";
    return { results: await search(query, parseInt(page)) };
  },
}

function SearchPage() {
  const { results } = useLoaderData();
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
function shouldRevalidate({ currentUrl, nextUrl, formAction }) {
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
// product.tsx
import { Route } from "./+types/product";

export async function loader({ params }: Route.LoaderArgs) {
  const product = await getProduct(params.pid);
  return { product };
}

export default function Product({ loaderData }: Route.ComponentProps) {
  return <div>{loaderData.product.name}</div>;
}
```
