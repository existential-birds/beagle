# Revalidation & Pending State Review Reference

Anti-patterns and review prompts for `useNavigation`, `useTransition` (v1 holdover), `shouldRevalidate`, and `useRevalidator` in Remix v2. See [beagle-remix-v2:remix-v2-data-flow](../../remix-v2-data-flow/SKILL.md) for canonical patterns.

## 1. `useTransition` — v1 holdover

**Smell**:

```tsx
import { useTransition } from "@remix-run/react";

function SaveButton() {
  const transition = useTransition();
  const busy = transition.state === "submitting";
  // ...
}
```

**Why bad**: `useTransition` was removed in Remix v2; the hook is now `useNavigation`. The `submission` object was flattened — `transition.submission.formMethod` no longer exists; the fields are on the root: `nav.formMethod`, `nav.formData`, `nav.formAction`.

**Fix**:

```tsx
import { useNavigation } from "@remix-run/react";

function SaveButton() {
  const nav = useNavigation();
  const busy = nav.state !== "idle" && nav.formMethod === "POST";
}
```

**Related holdovers to flag in the same review**:

- `fetcher.type === "actionSubmission"` — `fetcher.type` is removed. Branch on `fetcher.state` plus presence of `fetcher.formData`.
- `formMethod === "post"` (lowercase) — v2 returns UPPERCASE (`"POST"`, `"GET"`, `"DELETE"`); lowercase comparisons silently never match. Applies to `useNavigation`, `useFetcher`, and the `shouldRevalidate` arg.
- `LoaderArgs` / `ActionArgs` — renamed to `LoaderFunctionArgs` / `ActionFunctionArgs`.

## 2. Missing pending state

**Smell**: A `<Form method="post">` submit button has no disabled / spinner / busy attribute. Users double-click and double-submit.

**Why bad**: Long submits feel broken; double submits create duplicate records. Remix exposes `nav.state` and `fetcher.state` for exactly this.

**Fix**:

```tsx
const nav = useNavigation();
const busy = nav.state !== "idle" && nav.formMethod === "POST";
return <button type="submit" disabled={busy}>{busy ? "Saving…" : "Save"}</button>;
```

For `useFetcher`-driven mutations, gate on `fetcher.state !== "idle"` instead. POST flow goes `idle → submitting → loading → idle`; GET flow goes `idle → loading → idle` — a spinner gated only on `"submitting"` will miss GET forms.

**Do not flag when**:

- The button uses CSS / `data-busy` attribute hooked into `nav.state` elsewhere (search the file for `nav.state` / `fetcher.state` before flagging "missing pending state").
- The form posts to a `useFetcher` that drives optimistic UI from `fetcher.formData` — the optimistic state *is* the pending indicator.

## 3. Blanket `shouldRevalidate` returning `false`

**Smell**:

```tsx
export const shouldRevalidate: ShouldRevalidateFunction = () => false;
```

**Why bad**: The route now never revalidates — not after the user's own mutations on this route, not on params change, not when explicit `useRevalidator()` calls fire. The docs warn: "This makes it possible for your UI to get out of sync with your server if you do it wrong, so be careful." Users will see stale data after their own actions and not understand why.

**Fix**: Start from `defaultShouldRevalidate` and opt out only for the narrow conditions that justify it:

```tsx
export const shouldRevalidate: ShouldRevalidateFunction = ({
  currentParams,
  nextParams,
  defaultShouldRevalidate,
}) => {
  // Root loader carries static env vars; only revalidate if params change (they shouldn't here).
  if (currentParams.userId !== nextParams.userId) return true;
  return false;
};
```

**Legitimate `return false`**: A root loader carrying purely static data (`{ env: { APP_URL } }`) that never changes for the page lifetime. Even there, prefer narrowing on `formAction` rather than a blanket `false`.

**Red flags** to look for in `shouldRevalidate` bodies:

- Return value is a literal `false` with no condition.
- The function body never references `formAction`, `formMethod`, `currentParams`, or `nextParams`.
- The function body never references `defaultShouldRevalidate`.

## 4. `useRevalidator` when navigation would do

**Smell**:

```tsx
function SaveButton() {
  const fetcher = useFetcher();
  const { revalidate } = useRevalidator();
  return (
    <button
      onClick={async () => {
        await fetcher.submit({ ... }, { method: "POST", action: "/save" });
        revalidate(); // manual refresh
      }}
    >
      Save
    </button>
  );
}
```

**Why bad**: After any action submitted via `<Form>` or `useFetcher`, Remix automatically revalidates all loaders for matching routes on the page. The manual `revalidate()` call duplicates the loader requests and races the automatic pass. The docs say: "If you find yourself using this for normal CRUD operations on your data… you're probably not taking advantage of the other APIs like `<Form>`, `useSubmit`, or `useFetcher`."

**Fix**: Remove the `revalidate()` call. `useRevalidator` is for cases the framework cannot trigger automatically: cross-tab sync, focus-driven refresh, polling, websocket-pushed updates.

**Legitimate uses (do not flag)**:

```tsx
const { revalidate, state } = useRevalidator();
useEffect(() => {
  function onFocus() {
    if (state === "idle") revalidate();
  }
  window.addEventListener("focus", onFocus);
  return () => window.removeEventListener("focus", onFocus);
}, [revalidate, state]);
```

## 5. Polling with `useRevalidator` without guards

**Smell**:

```tsx
useEffect(() => {
  const id = setInterval(() => revalidate(), 5000);
  return () => clearInterval(id);
}, [revalidate]);
```

**Why bad**: Multiple revalidations can stack on top of each other — if the loader takes 6 seconds, a second call fires while the first is still in flight. Across many concurrent users this duplicates DB queries and can hammer the origin.

**Fix**: Gate on `state === "idle"`, add jitter, pause when the tab is hidden:

```tsx
useEffect(() => {
  const id = setInterval(() => {
    if (state === "idle" && document.visibilityState === "visible") revalidate();
  }, 5000 + Math.random() * 1000);
  return () => clearInterval(id);
}, [revalidate, state]);
```

## Review prompts

- Does the file import `useTransition` from `@remix-run/react`?
- Are there comparisons against lowercase `"post"` / `"get"` / `"delete"`?
- Does any `fetcher.type === ...` switch survive?
- Does `shouldRevalidate` always return a literal `false`?
- Does any submit button lack a `disabled` or busy class tied to `nav.state` / `fetcher.state`?
- Is `revalidate()` called manually right after a `fetcher.submit` / `<Form>` post that Remix would already revalidate?
- Are polling `revalidate()` calls gated on `state === "idle"` and visibility?
