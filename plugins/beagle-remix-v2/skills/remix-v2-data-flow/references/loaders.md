# Loaders

Loaders are server-only data-fetch functions exported from a route module. Remix calls them during SSR and on every client navigation that lands on the route. You never call a loader directly — "Remix will call your loaders for you; in no case should you ever try to call your loader directly."

## Signature

```ts
import { type LoaderFunctionArgs } from "@remix-run/node";

export async function loader(
  { request, params, context }: LoaderFunctionArgs,
): Promise<Response> {
  // ...
}
```

- `request` — standard `Request`. Use `new URL(request.url)` to read search params, `request.headers` for cookies / `Authorization`.
- `params` — route params from the file/segment definition. Values are typed `string | undefined` — always guard before passing to a DB query.
- `context` — adapter-supplied context (Cloudflare bindings, Express locals via the Node adapter, etc.).

The v2 type name is `LoaderFunctionArgs`. The v1 name `LoaderArgs` may still exist as a deprecated alias — prefer the v2 name.

## Typed `useLoaderData`

```tsx
import { useLoaderData } from "@remix-run/react";

export default function Invoices() {
  const { invoices, status } = useLoaderData<typeof loader>();
  return <InvoiceList invoices={invoices} activeStatus={status} />;
}
```

`useLoaderData<typeof loader>()` is a **type annotation**, not a `as`-style assertion. Internally it resolves to `SerializeFrom<typeof loader>`, which models the on-the-wire transformation:

- `Date` becomes `string`.
- `Map` / `Set` collapse to empty object / array shapes.
- `undefined` fields are stripped.
- Class instances lose their methods (just plain data survives).

If your component calls `data.createdAt.getFullYear()`, the type already says `string` — that's a real bug, not a tooling complaint.

## `json()` — Status, Headers, Typing

```ts
import { json } from "@remix-run/node";

return json({ invoices }, { status: 200, headers: { "Cache-Control": "private, max-age=10" } });
return json({ errors }, { status: 400 });
return json({ user }, 201); // numeric shorthand for status
```

`json(data, init?)` is a shortcut for an `application/json` response with the given status and headers. The return type is `TypedResponse<typeof data>` — that's what lets `useLoaderData<typeof loader>()` infer the payload through `SerializeFrom`.

### When `json()` Is Optional in v2

v2 did **not** change the underlying contract: loaders must return a `Response`. `json()` is the ergonomic wrapper. Returning a bare object is not the documented v2 contract — do not assume the auto-wrapping behavior of Remix 3 / React Router `dataStrategy`. Reach for `json()` whenever you need a non-200 status, custom headers, or explicit `TypedResponse<T>` inference.

## `redirect()`

```ts
import { redirect } from "@remix-run/node";

throw redirect("/login");
return redirect(`/projects/${project.id}`, {
  headers: { "Set-Cookie": await commitSession(session) },
});
```

`redirect(url, init?)` is a shortcut for 30x responses. Default status is `302`; supports `301` / `303` / `307` and any standard `Response` init (including `Set-Cookie`).

## Throwing for Short-Circuits

Throwing a `Response` exits the data function immediately — useful for auth guards and 404s.

```ts
// app/utils/auth.server.ts
export async function requireUser(request: Request) {
  const user = await getUser(request);
  if (!user) throw redirect("/login");
  return user;
}

// In a loader:
export async function loader({ request }: LoaderFunctionArgs) {
  const user = await requireUser(request);
  return json({ user });
}
```

Throw `new Response("Not Found", { status: 404 })` or `throw json({ message }, { status: 404 })` for 404s — `useRouteError()` + `isRouteErrorResponse()` will then expose `status` / `statusText` to your `ErrorBoundary`. Throwing a plain `Error` will not classify as a route response.

## Filtering Sensitive Data

Loaders run server-only, but their return values ship to the browser as JSON. Project to a safe DTO before returning.

```ts
// Bad — leaks passwordHash, internal flags
const user = await db.user.findUnique({ where: { id } });
return json({ user });

// Good
const user = await db.user.findUnique({
  where: { id },
  select: { id: true, email: true, name: true },
});
return json({ user });
```

