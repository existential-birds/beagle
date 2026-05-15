# `<Form>` from `@remix-run/react`

The navigating, progressively-enhanced form component. It posts to a route
`action`, then triggers full-page revalidation of every loader in the
matched route tree.

## Signature

```tsx
<Form
  method="get | post | put | patch | delete"  // Remix accepts lowercase JSX method and normalizes; v2 docs document them as uppercase. formMethod on useNavigation/fetcher always returns UPPERCASE.
  action?={string}
  encType?="application/x-www-form-urlencoded" | "multipart/form-data" | "application/json" | "text/plain"
  replace?={boolean}
  reloadDocument?={boolean}
  navigate?={boolean}          // false → behaves like <fetcher.Form>
  fetcherKey?={string}         // observed via useFetchers()
  preventScrollReset?={boolean}
  viewTransition?={boolean}
/>
```

## `<Form>` vs native `<form>` vs `fetch()`

| Aspect | `<Form>` from `@remix-run/react` | Native `<form>` | `fetch()` in `onSubmit` |
|---|---|---|---|
| Submits to route `action` | Yes | Yes (hard navigation) | Yes (if URL matches) |
| Loaders revalidate | Yes (client-side) | Yes (full reload) | **No** |
| Works without JS | Yes | Yes | **No** |
| `useNavigation()` pending state | Yes | No (full reload) | **No** |
| `useNavigation().formData` for optimistic UI | Yes | No | **No** |
| Scroll position preserved | Yes (configurable) | No | N/A |

Use `<Form>` from `@remix-run/react` for in-app mutations. Native `<form>`
is fine only for forms that intentionally target external URLs or want a
full document reload. Never use `fetch()` for in-app mutations — it
bypasses the entire Remix action lifecycle, leaves loaders stale, and
breaks progressive enhancement.

## Progressive Enhancement

`<Form method="post">` works before client JS hydrates. The browser
performs a native POST, the server runs the action, returns a redirect or
re-renders, and the page works. When JS is available, Remix intercepts the
submission, runs the action, and revalidates loaders without a full page
reload.

This is why `useState`/`setIsLoading(true)` is wrong for tracking
submission: it does not exist before hydration, and it duplicates state
Remix already owns. Always derive busy state from `useNavigation()`.

PE caveats:

- Native HTML forms only support `method="get"` and `method="post"`.
  Without JS, `put` / `patch` / `delete` degrade to `get`, which usually
  hits the loader instead of the action and 405s. If PE matters, use
  `method="post"` and dispatch via an `intent` field.
- `GET <Form>` does not call the action — it triggers a navigation with
  form fields as URL search params, hitting the loader. Useful for
  search/filter UIs; confusing if you expected the action to run.

## Redirect After Success

Always `redirect(...)` on success. Returning `json({ ok: true })` from a
mutation that should redirect strands the user on the form URL:
refreshing re-submits via the browser's POST-resubmit prompt, and the
back button revisits the form.

```tsx
import { json, redirect, type ActionFunctionArgs } from "@remix-run/node";

export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const title = String(form.get("title") ?? "");
  if (!title) return json({ errors: { title: "Required" } }, { status: 400 });
  const created = await createItem({ title });
  return redirect(`/items/${created.id}`);
}
```

Return `json(...)` only for validation errors or when the user must stay
on the same page after the mutation.

## Validation Errors via `useActionData`

`useActionData<typeof action>()` returns the most recent action result
for the current route. It persists across renders until the user
navigates away or another action runs — so success banners derived from
`actionData` will linger until next nav.

