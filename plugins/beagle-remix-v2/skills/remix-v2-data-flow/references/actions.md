# Actions

Actions are server-only handlers for non-GET requests (POST, PUT, PATCH, DELETE) targeting a route. They are where data mutations live. Actions and loaders co-locate in the same route module: "loader = read, action = write."

## Signature

```ts
import { type ActionFunctionArgs } from "@remix-run/node";

export async function action(
  { request, params, context }: ActionFunctionArgs,
): Promise<Response> {
  // ...
}
```

The v2 type name is `ActionFunctionArgs`. The v1 alias `ActionArgs` is deprecated.

## Parsing FormData

```ts
export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const title = form.get("title");
  // ...
}
```

`request.formData()` returns a standard `FormData`. Every value is `FormDataEntryValue` (`string | File`) — never trust the static type, always validate. Type assertions like `form.get("title") as string` hide injection and type-confusion bugs.

## Validation with zod (or valibot)

Server-side validation is mandatory; client validation can always be bypassed.

```tsx
// app/routes/projects.new.tsx
import { json, redirect, type ActionFunctionArgs } from "@remix-run/node";
import { useActionData, Form } from "@remix-run/react";
import { z } from "zod";

const NewProject = z.object({
  title: z.string().min(1).max(120),
  description: z.string().max(2000).optional(),
});

export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const parsed = NewProject.safeParse(Object.fromEntries(form));

  if (!parsed.success) {
    return json(
      {
        errors: parsed.error.flatten().fieldErrors,
        values: Object.fromEntries(form),
      },
      { status: 400 },
    );
  }

  const project = await db.project.create({ data: parsed.data });
  return redirect(`/projects/${project.id}`);
}
```

Two important moves above:

1. **Return a 400 on validation failure** so the form route still renders and the user sees inline errors.
2. **Echo `values` back** so the form can rehydrate after a failed submit.

valibot follows the same shape; substitute `safeParse` / `flatten()` equivalents per its API.

## Typed `useActionData`

```tsx
export default function NewProject() {
  const actionData = useActionData<typeof action>();

  return (
    <Form method="post">
      <input name="title" defaultValue={(actionData?.values?.title as string) ?? ""} />
      {actionData?.errors?.title && <p role="alert">{actionData.errors.title}</p>}
      <button type="submit">Create</button>
    </Form>
  );
}
```

`useActionData<typeof action>()` returns `SerializeFrom<typeof action> | undefined`. The same serialization rules from loaders apply (Dates become strings, undefined is stripped). It is **scoped to the current route** — it cannot read data from parent or child actions. To share an action result up or down the tree, lift the action to a higher route or use a `useFetcher` with a `key`.

## Redirect-After-Success (PRG)

The Post/Redirect/Get pattern is the v2 default for successful mutations: an action that returns a `redirect()` causes the browser to navigate to the target route, which prevents accidental re-submission on refresh and naturally surfaces the freshly mutated state.

```ts
const project = await db.project.create({ data: parsed.data });
return redirect(`/projects/${project.id}`);
```

If you want to stay on the same route after success (e.g. an inline editor), return `json({ ok: true, project })` instead — but then you own pending UI and reset logic via `useActionData`.

## Error Returns vs Throws

| Outcome              | Mechanism                                              | Where it surfaces                    |
|----------------------|--------------------------------------------------------|--------------------------------------|
| Validation error     | `return json({ errors }, { status: 400 })`             | `useActionData<typeof action>()`     |
| Auth failure         | `throw redirect("/login")`                             | Browser navigation                   |
| 404 / 403            | `throw new Response(..., { status: 404 })` or `throw json({...}, { status: 404 })` | `ErrorBoundary` via `useRouteError()` |
| Unexpected exception | Unhandled throw (any `Error`)                          | `ErrorBoundary` (no `status` field)  |

