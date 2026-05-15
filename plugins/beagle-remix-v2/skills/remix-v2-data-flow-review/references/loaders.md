# Loader Review Reference

Anti-patterns and review prompts for `export async function loader` in Remix v2 route modules. See [beagle-remix-v2:remix-v2-data-flow](../../remix-v2-data-flow/SKILL.md) for canonical loader patterns.

## 1. `useEffect` data fetching that belongs in a loader

**Smell**:

```tsx
// app/routes/invoices.tsx
export default function Invoices() {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  useEffect(() => {
    fetch("/api/invoices").then((r) => r.json()).then(setInvoices);
  }, []);
  return <InvoiceList invoices={invoices} />;
}
```

**Why bad**: Defeats SSR, opens a fetch waterfall, skips automatic revalidation after actions, and breaks progressive enhancement. The docs say "Remix will call your loaders for you; in no case should you ever try to call your loader directly."

**Fix**: Move into a `loader` and read with `useLoaderData<typeof loader>()`.

**Do not flag when**: the fetch reads `localStorage`, `window.matchMedia`, `IntersectionObserver`, or any browser-only API — those legitimately stay in `useEffect`.

## 2. Mutations inside a `loader`

**Smell**:

```tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const user = await getUser(request);
  await db.session.update({ where: { id: user.sessionId }, data: { lastSeen: new Date() } });
  return json({ user });
}
```

**Why bad**: Loaders run on every GET navigation **and** speculatively on prefetch **and** during automatic revalidation after any action on the page. A write in a loader replays unpredictably and corrupts data.

**Fix**: Move the write into an `action` or a non-route server module triggered by an explicit `<Form method="post">` / `fetcher.submit()`. Read-only logging that *must* live with the GET (e.g. analytics ping) belongs in a fire-and-forget call on the server response, not a synchronous `await` in the loader.

## 3. Missing FormData / params validation

**Smell**:

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const project = await db.project.findUnique({ where: { id: params.id } });
  return json({ project });
}
```

**Why bad**: `params.id` is `string | undefined`. Prisma silently passes `undefined`, returning an unintended record or null. Downstream code crashes on `.toLowerCase()` etc.

**Fix**:

```tsx
import invariant from "tiny-invariant";

export async function loader({ params }: LoaderFunctionArgs) {
  invariant(params.id, "id required");
  const project = await db.project.findUnique({ where: { id: params.id } });
  if (!project) throw new Response("Not Found", { status: 404 });
  return json({ project });
}
```

Or parse `params` with a zod schema for slug/id format validation.

## 4. Leaking server-only fields to the client

**Smell**:

```tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const user = await db.user.findUnique({
    where: { id: await getUserId(request) },
  });
  return json({ user }); // ships passwordHash, apiKey, internalRole, etc.
}
```

**Why bad**: Everything returned from a loader travels to the browser as JSON. Password hashes, API keys, session tokens, and `internal_*` flags become visible in the Network panel and the SSR HTML payload.

**Fix**: Project to a safe DTO before returning:

```tsx
return json({
  user: { id: user.id, email: user.email, name: user.name },
});
```

**Field-name red flags** to grep for in loader return values: `password`, `passwordHash`, `apiKey`, `secret`, `token`, `internal_`, `__`, `salt`, `mfaSeed`, `webhookSecret`.

## 5. Wrong type assertion vs type annotation

**Smell**:

```tsx
const data = useLoaderData() as { invoices: Invoice[] };
```

**Why bad**: An `as` assertion bypasses `SerializeFrom<T>`. The wire format collapses `Date → string`, `Map/Set → {}`, strips `undefined`, and removes class methods. The assertion will lie about the runtime shape.

**Fix**:

```tsx
const { invoices } = useLoaderData<typeof loader>();
```

The `<typeof loader>` here is a generic parameter (type annotation), not an `as`-style assertion. Do not flag the annotation form as an "unsafe cast" — it is the documented safe path.

## 6. Throwing primitives instead of Response

**Smell**:

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const project = await db.project.findUnique({ where: { id: params.id! } });
  if (!project) throw new Error("Not Found"); // or: throw "not found"
  return json({ project });
}
```

**Why bad**: `useRouteError()` + `isRouteErrorResponse()` only classify thrown `Response` objects as route responses. A plain `Error` hits the boundary as an unknown runtime error with no `status` / `statusText`; a thrown string is even worse.

**Fix**:

```tsx
if (!project) throw new Response("Not Found", { status: 404 });
// or: throw json({ message: "Not found" }, { status: 404 });
```

For auth guards, `throw redirect("/login")` from a helper short-circuits the loader cleanly.

## 7. `LoaderArgs` v1 type holdover

**Smell**:

```tsx
import type { LoaderArgs } from "@remix-run/node";
export async function loader({ request }: LoaderArgs) { ... }
```

**Why bad**: v2 renamed `LoaderArgs` → `LoaderFunctionArgs`. The old name may exist as a deprecated alias but is a migration smell — flag it during a v2 review.

**Fix**: `import type { LoaderFunctionArgs } from "@remix-run/node";`

## 8. Re-defining the same data via parent + child loaders

**Smell**: Both `app/routes/projects.tsx` and `app/routes/projects.$id.tsx` independently call `db.project.findMany`.

**Why bad**: Two sources of truth, doubled DB queries, divergent shapes after revalidation.

**Fix**: Load once at the highest matching route and read via `useRouteLoaderData("routes/projects")` in children.

## Review prompts

- Is every `params.x` access guarded by `invariant` or a schema parse?
- Does the loader return any object that originates from an ORM `findUnique`/`findMany` without explicit field projection?
- Is anything in the returned object named after a secret (`password`, `token`, `apiKey`, `internal_`)?
- Are 404 / auth short-circuits using `throw new Response(...)` or `throw redirect(...)` (not `throw new Error(...)`)?
- Is there a `useEffect` in the default export that fetches non-browser-API data?
- Does the file still import `LoaderArgs` from `@remix-run/node`?
