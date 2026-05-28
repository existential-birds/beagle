# Hydration Safety Review

Anti-patterns that produce SSR/client divergence.

## What to flag

### 1. `new Date()` / `Date.now()` in render path

Server and client compute different values microseconds apart — different HTML, hydration mismatch, React 18 logs a warning and re-renders the entire subtree on the client. Common offenders: rendering "last updated X ago," "current time," default-form values, copyright years (sometimes).

**Bad:**
```tsx
export default function Page() {
  return <p>Rendered at {new Date().toLocaleString()}</p>;
}
```

**Bad (same problem, different shape):**
```tsx
const NOW = Date.now(); // module-level — evaluated at first import
export default function Page() {
  return <p>Now: {NOW}</p>;
}
```

**Good (render a stable value, format client-side after hydration):**
```tsx
import { useEffect, useState } from "react";

export default function Page() {
  const iso = useLoaderData<typeof loader>().renderedAt;
  const [pretty, setPretty] = useState<string | null>(null);
  useEffect(() => setPretty(new Date(iso).toLocaleString()), [iso]);
  return <p>Rendered at {pretty ?? iso}</p>;
}
```

**Report as:** `[FILE:LINE] DATE_IN_RENDER` — `new Date()` / `Date.now()` evaluated in JSX render path.

**Do not flag when the call site is:**
- inside `useEffect` / `useLayoutEffect`
- inside an event handler (`onClick`, `onChange`, etc.)
- inside a `setTimeout`/`requestAnimationFrame` callback
- inside `<ClientOnly>{() => ...}</ClientOnly>`
- inside a render branch gated by `useHydrated()` returning `true`

### 2. `Math.random()` / `crypto.randomUUID()` in render or as React keys

Server picks one value, client picks another — different HTML, different keys, hydration mismatch and remount of subtree.

**Bad:**
```tsx
export default function List({ items }: { items: string[] }) {
  return (
    <ul>
      {items.map((item) => (
        <li key={Math.random()}>{item}</li> // different key every render
      ))}
    </ul>
  );
}
```

**Bad (same problem):**
```tsx
const id = `widget-${crypto.randomUUID()}`; // module-level random
export function Widget() {
  return <div id={id}>...</div>;
}
```

**Good (stable identity from data, or `useId` for ID generation):**
```tsx
{items.map((item) => <li key={item.id}>{item.label}</li>)}
```

```tsx
import { useId } from "react";
export function Widget() {
  const id = useId();
  return <div id={id}>...</div>;
}
```

**Report as:** `[FILE:LINE] RANDOM_IN_RENDER_OR_KEY` — `Math.random()` / `crypto.randomUUID()` used in render path or as a key.

**Do not flag when:** the call is inside an effect, event handler, or `<ClientOnly>` body.

### 3. Locale formatting without explicit locale

`new Intl.DateTimeFormat()` and `date.toLocaleDateString()` without arguments use the runtime's default locale. The server's default locale (typically `en-US` from `ICU_DATA` or system) almost never matches a visitor's locale → divergent strings → hydration mismatch.

**Bad:**
```tsx
<time>{new Date(iso).toLocaleDateString()}</time>           // implicit locale
<time>{new Intl.DateTimeFormat().format(new Date(iso))}</time>
<span>{n.toLocaleString()}</span>                            // implicit locale
```

**Good (explicit locale — pass via loader or hardcode if appropriate):**
```tsx
<time>{new Date(iso).toLocaleDateString("en-US")}</time>
<time>{new Intl.DateTimeFormat("en-US", { dateStyle: "medium" }).format(new Date(iso))}</time>
```