An `action` that returns `null` / `undefined` with no error handling is an anti-pattern: `useActionData()` is `undefined`, errors are silently swallowed, and the user sees nothing. Either throw to the boundary or return `json({ error })` and render it.

## Index Route Actions

Only the deepest matching action runs. When a parent layout and its index child both define an action, target the index explicitly:

```tsx
<Form action="/things?index" method="post" />
```

Without `?index`, the layout action wins.

## Fetcher Actions (No Navigation)

For inline edits, list-row toggles, and optimistic UI, post to a route action without a URL change via `useFetcher`:

```tsx
import { useFetcher } from "@remix-run/react";

export function StarButton({ project }: { project: Project }) {
  const fetcher = useFetcher<typeof action>();

  // Predict the next state from in-flight FormData for optimistic UI.
  const starred = fetcher.formData
    ? fetcher.formData.get("starred") === "1"
    : project.starred;

  return (
    <fetcher.Form method="post" action={`/projects/${project.id}/star`}>
      <input type="hidden" name="starred" value={starred ? "0" : "1"} />
      <button aria-pressed={starred}>{starred ? "★" : "☆"}</button>
    </fetcher.Form>
  );
}
```

After the fetcher resolves, Remix automatically revalidates affected loaders.

## File Uploads

`request.formData()` returns a `File` for `<input type="file">` fields. For large uploads, prefer `unstable_parseMultipartFormData` with `unstable_createFileUploadHandler` or `unstable_createMemoryUploadHandler` from `@remix-run/node` — the bare `request.formData()` buffers the entire body in memory.

## Don't Hit Actions With Manual `fetch()`

Calling `fetch("/projects/123/star", { method: "POST" })` from a component bypasses revalidation, pending state, progressive enhancement, and CSRF affordances built into `<Form>` and `useFetcher`. Use `useFetcher().submit()` or `useFetcher().load()` instead — same UX without a URL change, and Remix wires up the lifecycle for you.

## Pending State on Submit

```tsx
import { useNavigation, Form } from "@remix-run/react";

export default function SaveButton() {
  const nav = useNavigation();
  // POST flow: idle → submitting → loading → idle. GET: idle → loading → idle.
  // formMethod is UPPERCASE in v2.
  const busy = nav.state !== "idle" && nav.formMethod === "POST";

  return (
    <Form method="post">
      <button type="submit" disabled={busy}>
        {busy ? "Saving…" : "Save"}
      </button>
    </Form>
  );
}
```

Missing pending UI is a real UX bug — users double-click and double-submit. Gate on `nav.state !== "idle"` (or `fetcher.state !== "idle"` for non-navigating mutations).

## Action Anti-Pattern Recap

- **No server-side validation** — client validation is bypassable; always re-validate on the server with zod / valibot and return `{ status: 400 }` on failure.
- **`form.get("title") as string`** — `FormDataEntryValue` is `string | File`; type assertions hide injection bugs. Parse with `Object.fromEntries(form)` and a schema.
- **Returning `null` from an action** — `useActionData()` becomes `undefined` and errors are silently swallowed. Either `throw json({ message }, { status: 500 })` to hit `ErrorBoundary` or `return json({ error })`.
- **No redirect after success** — re-rendering the same form route on success risks accidental re-submission on refresh. Redirect via PRG unless you have a specific reason to stay.
- **Manual `fetch()` instead of `useFetcher`** — bypasses revalidation, pending state, and progressive enhancement.
- **Forgetting `?index`** when posting from a layout to its index action — the layout action runs instead.

## Cross-Reference

- Loader-side details: see [loaders.md](loaders.md) for `useLoaderData<typeof loader>()` typing, `redirect()` semantics, and sensitive-data filtering — the same rules apply to action returns.
- Pending UI and revalidation: see [revalidation.md](revalidation.md) for `useNavigation`, `useFetcher`, `useRevalidator`, `shouldRevalidate`, and the v1 → v2 `useTransition` rename.
