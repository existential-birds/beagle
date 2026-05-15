# Pending State Anti-patterns

Flag code that re-implements pending state Remix already owns, or wires
the wrong observer to the wrong submission. See
[beagle-remix-v2:remix-v2-forms](../../remix-v2-forms/SKILL.md) for the
`useNavigation` vs `fetcher.state` decision gates.

## Anti-pattern 1 — `useState` loading flag alongside `<Form>` / `useFetcher`

```tsx
// BAD
function Signup() {
  const [isLoading, setIsLoading] = useState(false);
  return (
    <Form
      method="post"
      onSubmit={() => setIsLoading(true)}
    >
      <input name="email" />
      <button disabled={isLoading}>
        {isLoading ? "Signing up..." : "Sign Up"}
      </button>
    </Form>
  );
}
```

**Why bad:** Duplicates state Remix already owns. The flag diverges
from `navigation.state` on:

- Server-side errors (state never flips back if you forget the
  `useActionData` effect).
- `redirect()` responses (the new route mounts a fresh component, so
  the flag is stuck `true` until cleanup runs).
- Double-submits and rapid clicks (no race-safe handoff).
- No JS — the button is enabled, the form posts, the flag never sets,
  so any reliance on it breaks progressive enhancement.

**Fix:** Derive busy state from `useNavigation()` for `<Form>` or
`fetcher.state` for `useFetcher`.

```tsx
const nav = useNavigation();
const busy = nav.state !== "idle" && nav.formAction === "/signup";
```

Filter by `formAction` whenever the surface might see other navigations
(sidebar links, sibling forms) — otherwise unrelated nav lights up your
spinner.

## Anti-pattern 2 — `useNavigation` driving a per-row spinner

```tsx
// BAD
function FavoriteList({ items }: { items: Item[] }) {
  const nav = useNavigation();
  return items.map((i) => (
    <fetcher.Form key={i.id} method="post" action={`/items/${i.id}/fav`}>
      <button disabled={nav.state !== "idle"}>Favorite</button>
    </fetcher.Form>
  ));
}
```

**Why bad:** `useNavigation` does **not** observe fetcher activity. If
each row submits via its own `useFetcher`, the page-level
`navigation.state` stays `"idle"` and the spinner never lights up.

Even if rows used `<Form>` instead, every row would disable on every
submission because `navigation.state` is page-global.

**Fix:** Use one `useFetcher()` per row and key pending state off that
fetcher's state. To express a true "anything in flight" indicator, use
`useFetchers()` at the page level.

```tsx
function Row({ item }: { item: Item }) {
  const fetcher = useFetcher();
  const pending = fetcher.state !== "idle";
  return (
    <fetcher.Form method="post" action={`/items/${item.id}/fav`}>
      <button disabled={pending} aria-busy={pending}>Favorite</button>
    </fetcher.Form>
  );
}
```

## Anti-pattern 3 — Missing pending state entirely

```tsx
// BAD — user gets no feedback during a 2s mutation
export default function Comment() {
  return (
    <Form method="post">
      <textarea name="body" />
      <button>Post</button>
    </Form>
  );
}
```

**Why bad:** The user double-clicks, submits twice, and waits with no
indication anything happened. On a slow connection, the form looks
broken.

**Fix:** Read `useNavigation()` (for `<Form>`) or `fetcher.state` (for
`useFetcher`) and disable the submit button or surface a spinner.
Filter on `formAction` so an unrelated nav (sidebar link) does not
disable your form.

**Exemptions — do NOT flag:**

- The button is non-interactive after submit (e.g. unmounted by a
  conditional render that depends on `useActionData`).
- The surface is read-only / no real mutation.
- A wrapping layout already renders a top-level pending indicator
  (root-level `useNavigation` bar).

## Anti-pattern 4 — `useNavigation()` without a `formAction` filter

```tsx
// BAD — sidebar Link navigations also disable this button
const nav = useNavigation();
const busy = nav.state !== "idle";
```

**Why bad:** `navigation.state` flips for ANY navigation in the route
tree. Clicking a sidebar `<Link>` will disable an unrelated submit
button and surface a spinner that has nothing to do with the form.

**Fix:** Compare `navigation.formAction` to the form's action path:

```tsx
const nav = useNavigation();
const busy = nav.state !== "idle" && nav.formAction === "/signup";
```

For forms posting to the current route, capture the route's path from
`useLocation()` or hardcode the literal — both are correct.

**Exemptions — do NOT flag:**

- The button is in `root.tsx` and intentionally reflects ALL nav.
- The surface is a single-form route where no other navigation is
  reachable (rare; usually still safer to filter).

## Anti-pattern 5 — Reading `fetcher.state` from the wrong fetcher

```tsx
// BAD — two fetchers, one observed
function Row({ item }: { item: Item }) {
  const likeFetcher = useFetcher();
  const deleteFetcher = useFetcher();
  const busy = likeFetcher.state !== "idle";  // ignores delete
  return (
    <>
      <likeFetcher.Form method="post" action={`/items/${item.id}/like`}>
        <button disabled={busy}>Like</button>
      </likeFetcher.Form>
      <deleteFetcher.Form method="post" action={`/items/${item.id}/delete`}>
        <button disabled={busy}>Delete</button>
      </deleteFetcher.Form>
    </>
  );
}
```

**Why bad:** Pending state of "like" is wired to the delete button.
Visual feedback is inverted.

**Fix:** Either observe both (`busy = like.state !== "idle" ||
delete.state !== "idle"`) or — better — use the intent pattern on a
single fetcher so only the clicked button is "in flight". See
[multi-action-routes.md](multi-action-routes.md).

## Verification before reporting

1. Grep the file for `useState`, `useNavigation`, `useFetcher`,
   `fetcher.state`. A real loading flag often shadows what is really
   happening.
2. Confirm `<Form method>` is POST (or non-GET). GET forms driven by
   `useNavigation` only ever produce `"loading"`, never `"submitting"`,
   so some patterns look different on GET. (`<fetcher.Form method='get'>`
   driven by `fetcher.state` DOES produce `"submitting"`.)
3. Confirm the per-row vs page-global axis by reading the surrounding
   `.map()` — page-global checks are correct on a single-form route.
4. Confirm `nav.formAction` checks the right path; an outdated literal
   is worth flagging as a soft warning, not a critical bug.
