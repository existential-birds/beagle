# Revalidation & Pending State

Remix keeps the UI in sync with the server by re-running loaders automatically after every action. You almost never need to wire up cache invalidation by hand.

## Automatic Revalidation

The default behavior, restated from the Remix data-flow discussion:

1. Route loaders provide data to the UI.
2. Forms post data to route actions that update persistent state.
3. **Loader data on the page is automatically revalidated** after every action.

After a `<Form method="post">` submit or a `fetcher.submit()`, Remix runs the action, then re-runs every loader of every currently matched route on the page — even loaders whose params didn't change. The result: every `useLoaderData<typeof loader>()` reads fresh data without manual invalidation.

## `shouldRevalidate` — Opt Out

For expensive loaders that don't depend on the action, opt out via the route module's `shouldRevalidate` export.

```ts
import type { ShouldRevalidateFunction } from "@remix-run/react";

export const shouldRevalidate: ShouldRevalidateFunction = ({
  currentParams,
  currentUrl,
  nextParams,
  nextUrl,
  formMethod,
  formAction,
  formData,
  actionResult,
  defaultShouldRevalidate,
}) => {
  // Re-validate by default, except for parent search-param changes that
  // don't affect this route's data.
  if (currentUrl.pathname === nextUrl.pathname && currentParams === nextParams) {
    return false;
  }
  return defaultShouldRevalidate;
};
```

A common safe use is a root loader that returns static env config:

```ts
// app/root.tsx
export const loader = async () =>
  json({ env: { APP_URL: process.env.APP_URL } });

export const shouldRevalidate: ShouldRevalidateFunction = () => false;
```

### Don't Return `false` Unconditionally Without Thought

The docs warn: "This makes it possible for your UI to get out of sync with your server if you do it wrong, so be careful." A permanent opt-out causes stale data after the user's own mutations. Default to `defaultShouldRevalidate` and only suppress the narrow cases where you can prove the loader's inputs haven't changed.

## `useRevalidator` — Manual Trigger

For pull-style refresh (window focus, polling, server-sent events) use `useRevalidator`.

```tsx
import { useRevalidator } from "@remix-run/react";
import { useEffect } from "react";

export function useRevalidateOnFocus() {
  const { revalidate, state } = useRevalidator();

  useEffect(() => {
    function onFocus() {
      if (state === "idle") revalidate();
    }
    window.addEventListener("focus", onFocus);
    return () => window.removeEventListener("focus", onFocus);
  }, [revalidate, state]);
}
```

`useRevalidator()` returns `{ revalidate(): void; state: "idle" | "loading" }`. Always gate the call on `state === "idle"` — multiple concurrent revalidations fire overlapping loader calls.

> If you find yourself using `useRevalidator` for normal CRUD operations, you're probably skipping `<Form>` / `useSubmit` / `useFetcher` and reinventing the automatic revalidation.

### Polling Gotchas

- Synchronized polling from many tabs / users can DDoS your origin. Add jitter.
- Pause polling while the user is scrolling or interacting.
- Concurrent revalidations duplicate DB queries — `state === "idle"` is a real guard.

## `useNavigation` — Pending UI

`useNavigation()` returns the in-flight navigation/submission state for the whole app (not scoped to one form). It is the v2 replacement for v1's `useTransition`.

```tsx
import { useNavigation, Form } from "@remix-run/react";

export default function SaveButton() {
  const nav = useNavigation();
  // POST: idle → submitting → loading → idle.
  // GET:  idle → loading → idle.
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

The shape: `{ state, location, formData, formAction, formMethod }`. The `submission` object from v1 is flattened directly onto the navigation; there is no `nav.submission.formMethod` in v2.

### v1 `useTransition` → v2 `useNavigation`

If you see `useTransition` from `@remix-run/react`, it's a v1 holdover. In `@remix-run/react@2.x` it still exists as a deprecated forwarder to `useNavigation`, so code compiles — schedule for replacement before the next major. Replacements:

| v1                                       | v2                                              |
|------------------------------------------|-------------------------------------------------|
| `useTransition()`                        | `useNavigation()`                               |
| `transition.submission.formMethod`       | `nav.formMethod`                                |
| `transition.submission.formData`         | `nav.formData`                                  |
| `transition.state === "submitting"`      | `nav.state === "submitting"`                    |
| `transition.type === "actionSubmission"` | `nav.state === "submitting" && nav.formMethod !== "GET"` |

(Note: React 18 / React 19 also export a `useTransition` from `react` itself — that hook is unrelated and has a different API. The collision is unfortunate; the Remix one is gone, the React one stays.)

### `formMethod` Is UPPERCASE in v2

```ts
nav.formMethod === "POST" // correct
nav.formMethod === "post" // silently never matches — v1 lowercase holdover
```

`useNavigation`, `useFetcher`, and `shouldRevalidate` all return UPPERCASE methods in v2. Greping a v2 codebase for `=== "post"` (lowercase) is a fast way to surface broken pending-state checks.

### `fetcher.type` Is Gone

v1 code like `if (fetcher.type === "actionSubmission")` no longer compiles. Branch instead on `fetcher.state` plus presence of `fetcher.formData`:

```ts
const submitting = fetcher.state === "submitting" && fetcher.formData != null;
```

### GET Submissions Skip "submitting"

A `<Form method="get">` goes `idle → loading → idle` — never enters `"submitting"`. Spinners gated only on `state === "submitting"` will silently miss GET form filtering.

## Decision Sketch

| Goal                                                     | API                                       |
|----------------------------------------------------------|-------------------------------------------|
| Refetch loaders after a write                            | Nothing — Remix does it automatically     |
| Opt out of revalidation for an expensive parent loader   | `shouldRevalidate` returning `false`      |
| Refetch on window focus / interval / SSE message         | `useRevalidator` (gate on `state === "idle"`) |
| Show pending state during navigation / submission        | `useNavigation`                           |
| Show pending state for an inline (non-nav) mutation      | `fetcher.state` + `fetcher.formData`      |

## Optimistic UI from `fetcher.formData`

A fetcher exposes the FormData it's currently submitting. Read it to predict the next state before the server has responded.

```tsx
import { useFetcher } from "@remix-run/react";

export function StarButton({ project }: { project: Project }) {
  const fetcher = useFetcher<typeof action>();
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

When the fetcher resolves, automatic revalidation refreshes loader data and the component reconciles to the server's truth — no manual rollback code.

## `v2_normalizeFormMethod` Future Flag

In late Remix v1 (1.16+), the `v2_normalizeFormMethod` future flag opted in early to the v2 UPPERCASE-method behavior described above. In a true v2 codebase the flag is a no-op (the behavior is the default), but if you're working on a v1→v2 migration branch, enabling that flag *before* the version bump lets you fix `formMethod` comparisons incrementally.