```tsx
import { json, redirect, type ActionFunctionArgs } from "@remix-run/node";
import { Form, useActionData, useNavigation } from "@remix-run/react";

export async function action({ request }: ActionFunctionArgs) {
  const form = await request.formData();
  const email = String(form.get("email") ?? "");
  const password = String(form.get("password") ?? "");

  const errors: Record<string, string> = {};
  if (!email.includes("@")) errors.email = "Invalid email";
  if (password.length < 12) errors.password = "Min 12 characters";
  if (Object.keys(errors).length) return json({ errors }, { status: 400 });

  await createUser({ email, password });
  return redirect("/dashboard");
}

export default function Signup() {
  const actionData = useActionData<typeof action>();
  const nav = useNavigation();
  const busy = nav.state !== "idle" && nav.formAction === "/signup";
  return (
    <Form method="post" replace>
      <input name="email" type="email" />
      {actionData?.errors?.email ? <em>{actionData.errors.email}</em> : null}
      <input name="password" type="password" />
      {actionData?.errors?.password ? <em>{actionData.errors.password}</em> : null}
      <button disabled={busy}>{busy ? "Signing up..." : "Sign Up"}</button>
    </Form>
  );
}
```

`redirect()` on success clears `useActionData` and resets the form
naturally on the new route. `json({ errors }, { status: 400 })`
re-renders the same route with the errors visible.

## Validate Input — `FormData.get()` is `string | File | null`

`FormData.get()` returns `FormDataEntryValue | null`. Implicit coercion
silently lets attackers submit empty strings, repeated keys, or files
where strings are expected. Cast with `String(form.get("x") ?? "")` and
run a schema validator (Zod, Valibot) before any DB call.

## Programmatic Submission with `useSubmit`

```tsx
import { Form, useSubmit } from "@remix-run/react";

export default function SearchBar() {
  const submit = useSubmit();
  return (
    <Form
      method="get"
      action="/search"
      onChange={(event) => submit(event.currentTarget, { replace: true })}
    >
      <input type="search" name="q" />
    </Form>
  );
}
```

`replace: true` keeps the back button useful — one history entry instead
of one per keystroke.

`useSubmit` also accepts `FormData`, `URLSearchParams`, or a plain
object. With `{ encType: "application/json" }` it posts JSON, not
FormData — in the action use `await request.json()` because
`request.formData()` will throw.

## Reset Uncontrolled Form on Success

React does not unmount uncontrolled inputs across a same-route mutation,
so the DOM keeps the old value until you call `form.reset()`.

```tsx
import { useEffect, useRef } from "react";
import { Form, useActionData, useNavigation } from "@remix-run/react";

export default function CommentForm() {
  const formRef = useRef<HTMLFormElement>(null);
  const nav = useNavigation();
  const actionData = useActionData<typeof action>();
  useEffect(() => {
    if (nav.state === "idle" && actionData?.ok) formRef.current?.reset();
  }, [nav.state, actionData]);
  return (
    <Form ref={formRef} method="post">
      <input name="body" />
      <button>Post</button>
    </Form>
  );
}
```

For fetchers, swap `nav` for `fetcher` and key the effect on
`fetcher.state` / `fetcher.data`.

## Anti-Patterns

- **`onSubmit={(e) => { e.preventDefault(); fetch(...) }}`** — bypasses
  the action lifecycle, leaves loaders stale, breaks PE. Replace with
  `<Form method="post" action="/...">` and move logic to the action.
- **Native `<form method="post">`** for in-app mutations — works but loses
  client-side enhancement and gives no `useNavigation` hook. Import
  `Form` from `@remix-run/react`.
- **`useState`/`setIsLoading(true)` for submission state** — diverges
  from `navigation.state` on errors and double-submits; stops working
  without JS. Derive from `useNavigation()`.
- **Returning `json({ ok: true })` when you should redirect** — strands
  the user on a stale URL. `return redirect("/items/" + created.id)`.

## Gotchas

- `useActionData` is **per-route, not per-intent**. To distinguish which
  intent ran, include the intent in the response or use a separate
  `useFetcher` per intent.
- `<Form method="post">` revalidates **all** loaders in the matched route
  tree. For high-frequency mutations, use `useFetcher` for granular
  control or `shouldRevalidate` per route to opt out.
- `replace` and `preventScrollReset` are independent. Setting one does
  not imply the other.
- `navigate={false}` on `<Form>` turns it into a fetcher form —
  equivalent to `<fetcher.Form>` but without holding the fetcher
  reference. Use `fetcherKey` to observe it via `useFetchers()`.
