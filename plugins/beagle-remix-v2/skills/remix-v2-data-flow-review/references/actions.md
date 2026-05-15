# Action Review Reference

Anti-patterns and review prompts for `export async function action` in Remix v2 route modules. See [beagle-remix-v2:remix-v2-data-flow](../../remix-v2-data-flow/SKILL.md) for canonical action patterns.

## 1. Unvalidated FormData

**Smell**:

```tsx
export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const title = form.get("title") as string;
  await db.project.create({ data: { title } });
  return redirect("/projects");
}
```

**Why bad**:

- `form.get("title")` is `FormDataEntryValue | null` (`string | File | null`). The `as string` assertion hides the `null` and `File` cases.
- Client-side validation is bypassable; the docs explicitly warn against trusting it.
- An attacker can submit empty strings, oversized payloads, or `File` objects where strings were expected. Schema validation is mandatory on the server.

**Fix**:

```tsx
import { z } from "zod";

const NewProject = z.object({
  title: z.string().min(1).max(120),
});

export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const parsed = NewProject.safeParse(Object.fromEntries(form));
  if (!parsed.success) {
    return json(
      { errors: parsed.error.flatten().fieldErrors, values: Object.fromEntries(form) },
      { status: 400 },
    );
  }
  const project = await db.project.create({ data: parsed.data });
  return redirect(`/projects/${project.id}`);
}
```

`Object.fromEntries(formData)` collapses repeated fields — for checkbox groups / multi-selects, use `formData.getAll("tag")` and feed it into the schema explicitly.

## 2. Returning `json` instead of `redirect` on success (broken PRG)

**Smell**:

```tsx
export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const project = await db.project.create({ data: { title: form.get("title") as string } });
  return json({ project }); // success → no redirect
}
```

**Why bad**: Without a redirect, the browser's URL stays on the form-submitting route. Pressing refresh re-POSTs the form (browser prompt "Confirm form resubmission?"), and the back button replays the mutation. This is the classic Post/Redirect/Get problem — Remix actions are designed to redirect on success.

**Fix**: `return redirect(\`/projects/\${project.id}\`);` on success. Keep `return json(...)` only for the validation-error branch where you want the user to stay on the form.

**Do not flag when**:

- The action is invoked via `useFetcher` and the route was never navigated to (fetcher actions do not change the URL, so PRG is not at stake).
- The action intentionally returns optimistic / interim data for an inline-edit UI consumed via `fetcher.data` — the URL never changed and refresh has no meaning.

## 3. Missing error branch / silent `return null`

**Smell**:

```tsx
export async function action({ request }: ActionFunctionArgs) {
  try {
    const form = await request.formData();
    await db.project.create({ data: { title: form.get("title") as string } });
    return redirect("/projects");
  } catch {
    return null; // swallowed
  }
}
```

**Why bad**: `useActionData()` becomes `undefined`, the UI shows no feedback, and the user retries blindly. `ErrorBoundary` cannot catch a returned value — only thrown ones.

**Fix**: Either let exceptions propagate (so `ErrorBoundary` handles them) or return a structured error:

```tsx
return json(
  { errors: { _form: "Could not create project. Please try again." } },
  { status: 500 },
);
```

For "this should never happen" cases: `throw json({ message }, { status: 500 })`.

## 4. Leaking server-only fields in `actionData`

**Smell**:

```tsx
export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const user = await db.user.findUnique({ where: { email: form.get("email") as string } });
  if (!user) return json({ error: "Not found" }, { status: 404 });
  return json({ user }); // ships passwordHash, etc.
}
```

**Why bad**: Action return values ship to the client just like loader return values. Returning a raw ORM record exposes password hashes, session tokens, API keys, and `internal_*` flags via `useActionData`.

**Fix**: Project to a safe DTO before returning:

```tsx
return json({ user: { id: user.id, email: user.email, name: user.name } });
```

**Field-name red flags** to grep for in action return values: `password`, `passwordHash`, `apiKey`, `secret`, `token`, `internal_`, `__`, `salt`, `mfaSeed`, `webhookSecret`, `csrfSecret`.

## 5. Manual `fetch()` to a Remix route from a component

**Smell**:

```tsx
function StarButton({ id }: { id: string }) {
  return (
    <button
      onClick={() =>
        fetch(`/projects/${id}/star`, { method: "POST" })
      }
    >
      Star
    </button>
  );
}
```

**Why bad**: Bypasses automatic revalidation, pending state (`fetcher.state`), progressive enhancement, and the CSRF / cookie flow built into `<Form>` and `useFetcher`. Errors are not surfaced via `useActionData`.

**Fix**: Use `useFetcher().submit()` or `<fetcher.Form>`:

```tsx
const fetcher = useFetcher<typeof action>();
return (
  <fetcher.Form method="post" action={`/projects/${id}/star`}>
    <button type="submit">Star</button>
  </fetcher.Form>
);
```

## 6. `ActionArgs` v1 type holdover

**Smell**: `import type { ActionArgs } from "@remix-run/node";`

**Why bad**: v2 renamed `ActionArgs` → `ActionFunctionArgs`. Old name may exist as a deprecated alias — flag during v2 review.

**Fix**: `import type { ActionFunctionArgs } from "@remix-run/node";`

## 7. `actionData` from the wrong route

**Smell**: A parent layout reads `useActionData()` expecting results from a child route's action.

**Why bad**: `useActionData` "cannot access data from other parent or child routes." The hook is scoped to the route module it is called from; results from a different route's action are unreachable here.

**Fix**: Lift the action to the parent route, or use `useFetcher` with a shared `key` so multiple components see the same fetcher state.

## Review prompts

- Is every `formData.get(...)` value validated by a schema before reaching the DB?
- Does the success branch end with `redirect(...)` (unless the action is a `useFetcher` target)?
- Does the catch / failure branch return structured `json({ errors }, { status })` or throw — never silently return `null`?
- Are any object literals in `return json(...)` derived from full ORM records without field projection?
- Does the file still import `ActionArgs` from `@remix-run/node`?
- Is there a manual `fetch("/route", { method: "POST" })` that should be a `useFetcher`?
