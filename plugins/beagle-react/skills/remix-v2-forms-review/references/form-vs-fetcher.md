# Form vs Fetcher Misuse

Flag code that bypasses Remix's mutation lifecycle or picks the wrong
primitive for the job. See
[beagle-react:remix-v2-forms](../../remix-v2-forms/SKILL.md) for the
decision gates and canonical patterns.

## Anti-pattern 1 — Manual `fetch()` for in-app mutations

```tsx
// BAD
function CreatePost() {
  return (
    <form
      onSubmit={async (e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        await fetch("/api/posts", { method: "POST", body: fd });
      }}
    >
      <input name="title" />
      <button>Create</button>
    </form>
  );
}
```

**Why bad:** Bypasses the route `action` entirely. Loaders do not
revalidate, so the UI shows stale data until a hard reload. Progressive
enhancement is broken (the form does nothing without JS). There is no
`useNavigation`/`useFetcher` pending state hook. Race-safe out-of-order
submission handling is gone.

**Fix:** Replace with `<Form method="post" action="/posts">` (URL
changes) or `<fetcher.Form method="post" action="/posts">` (stays in
place). Move the network call into that route's `action`.

**Exemptions — do NOT flag:**

- `fetch()` to a third-party URL (Stripe, Mapbox, an unrelated API).
- `fetch()` inside an `action` or `loader` on the server.
- `fetch()` in a webhook handler or background worker.

## Anti-pattern 2 — Native `<form>` for POST mutations

```tsx
// BAD
import { useActionData } from "@remix-run/react";
export default function Signup() {
  return (
    <form method="post">  {/* lowercase — native, not Remix */}
      <input name="email" />
      <button>Sign up</button>
    </form>
  );
}
```

**Why bad:** It works — Remix `action`s accept native form posts — but a
hard navigation happens on submit, scroll position resets, and there is
no way to read pending state, no `useNavigation.formData`, no
optimistic UI surface. The user loses every benefit of client
enhancement.

**Fix:** Import `Form` from `@remix-run/react`. Native `<form>` is fine
ONLY for forms that intentionally target external URLs or expect a full
document reload (rare; document the reason).

**Exemptions — do NOT flag:**

- `<form action="https://external.example.com/...">` — external target.
- `<form method="get">` — GET forms work identically as native or
  `<Form>`; the Remix component still has benefits (no scroll reset)
  but the native version is not a bug.
- `<form>` rendered inside a markdown/CMS-rendered body.

## Anti-pattern 3 — `useFetcher` when the URL should change

```tsx
// BAD — "create" flow with no redirect
function NewItem() {
  const fetcher = useFetcher();
  return (
    <fetcher.Form method="post" action="/items">
      <input name="title" />
      <button>Create</button>
    </fetcher.Form>
  );
}
```

**Why bad:** No history entry, no scroll reset, no shareable URL for
the new record, and the user's back button now skips the just-completed
flow. Usually a sign the developer worked around `<Form>` because the
pending-state ergonomics felt clumsy.

**Fix:** Use `<Form>` and `redirect(\`/items/\${created.id}\`)` from
the action. Derive pending state from `useNavigation()` with a
`formAction` check.

**Exemptions — do NOT flag:**

- A "quick-add" widget where the user stays on the dashboard.
- Inline create-in-place rows in a table.
- Drafts/autosave where the URL deliberately stays put.

## Anti-pattern 4 — `<Form>` when each row needs independent pending state

```tsx
// BAD — every row flickers on any submission
function TaskList({ tasks }: { tasks: Task[] }) {
  const nav = useNavigation();
  return tasks.map((t) => (
    <Form key={t.id} method="post" action={`/tasks/${t.id}/toggle`}>
      <button disabled={nav.state !== "idle"}>
        {nav.state !== "idle" ? "..." : "Toggle"}
      </button>
    </Form>
  ));
}
```

**Why bad:** `useNavigation` is page-global. The moment any row
submits, every other row's button disables. Also: a `<Form>` submission
navigates, so clicking row 5 changes the URL to `/tasks/5/toggle`.

**Fix:** Use `useFetcher()` per row and key pending state off that
fetcher's `fetcher.state`. Each `useFetcher()` call returns an
independent submission channel.

```tsx
function TaskRow({ task }: { task: Task }) {
  const fetcher = useFetcher();
  return (
    <fetcher.Form method="post" action={`/tasks/${task.id}/toggle`}>
      <button disabled={fetcher.state !== "idle"}>Toggle</button>
    </fetcher.Form>
  );
}
```

## Anti-pattern 5 — Action returning JSON on a create surface

```tsx
// BAD
export async function action({ request }: ActionFunctionArgs) {
  const fd = await request.formData();
  const created = await createItem(fd);
  return json({ ok: true, id: created.id });
}
```

**Why bad:** The user is stranded on the `/new` URL after success.
Refreshing prompts the browser to resubmit the POST. The back button
revisits the form. Reset logic has to be wired manually.

**Fix:** `return redirect(\`/items/\${created.id}\`)`. Only return
`json()` from a create surface for validation errors or when the user
must stay on the same page.

## Verification before reporting

1. Confirm the form's `method` is POST (or PUT/PATCH/DELETE). GET forms
   are exempt from these rules.
2. Confirm there is a real route `action` (or that one is expected).
   `fetch()` against a deliberately non-Remix endpoint may be correct.
3. Confirm `<form>` is the lowercase native element, not the imported
   `Form` from `@remix-run/react`. A grep for `from "@remix-run/react"`
   in the file usually settles it.
4. For row-pending issues, confirm the surrounding list actually
   renders multiple instances — a one-row "list" is not a bug.
5. For "should redirect" findings, confirm the route's path segment
   implies creation (e.g. `/items/new`, `/posts/create`). A nested
   form on a dashboard or detail page may legitimately stay put.

## Severity guidance

- **High** — Manual `fetch()` for any POST in-app mutation; missing
  `encType` on a file upload; trusting `formData.get()` as DB input.
- **Medium** — Native `<form>` for POST; `useFetcher` where `<Form>` +
  `redirect` is correct; action returning `json` on a `/new` route.
- **Low** — `<Form>` where `useFetcher` would be lighter (rarely worth
  flagging unless the surface lists multiple rows).