If you must fetch the full record (to do server-side work), strip before return:

```ts
const full = await db.user.findUnique({ where: { id } });
const { passwordHash, internalNotes, ...safe } = full!;
return json({ user: safe });
```

## Params: Always Guard

`params` values are `string | undefined`. Downstream DB lookups silently coerce or query `undefined`.

```ts
import invariant from "tiny-invariant";

export async function loader({ params }: LoaderFunctionArgs) {
  invariant(params.projectId, "projectId required");
  const project = await db.project.findUnique({ where: { id: params.projectId } });
  if (!project) throw new Response("Not Found", { status: 404 });
  return json({ project });
}
```

Or parse with zod for richer shapes:

```ts
const ParamsSchema = z.object({ projectId: z.string().uuid() });
const { projectId } = ParamsSchema.parse(params);
```

## Reading Search Params

```ts
export async function loader({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const status = url.searchParams.get("status") ?? "open";
  const invoices = await db.invoice.findMany({ where: { status } });
  return json({ invoices, status });
}
```

## Don't Mutate in Loaders

Loaders run on every GET and may be invoked speculatively by prefetch; revalidation re-runs them after every action. Any mutation inside a loader will replay. Writes belong in `action`.

## Don't Re-Define Data in Child Loaders

Re-loading the same query in a parent and child means two sources of truth, doubled DB load, and divergent shapes after revalidation. Load once at the highest matching route and read from children via `useMatches` / `useRouteLoaderData`.

## `.server` Suffix

Modules with a `.server.ts` / `.server.tsx` suffix are never bundled to the client. Import DB clients, secrets, and crypto helpers from `~/db.server`, `~/auth.server`, etc., so a stray browser-side import of a server-only utility fails fast at build time rather than leaking secrets.

## Sharing Data Across Routes — `useRouteLoaderData`

When a child route needs data already loaded by an ancestor, don't refetch — read the parent's loader data directly.

```tsx
// app/root.tsx
export async function loader() {
  return json({ user: await getCurrentUser() });
}

// app/routes/dashboard.tsx
import { useRouteLoaderData } from "@remix-run/react";
import type { loader as rootLoader } from "~/root";

export default function Dashboard() {
  const data = useRouteLoaderData<typeof rootLoader>("root");
  return <h1>Welcome, {data?.user.name}</h1>;
}
```

The string id matches the route module's id (`"root"` for `app/root.tsx`; file-based ids for nested routes). Pair with `typeof rootLoader` to keep `SerializeFrom`-aware typing.

## Headers from the Leaf Loader Win

Only the deepest matching `headers` export is used by default; parent caching policies are ignored unless you merge them yourself.

```ts
// app/routes/products.$id.tsx
import type { HeadersFunction } from "@remix-run/node";

export const headers: HeadersFunction = ({ loaderHeaders, parentHeaders }) => ({
  "Cache-Control": loaderHeaders.get("Cache-Control") ?? parentHeaders.get("Cache-Control") ?? "no-store",
});
```

## Response Caching

For per-route caching, set `Cache-Control` via the `init` argument to `json()`:

```ts
return json(
  { product },
  {
    headers: {
      "Cache-Control": "private, max-age=60, stale-while-revalidate=300",
    },
  },
);
```

Choose `private` for user-specific data; `public` only when the response is identical for every viewer.

## Quick Anti-Pattern Recap

- **Fetching in `useEffect` what belongs in a loader** — defeats SSR, creates waterfalls, skips automatic revalidation.
- **Mutating in a loader** — loaders run on GETs and may be prefetched; writes belong in `action`.
- **Returning sensitive fields** — everything goes to the browser as JSON; project to a safe DTO.
- **Reading `params.foo` without guarding** — values are `string | undefined`; use `invariant` or zod.
- **Asserting types instead of annotating** — `useLoaderData<typeof loader>()` is an annotation that drives `SerializeFrom`; never `useLoaderData() as Foo`.
