# v1 Holdovers

Remix v2 re-exports its router surface from `@remix-run/react`. Imports from `react-router-dom`, double-underscore folders, and v1 file shapes are nearly always migration leftovers that bypass Remix's loader/action wiring. The v1-convention adapter is legitimate when wired explicitly — flag it only when its presence is inconsistent with the rest of the tree.

See [beagle-remix-v2:remix-v2-routing](../../remix-v2-routing/SKILL.md) for canonical v2 imports and filename grammar.

---

## Importing from `react-router-dom`

**Pattern**: A route module or component imports `Outlet`, `Link`, `useLoaderData`, `useParams`, or any hook from `react-router-dom` in a Remix v2 project.

```tsx
// smell
import { Outlet, Link, useParams } from "react-router-dom";
```

**Why bad**: Remix v2 wraps React Router with loader/action wiring, type inference for `useLoaderData<typeof loader>()`, and SSR-aware navigation. Importing the underlying `react-router-dom` package bypasses Remix's wiring — types break, loaders don't connect, and SSR hydration mismatches surface at runtime.

**Fix**:

```tsx
import { Outlet, Link, useParams, useLoaderData } from "@remix-run/react";
import type { LoaderFunctionArgs } from "@remix-run/node"; // or /cloudflare, /deno
```

Allowed exception: importing types like `Path` from `react-router-dom` is sometimes necessary when `@remix-run/react` doesn't re-export them. Flag value imports; check type imports against the actual export surface before flagging.

---

## `__double` underscore folders left from v1

**Pattern**: Folders under `app/routes/` named `__auth/`, `__app/`, `__marketing/`, with route files inside.

```text
app/routes/__auth/login.tsx          # v1 pathless layout shape
app/routes/__auth/signup.tsx
```

(v1 used `__auth/` as a *folder* name. A `.tsx` file literally named `__auth.tsx` at the routes root is a malformed mix of v1 and v2 grammar — it's neither a v1 pathless layout nor a v2 pathless layout. Treat it as a typo for `_auth.tsx`.)

**Why bad**: v1's double-underscore-folder convention is not recognized by v2 flat-routes. The walker either ignores the folder or mounts files at wrong URLs.

**Fix**: Rename to single-underscore files.

```text
app/routes/_auth.tsx                 → pathless layout (no URL)
app/routes/_auth.login.tsx           → /login
app/routes/_auth.signup.tsx          → /signup
```

**Do NOT flag** when `@remix-run/v1-route-convention` is installed and wired (see below).

---

## `index.tsx` left from v1

**Pattern**: Files named `index.tsx` (no leading `_`) under `app/routes/` or inside a v1-style folder.

```text
app/routes/index.tsx                 # v1 root index
app/routes/dashboard/index.tsx       # v1 nested index
```

**Why bad**: v2 reads these as literal `/index` segments. The home page mysteriously moves from `/` to `/index` after the upgrade.

**Fix**:

```text
app/routes/_index.tsx                → /
app/routes/dashboard._index.tsx      → /dashboard
```

---

## `@remix-run/v1-route-convention` as a deliberate-vs-accidental tell

**Pattern**: The package appears in `package.json` and `remix.config.js` wires the v1 convention:

```js
// remix.config.js
import { createRoutesFromFolders } from "@remix-run/v1-route-convention";

/** @type {import('@remix-run/dev').AppConfig} */
export default {
  routes(defineRoutes) {
    return createRoutesFromFolders(defineRoutes);
  },
};
```

**This is not automatically a smell.** It is the documented migration adapter — a team can legitimately keep a v1 nested-folder tree alive while shipping new v2 flat-routes alongside it.

**Flag only when**:

- The adapter is present **but no v1-style files exist** anywhere in `app/routes/` — the package is dead weight; remove it from `package.json` and `remix.config.js`.
- The adapter is **absent** but v1-style files (`__auth/`, `index.tsx`) exist — those files won't route correctly; either delete them or install the adapter.
- Mixed grammars *within the same feature folder* — e.g., `app/routes/__auth/login.tsx` (v1) alongside `app/routes/_auth.signup.tsx` (v2). Pick one per subtree.

**Fix**: Either commit to v2 grammar (delete the adapter, rename files) or commit to v1 (keep the adapter, rename strays back to folders). Don't half-migrate.

---

## v1-style hooks and helpers

**Pattern**: Code uses `useTransition` (v1) instead of `useNavigation` (v2), or `useFetchers` semantics that assume v1 behavior.

**Why bad**: v2 renamed `useTransition` to `useNavigation` and removed the `type` and `submission` fields. The `state` values (`"idle" | "submitting" | "loading"`) are unchanged from v1. Code copied from v1 docs or older blog posts will type-check against React's `useTransition` (a different API entirely) or silently misbehave when it reaches for the removed `type`/`submission` properties.

**Fix**:

```tsx
// v1
import { useTransition } from "@remix-run/react";
const transition = useTransition();
if (transition.state === "submitting") { /* … */ }

// v2
import { useNavigation } from "@remix-run/react";
const navigation = useNavigation();
if (navigation.state === "submitting") { /* … */ }
```

Note: React's own `useTransition` from `react` is a different hook entirely — don't conflate.

---

## `json()` / `redirect()` imported from `@remix-run/react`

**Pattern**: Server helpers imported from the React entry instead of the runtime entry.

```tsx
// smell
import { json, redirect } from "@remix-run/react";
```

**Why bad**: `json` and `redirect` are server runtime helpers and live in the runtime package (`@remix-run/node`, `/cloudflare`, `/deno`). Importing them from `@remix-run/react` either fails to resolve or pulls server code into the client bundle.

**Fix**: Match the runtime adapter the app uses.

```tsx
import { json, redirect } from "@remix-run/node";
```

---

## Verification

For each v1-holdover flag:

1. Quote the offending import line or filename.
2. Confirm the project is v2 (`@remix-run/react` ^2 in `package.json`).
3. Check `remix.config.js` for `@remix-run/v1-route-convention` — if wired, v1 filenames are intentional.
4. For import flags: confirm the symbol exists in the suggested replacement entry (`@remix-run/react` vs `@remix-run/node`).
