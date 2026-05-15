# Throw vs Return — Responses, Errors, and `handleError`

In Remix v2, only **thrown** values reach `ErrorBoundary`. A `return`
from a loader/action is a successful result — no matter the status
code. Choosing throw-vs-return wrong is one of the most common
boundary bugs because the code looks correct and types check.

Companion: `app/entry.server.tsx` may export `handleError` for
server-side error reporting. Its contract has a sharp edge: it does
**not** fire for thrown `Response`s.

## Canonical patterns

```tsx
// Loader: throw for 4xx/5xx, return for success
export async function loader({ params }: LoaderFunctionArgs) {
  invariant(params.invoiceId, "Missing invoiceId");
  const invoice = await db.invoice.findUnique({ where: { id: params.invoiceId } });
  if (!invoice) {
    throw json({ message: `Invoice ${params.invoiceId} not found` }, { status: 404 });
  }
  return json({ invoice });
}

// Action: throw for auth / validation hard-stops, return for field errors
export async function action({ request }: ActionFunctionArgs) {
  const user = await requireUser(request);              // throws Response on 401
  const form = await request.formData();
  const parsed = schema.safeParse(Object.fromEntries(form));
  if (!parsed.success) {
    return json({ errors: parsed.error.flatten() }, { status: 400 }); // returned — rendered by route
  }
  await db.invoice.update({ where: { id: parsed.data.id }, data: parsed.data });
  return redirect(`/invoices/${parsed.data.id}`);
}
```

```tsx
// app/entry.server.tsx
export function handleError(
  error: unknown,
  { request }: LoaderFunctionArgs | ActionFunctionArgs,
) {
  if (request.signal.aborted) return;                  // ignore client disconnects
  if (error instanceof Error) {
    reportToSentry(error);
  } else {
    console.error("Non-Error thrown server-side:", error);
  }
}
```

## Anti-patterns to flag

### 1. Returning instead of throwing for 4xx / 5xx

**Pattern**

```tsx
export async function loader({ params }: LoaderFunctionArgs) {
  const post = await db.post.findUnique({ where: { slug: params.slug } });
  if (!post) {
    return json({ error: "Not found" }, { status: 404 }); // returned, not thrown
  }
  return json({ post });
}

export default function Post() {
  const data = useLoaderData<typeof loader>();
  if ("error" in data) return <p>{data.error}</p>;       // ad-hoc error branch
  return <article>{data.post.title}</article>;
}
```

**Why bad**

- The 404 case does *not* reach `ErrorBoundary`. The component now
  carries two-shape `data` and must branch on `"error" in data` —
  defeating the v2 model.
- The browser sees a 404 status with a successful HTML body. SEO tools
  and crawlers get mixed signals.
- The component types become a discriminated union of "success" and
  "error" shapes, which leaks into every consumer.

**Fix**

```tsx
if (!post) throw json({ message: "Not found" }, { status: 404 });
return json({ post });
```

The boundary now renders the 404; the component only deals with the
success shape.

### 2. Swallowing `error.data` (rendering an object as text)

**Pattern**

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error)) {
    return <p>{error.data}</p>;                          // error.data may be object
  }
  return null;
}
```

If the loader did `throw json({ message: "Forbidden" }, { status: 403 })`,
then `error.data` is `{ message: "Forbidden" }`. React renders this as
`"Objects are not valid as a React child"` and the boundary itself
crashes.

**Why bad**

`error.data` is typed `unknown`. The shape depends entirely on what
the loader threw. Boundaries that assume "data is a string" work for
some routes and fail for others.

**Fix**

Type-narrow before rendering:

```tsx
if (isRouteErrorResponse(error)) {
  const msg =
    typeof error.data === "string"
      ? error.data
      : typeof error.data === "object" && error.data && "message" in error.data
      ? String((error.data as { message: unknown }).message)
      : error.statusText;
  return <p>{msg}</p>;
}
```

Or define a shared `ErrorPayload` type and `throw json<ErrorPayload>(...)`.

### 3. Throwing a non-`Response` / non-`Error` value

**Pattern**

```tsx
if (!input.email) throw "Email required";              // string
if (!user)       throw { code: 401, message: "Unauthorized" }; // POJO
```

**Why bad**

`useRouteError()` returns the value as `unknown`. Neither
`isRouteErrorResponse(error)` nor `error instanceof Error` matches, so
the boundary falls through to the "Unknown error" branch. Status code
information is lost. `handleError` receives a non-`Error` value and
typically logs `"Non-Error thrown server-side"` with no stack.

**Fix**

Always throw a `Response` (for expected control flow — 4xx) or an
`Error` (for bugs — 5xx):

```tsx
if (!input.email) throw new Response("Email required", { status: 400 });
if (!user)        throw json({ message: "Unauthorized" }, { status: 401 });
if (db.connection.state === "broken") throw new Error("DB connection lost");
```

### 4. Missing `handleError` in `entry.server.tsx`

**Pattern**

`app/entry.server.tsx` exports only `handleRequest`. No `handleError`,
no other server logging in place.

**Why bad**

In production, Remix logs runtime errors to `console.error` and shows
"Application Error" to the user. Without `handleError` the errors are
never piped to Sentry / Datadog / your reporter — they vanish into
stdout (or stderr depending on the host). You only learn about bugs
when users report them.

**Fix**

Export `handleError`. Filter aborted requests, narrow by type, report:

```tsx
export function handleError(error: unknown, { request }: LoaderFunctionArgs | ActionFunctionArgs) {
  if (request.signal.aborted) return;
  if (error instanceof Error) Sentry.captureException(error);
  else console.error("Non-Error thrown:", error);
}
```

### 5. Logging thrown `Response`s through `handleError`

**Pattern**

```tsx
export function handleError(error: unknown, { request }: LoaderFunctionArgs | ActionFunctionArgs) {
  Sentry.captureException(error);                       // also for Responses?
}
```

Then someone wraps a loader in `try { ... } catch (e) { handleError(e, ...); throw e; }`
to "make sure 404s are tracked."

**Why bad**

`handleError` is **never** called for thrown `Response`s by the
framework — Remix treats them as expected control flow. Manually
re-routing every 404/403 through Sentry turns normal user navigation
("user clicks expired link") into pages of error alerts and burns the
Sentry quota.

**Fix**

Trust the framework contract. If you need to track specific 4xx for
product reasons (e.g., suspicious 403 spikes), log at the **throw
site** with structured fields — not through `handleError`:

```tsx
if (!user) {
  metrics.increment("auth.unauthorized", { route: "/admin" });
  throw json({ message: "Unauthorized" }, { status: 401 });
}
```

## Cross-references

- Boundary shape (narrowing, props, hook) → [boundary-shape.md](boundary-shape.md)
- Root boundary specifics → [root-boundary.md](root-boundary.md)
- `handleError` doc: https://remix.run/docs/en/main/file-conventions/entry.server
- `throw` semantics: https://remix.run/docs/en/main/guides/errors