**Better (render ISO on server, reformat in `useEffect` using the visitor's locale):**
```tsx
import { useEffect, useState } from "react";

export function Date({ iso }: { iso: string }) {
  const [formatted, setFormatted] = useState<string | null>(null);
  useEffect(() => {
    setFormatted(new Date(iso).toLocaleDateString());
  }, [iso]);
  return <time dateTime={iso}>{formatted ?? iso}</time>;
}
```

**Report as:** `[FILE:LINE] LOCALE_FORMAT_WITHOUT_LOCALE` — `toLocaleString`/`toLocaleDateString`/`toLocaleTimeString`/`Intl.*` called without an explicit `locale` argument.

**Do not flag when:** the call is inside `useEffect` / event handler / `<ClientOnly>`.

### 4. Hand-rolled IDs in components that should use `useId()`

Counters, timestamps, random IDs in render path all break SSR. React's `useId` returns a stable ID across server and client.

**Bad:**
```tsx
let counter = 0;
export function LabeledInput({ label }: { label: string }) {
  const id = `input-${++counter}`; // increments per render; ordering differs SSR vs client
  return (<><label htmlFor={id}>{label}</label><input id={id} /></>);
}
```

**Bad:**
```tsx
export function LabeledInput({ label }: { label: string }) {
  const id = `input-${Math.random()}`;
  return (<><label htmlFor={id}>{label}</label><input id={id} /></>);
}
```

**Good:**
```tsx
import { useId } from "react";
export function LabeledInput({ label }: { label: string }) {
  const id = useId();
  return (<><label htmlFor={id}>{label}</label><input id={id} /></>);
}
```

**Report as:** `[FILE:LINE] MISSING_USE_ID` — component generates ID from counter/random/timestamp instead of `useId()`.

**Do not flag:** `` `${id}-input` ``-style append for multi-element components — that's the documented pattern.

### 5. Blanket `suppressHydrationWarning` on a parent that wraps a large subtree

`suppressHydrationWarning` silences React's mismatch warning for ONE element and its **immediate** text children. Applying it to a `<div>` or `<body>` that wraps a large subtree hides every bug under it, including critical ones (XSS, broken interactivity, leaked secrets). It's also misleading — the prop only suppresses the *warning*; the underlying mismatch still causes a client re-render.

**Bad:**
```tsx
<body suppressHydrationWarning>
  {/* everything below silenced */}
</body>
```

**Bad:**
```tsx
<div suppressHydrationWarning>
  <SomeComponent />
  <AnotherComponent />
</div>
```

**Good (narrow scope, comment why):**
```tsx
{/* suppress: server returns ISO, client reformats post-hydration */}
<time dateTime={iso} suppressHydrationWarning>
  {formatted}
</time>
```

**Report as:** `[FILE:LINE] BLANKET_SUPPRESS_HYDRATION_WARNING` — `suppressHydrationWarning` applied to a wrapper element or without an explanatory comment.

**Do not flag:** the prop on a single leaf element (`<time>`, `<span>`, `<input value>`) with a comment explaining why divergence is expected.

### 6. `window.` / `document.` / `localStorage` / `navigator.` in render path

These globals are undefined on the server. Reading them in render crashes SSR or — when wrapped in `typeof` guards — produces different output on server and client, causing mismatch.

**Bad:**
```tsx
export default function Page() {
  const width = window.innerWidth; // crashes on SSR
  return <p>Width: {width}</p>;
}
```

**Bad (guarded but still mismatched):**
```tsx
export default function Page() {
  const dark = typeof window !== "undefined" && localStorage.getItem("theme") === "dark";
  return <div className={dark ? "dark" : "light"}>...</div>; // SSR says "light", client says "dark"
}
```

**Good (initialize state from a stable default; sync in `useEffect`):**
```tsx
import { useEffect, useState } from "react";

export default function Page() {
  const [dark, setDark] = useState(false);
  useEffect(() => setDark(localStorage.getItem("theme") === "dark"), []);
  return <div className={dark ? "dark" : "light"}>...</div>;
}
```

**Or:** wrap the component in `<ClientOnly>` if there's no acceptable SSR fallback.

**Report as:** `[FILE:LINE] BROWSER_API_IN_RENDER` — `window.*`/`document.*`/`localStorage`/`navigator.*` read in render path.

### 7. `typeof window` ternaries that produce different JSX

A ternary on `typeof window` in render produces a different element tree on server vs client. This is the most common deliberate hydration mismatch — and it's always wrong; use `useHydrated` for the two-pass pattern.

**Bad:**
```tsx
export function Widget() {
  return typeof window !== "undefined"
    ? <ClientWidget />
    : <Skeleton />;
}
```

**Good:**
```tsx
import { useHydrated } from "remix-utils/use-hydrated";

export function Widget() {
  const isHydrated = useHydrated();
  return isHydrated ? <ClientWidget /> : <Skeleton />;
}
```

`useHydrated` is `false` on SSR **and** the first client render, then flips to `true` — the two-pass keeps HTML matched.

**Report as:** `[FILE:LINE] TYPEOF_WINDOW_TERNARY` — render returns different JSX based on `typeof window`.

### 8. Render-time `Date()` for the year (the "current year" footer)

This is the most-shipped hydration bug. `new Date().getFullYear()` in a footer renders one year on server, possibly another on client during a year boundary, but more importantly tools and linters often miss it.

**Acceptable (build-time):**
```tsx
const YEAR = 2026; // hardcoded or injected via build env
<p>© {YEAR} Company</p>
```

**Acceptable (loader):**
```tsx
export async function loader() {
  return json({ year: new Date().getFullYear() });
}
// component reads from useLoaderData
```

**Report as:** `[FILE:LINE] DATE_GETFULLYEAR_IN_RENDER` — `new Date().getFullYear()` in JSX (a special case of `DATE_IN_RENDER`, but distinct enough to call out).

## Verify before flagging

- **Confirm the call site is in render.** Walk up from the offending line. If the nearest enclosing function is a `useEffect`/`useLayoutEffect` callback, an event handler (`onClick`, `onChange`, `onSubmit`, etc.), a `setTimeout`/`setInterval`/`requestAnimationFrame` callback, or a `<ClientOnly>{() => ...}</ClientOnly>` child function — do not flag.
- For locale formatting, confirm no `locale` arg is passed. `toLocaleDateString("en-US")` is fine; `toLocaleDateString()` is the bug.
- For `suppressHydrationWarning`, confirm it's NOT on a single leaf element with a code comment. If it is, the narrow escape is acceptable.
- For browser-API reads, confirm the read is in render. `window.scrollTo()` in `useEffect` is fine.
- For `useId` issues, confirm the component generates IDs that need to match between SSR and CSR (label-for, aria-controls, aria-labelledby). A `data-test-id` that doesn't need to match is not the same thing.

## Verbatim quote requirements

Findings on this surface require a verbatim quote of:
- the offending expression (e.g. `new Date().toLocaleString()`), AND
- the enclosing function signature (so the reviewer can verify it's render, not effect/handler).

A finding like "this component has hydration issues" with no expression or call site is not reportable.
