# Hydration Safety

A hydration mismatch happens when the HTML React renders on the server differs from what it produces on the client during the first render. React 18 logs a warning and re-renders the affected subtree on the client, destroying any SSR perf benefit and sometimes producing visible flicker.

## Why mismatches happen

Server and client are different environments. The same render function can produce different output when it depends on:

- Time: `new Date()`, `Date.now()`, anything that reads "now."
- Randomness: `Math.random()`, `crypto.randomUUID()`.
- Locale: `Intl.DateTimeFormat()`, `Intl.NumberFormat()`, `toLocaleDateString()` — server defaults to system locale (often `en-US`), browser uses visitor's.
- Environment: `window.`, `document.`, `localStorage`, `navigator.`, `process.env.` in component bodies.
- Conditional branches: `typeof window === "undefined" ? A : B` produces different JSX on each side.
- External mutation: third-party scripts that mutate the DOM before React hydrates (chat widgets, A/B test scripts), browser extensions injecting nodes into `<body>` (Grammarly, password managers).

## The grep list

Before shipping, search the codebase for these patterns in components or hooks that aren't already inside `useEffect`, `<ClientOnly>`, or `useHydrated()` gates:

```text
new Date(
Math.random(
crypto.randomUUID(
Date.now(
window.
document.
localStorage
sessionStorage
navigator.
Intl.DateTimeFormat()
Intl.NumberFormat()
.toLocaleDateString
.toLocaleTimeString
.toLocaleString
process.env.
typeof window
```

Each one is a potential mismatch.

## `useHydrated()` — two-pass conditional UI

`useHydrated()` returns `false` during SSR and during the **first client render**, then flips to `true` on the next render. That two-pass behavior is what keeps server HTML and the initial client HTML identical — only the second render diverges, which React handles correctly.

```tsx
import { useHydrated } from "remix-utils/use-hydrated";

export function TimezoneBadge({ iso }: { iso: string }) {
  const isHydrated = useHydrated();
  if (!isHydrated) return <time dateTime={iso}>{iso}</time>;
  return (
    <time dateTime={iso}>
      {new Intl.DateTimeFormat().format(new Date(iso))}
    </time>
  );
}
```

`remix-utils/use-hydrated` exports the standard implementation. The hook can also be hand-rolled in any project:

```tsx
import { useEffect, useState } from "react";

export function useHydrated() {
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => setHydrated(true), []);
  return hydrated;
}
```

Use `useHydrated()` for **conditional UI inside an already-rendered component** — the component itself SSRs, but a slice of it switches to a richer client-only representation after hydration.

## `<ClientOnly>` — suppress SSR entirely

When a component cannot SSR at all (Leaflet maps, Mapbox, charts that read `window`, Three.js canvases), wrap it in `<ClientOnly>`:

```tsx
import { ClientOnly } from "remix-utils/client-only";

export function MapPanel() {
  return (
    <ClientOnly fallback={<MapPlaceholder aspect="16/9" />}>
      {() => <LeafletMap />}
    </ClientOnly>
  );
}
```

The `fallback` renders during SSR and during the first client render; the child renders after hydration. The child is a **function** (`() => <LeafletMap />`), not a JSX expression — this defers evaluation so that imports inside `LeafletMap` (which may touch `window`) don't run on the server.

Use `<ClientOnly>` for **entire subtrees that can't SSR**. Don't reach for it as a hammer for every browser API — most cases are better handled with `useEffect` and `useHydrated`.

## `useId()` — SSR-safe IDs

React's `useId()` generates an ID that is stable across server and client. Use it for label-for, ARIA references, and anywhere else you'd hand-roll an ID:

```tsx
import { useId } from "react";

export function LabeledInput({ label }: { label: string }) {
  const id = useId();
  return (
    <>
      <label htmlFor={id}>{label}</label>
      <input id={id} />
    </>
  );
}
```

Never hand-roll IDs with `Math.random()`, `crypto.randomUUID()`, or `Date.now()` in render. Server and client produce different values; every label-for, ARIA reference, and CSS hook breaks.

## Common mismatches and their fixes

### `new Date()` / `Date.now()`

```tsx
// BROKEN — server and client compute different "now"
<p>Updated {new Date().toLocaleString()}</p>

// FIX A — render the ISO from the loader, format after hydration
const { updatedAtIso } = useLoaderData<typeof loader>();
const isHydrated = useHydrated();
return (
  <p>
    Updated{" "}
    {isHydrated
      ? new Date(updatedAtIso).toLocaleString()
      : <time dateTime={updatedAtIso}>{updatedAtIso}</time>}
  </p>
);
```

### `Intl.DateTimeFormat()` without locale

```tsx
// BROKEN — server default locale != visitor's locale
new Intl.DateTimeFormat().format(date);

// FIX — pass locale explicitly (use a server-known value, or render
// ISO server-side and reformat in useEffect/useHydrated)
new Intl.DateTimeFormat("en-US", { dateStyle: "medium" }).format(date);
```

### `Math.random()`

```tsx
// BROKEN
const id = `widget-${Math.random()}`;

// FIX — useId() for IDs, or generate the value in the loader and pass via props
const id = useId();
```

### `localStorage` in a `useState` initializer

```tsx
// BROKEN — localStorage is undefined on the server
const [theme, setTheme] = useState(localStorage.getItem("theme"));

// FIX — initialize to a server-safe default, sync in useEffect
const [theme, setTheme] = useState<"light" | "dark">("light");
useEffect(() => {
  const stored = localStorage.getItem("theme") as "light" | "dark" | null;
  if (stored) setTheme(stored);
}, []);
```

### Third-party scripts mutating the DOM

Chat widgets, A/B test loaders, Sentry, analytics — if they inject DOM before React hydrates, hydration sees unexpected nodes. Defenses:

- Load them after hydration (in `useEffect`).
- Inject the script with `async` or `defer` and a known-stable mounting point that React doesn't manage.
- Set `suppressHydrationWarning` on container nodes whose content the script controls.

### Browser extensions injecting nodes

Grammarly, password managers, ad blockers can add attributes (`data-gramm`, `cz-shortcut-listen`) or wrap inputs. There's no clean fix — the standard workaround is `suppressHydrationWarning` on the affected element. Use sparingly; it silences real bugs too.

## Debugging hydration errors

React's hydration error message includes both the server HTML and the client-rendered output. Diff them character by character — the first divergence is your bug. Then grep the component tree for the patterns in the grep list above, starting at the deepest node.

If the mismatch is inside a third-party component, file an issue upstream and wrap the component in `<ClientOnly>` as a workaround.

## When `suppressHydrationWarning` is justified

- Browser extension DOM mutation that you can't prevent.
- Intentional time-since-now displays where the server value is acceptable for the first render.
- Cases where the difference is invisible (whitespace differences from a third-party script).

It only silences the warning for the **single element** it's attached to — children still report mismatches. Don't slap it at the root to suppress all warnings.
