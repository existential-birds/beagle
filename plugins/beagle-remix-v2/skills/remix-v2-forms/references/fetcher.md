# `useFetcher`

A non-navigating submission channel. `useFetcher` posts to a route
`action` (or loads from a route `loader`) and triggers the same loader
revalidation as `<Form>` — but it does not change the URL, does not add
a history entry, and does not reset scroll. Each `useFetcher()` call
returns an independent fetcher, so concurrent submissions in different
components do not share pending state.

## Signature

```tsx
const fetcher = useFetcher<TLoaderOrAction>({ key? });

// Returned API
fetcher.Form          // <fetcher.Form method="post"> — like <Form>, no nav
fetcher.submit(data, options?)  // programmatic submit
fetcher.load(href)    // GET-load data from a route's loader
fetcher.state         // "idle" | "submitting" | "loading"
fetcher.data          // last loader/action response (typed via generic)
fetcher.formData      // FormData in flight (populated while state !== "idle")
fetcher.formAction    // target action URL while in flight
fetcher.formMethod    // method while in flight
```

State transitions: `idle → submitting → loading → idle` (submitting only
present for non-GET).

## When to Reach for `useFetcher`

- Inline edit on a list row (favorite, like, increment, status toggle).
- Mutation from a popover/modal that should leave the underlying page
  intact.
- Combobox results, popover content, prefetch — `fetcher.load()`.
- Any mutation where a URL change would be wrong (no shareable URL, no
  new screen).

Use `<Form>` instead whenever the URL should change after the mutation
(create a record, delete and go back to list, multi-step flow).

## Inline Mutation (No URL Change)

```tsx
// app/components/favorite-button.tsx
import { useFetcher } from "@remix-run/react";

export function FavoriteButton({ id, favorited }: { id: string; favorited: boolean }) {
  const fetcher = useFetcher();
  // Optimistic: trust the in-flight intent if present.
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

Each row gets its own `useFetcher`, so two rows submitting at once do not
share a pending state. The optimistic `pendingFavorited` reads directly
from `fetcher.formData` each render — no local state to drift on error.

## List Operations

For a list where each row can mutate, each row owns its own fetcher.
Page-global `useNavigation()` will NOT observe fetcher activity. If you
want a "something is loading anywhere" indicator, use `useFetchers()` to
enumerate all in-flight fetchers.

```tsx
import { useFetchers } from "@remix-run/react";

function GlobalSpinner() {
  const fetchers = useFetchers();
  const anyBusy = fetchers.some((f) => f.state !== "idle");
  return anyBusy ? <Spinner /> : null;
}
```

## Popovers and `fetcher.load`

`fetcher.load(href)` fetches a route's loader without navigating. Useful
for hover cards, comboboxes, and prefetch.

```tsx
import { useEffect } from "react";
import { useFetcher } from "@remix-run/react";

export function UserHoverCard({ id }: { id: string }) {
  const fetcher = useFetcher<typeof loader>();
  useEffect(() => {
    if (fetcher.state === "idle" && !fetcher.data) {
      fetcher.load(`/users/${id}`);
    }
  }, [id, fetcher]);
  if (fetcher.state === "loading") return <p>Loading...</p>;
  if (!fetcher.data) return null;
  return <UserCard user={fetcher.data} />;
}
```

## Programmatic Submission with `fetcher.submit`

```tsx
const fetcher = useFetcher();

// Submit raw FormData
const fd = new FormData();
fd.set("intent", "delete");
fetcher.submit(fd, { method: "post", action: `/items/${id}` });

// Submit a plain object (encoded as FormData)
fetcher.submit({ intent: "archive" }, { method: "post" });

// Post JSON instead of FormData
fetcher.submit({ ids: [1, 2, 3] }, {
  method: "post",
  encType: "application/json",
});
```

When you submit with `encType: "application/json"`, in the action use
`await request.json()` — `request.formData()` will throw.

## Reading `fetcher.data`

`fetcher.data` is the typed response of the last action or loader call
through this fetcher. Use the generic `useFetcher<typeof action>()` to
get the serialized action return type, including validation errors.

```tsx
const fetcher = useFetcher<typeof action>();
const error = fetcher.data?.errors?.title;
```

`fetcher.data` persists until the fetcher next submits, similar to
`useActionData`.

## Shared Fetchers via `fetcherKey`

A `useFetcher({ key })` and a `<Form navigate={false} fetcherKey={key}>`
with the same key share submission state. Useful when a submission
should remain observable while the user navigates to a different
component — e.g. a sidebar that watches an in-flight upload started on
another route. Surprising when reused accidentally.

```tsx
// Sidebar — observe whether a known fetcher is in flight
import { useFetchers } from "@remix-run/react";

function UploadStatus() {
  const fetchers = useFetchers();
  const upload = fetchers.find((f) => f.key === "avatar-upload");
  return upload?.state !== "idle" ? <p>Uploading...</p> : null;
}
```

## Anti-Patterns

- **`useFetcher` when the URL should change** — no history entry, no
  scroll reset, no shareable URL, back button skips the just-completed
  flow. Use `<Form>` + `redirect()`.
- **`useNavigation()` to drive a per-row spinner inside a list where
  each row uses `useFetcher`** — `useNavigation` does not observe
  fetcher activity, so the spinner never lights up. Use the per-row
  `fetcher.state`.
- **Single `useFetcher` shared across a list** — submissions from
  different rows clobber each other's `formData` and `state`. Each row
  needs its own fetcher.
- **Mirroring `fetcher.formData.get("field")` into local React state**
  for optimistic rendering — two sources of truth. On error,
  `fetcher.data` returns the failure but local state still shows the
  optimistic value. Read from `fetcher.formData` each render.

## Gotchas

- `useNavigation` **does not observe fetchers**. Use `useFetchers()` for
  a page-wide "anything in flight" view.
- `fetcher.formData` is cleared when state returns to `idle`. After
  success, render against the refreshed loader data; after error,
  derive UI from `fetcher.data?.errors`.
- `fetcher.Form` with `method="get"` calls the matched route's loader,
  not its action — same as `<Form method="get">`.
- Two fetchers with the same explicit `key` share state. Without a key,
  each `useFetcher()` call is independent even in the same component.
