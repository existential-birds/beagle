# Optimistic UI

Remix v2 exposes the in-flight submission as `FormData` while the
mutation is pending. Reading that `FormData` synchronously each render
is the canonical way to show optimistic values — no local state, no
mirroring, no drift.

## The Two Sources

- `useNavigation().formData` — the `FormData` of the active page-level
  `<Form>` submission. Populated when `navigation.state !== "idle"` for a
  non-GET form submission. Cleared at `idle`.
- `useFetcher().formData` — the `FormData` of the active fetcher
  submission. Populated when `fetcher.state !== "idle"`. Cleared at
  `idle`.

Both are the **canonical** optimistic source: populated synchronously on
submit, automatically reverted when the action completes and loaders
revalidate.

## Why Not Local State

```tsx
// Anti-pattern — do not do this
const [optimisticCount, setOptimisticCount] = useState(count);

function onSubmit() {
  setOptimisticCount((c) => c + 1);
  fetcher.submit(...);
}
```

Two sources of truth. On error, `fetcher.data` returns the failure but
`optimisticCount` still shows the incremented value. On reload, local
state resets but the server may have completed the mutation. The user
sees flicker, ghost values, and stale UI.

Instead, derive optimistic state from `fetcher.formData` directly.

## Pattern: Counter / Quantity

```tsx
import { useFetcher } from "@remix-run/react";

export function CartCount({ count }: { count: number }) {
  const fetcher = useFetcher({ key: "add-to-bag" });
  const inFlight = Number(fetcher.formData?.get("quantity") ?? 0);
  const optimistic = count + inFlight;
  return <span aria-live="polite">{optimistic}</span>;
}
```

While the submission is in flight, `fetcher.formData.get("quantity")`
holds the value the user submitted. When `fetcher.state` returns to
`idle`, loaders have revalidated, `count` reflects the new server value,
and `inFlight` is `0` again. No code path needs to "revert on failure":
on failure, `fetcher.formData` clears and you fall back to the
unchanged server `count`.

## Pattern: Toggle (Favorite / Like)

```tsx
import { useFetcher } from "@remix-run/react";

export function FavoriteButton({ id, favorited }: { id: string; favorited: boolean }) {
  const fetcher = useFetcher();
  const pendingFavorited = fetcher.formData
    ? fetcher.formData.get("favorited") === "true"
    : favorited;
  return (
    <fetcher.Form method="post" action={`/items/${id}/favorite`}>
      <input type="hidden" name="favorited" value={String(!pendingFavorited)} />
      <button aria-pressed={pendingFavorited}>
        {pendingFavorited ? "Unfavorite" : "Favorite"}
      </button>
    </fetcher.Form>
  );
}
```

The hidden input encodes the new target state. `pendingFavorited` is the
single source of truth for what the UI should display — drawn from the
in-flight `FormData` when present, otherwise from the server prop.

## Pattern: Optimistic via `useNavigation` (Page Form)

For a `<Form>` submission (not a fetcher), read `useNavigation().formData`:

```tsx
import { Form, useNavigation } from "@remix-run/react";

export default function EditTitle({ title }: { title: string }) {
  const nav = useNavigation();
  const optimisticTitle =
    nav.formAction === "/title" && nav.formData
      ? String(nav.formData.get("title") ?? title)
      : title;
  return (
    <>
      <h1>{optimisticTitle}</h1>
      <Form method="post" action="/title">
        <input name="title" defaultValue={title} />
        <button>Save</button>
      </Form>
    </>
  );
}
```

Filter on `nav.formAction` so unrelated navigations don't trigger this
component's optimistic render.

## When to Apply Optimistic UI

Apply it when:

- The mutation almost always succeeds (favorites, likes, increments,
  toggles, quantity changes).
- The user's intent is unambiguous and easily reverted.
- A round-trip delay is perceptible (>~100ms) and would feel sluggish.

Skip it when:

- The mutation has meaningful failure modes (payment, account changes,
  destructive deletes) — the user expects to see the actual result.
- The new value depends on server-computed data (auto-generated IDs,
  derived fields, slugs).
- The optimistic render would mislead the user about real state
  (insufficient funds, permission denied, conflict).

## Reverting on Failure

You don't have to. When the action returns an error response, the
fetcher transitions through `loading` to `idle`. `fetcher.formData`
clears. Your render falls back to the server value. The UI "reverts"
automatically.

What you should do on failure: read `fetcher.data` for the error and
surface it.

```tsx
const fetcher = useFetcher<typeof action>();
const pendingFavorited = fetcher.formData
  ? fetcher.formData.get("favorited") === "true"
  : favorited;
const error = fetcher.state === "idle" ? fetcher.data?.error : null;
return (
  <>
    <fetcher.Form method="post" action={`/items/${id}/favorite`}>
      <input type="hidden" name="favorited" value={String(!pendingFavorited)} />
      <button aria-pressed={pendingFavorited}>...</button>
    </fetcher.Form>
    {error ? <p role="alert">{error}</p> : null}
  </>
);
```

## Anti-Patterns

- **Mirroring `fetcher.formData.get("field")` into `useState`.** Two
  sources of truth; ghost values on error.
- **Setting optimistic state inside `onSubmit`.** Stops working without
  JS; diverges from `fetcher.state` on double-submit.
- **Applying optimistic UI to destructive actions** (delete account,
  irreversible payment) — the user needs to see the real outcome.
- **Optimistic IDs / slugs.** Server-generated values cannot be guessed
  client-side. Wait for `fetcher.data` or revalidation.

## Gotchas

- `formData.get(key)` returns `FormDataEntryValue | null` (string or
  File). Cast or compare explicitly:
  `formData.get("favorited") === "true"`.
- `useNavigation().formData` is page-global. Filter on `formAction` to
  avoid one form's submission lighting up another form's optimistic UI.
- After a successful action, the optimistic value should match the
  server value — but loader revalidation is async. There is a brief
  window where `fetcher.formData` has cleared and the loader has not yet
  returned. Display the new server value as soon as it's available; the
  gap is normally a single tick.
