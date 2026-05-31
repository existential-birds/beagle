# Meta v2 Shape — Anti-Patterns

The v1 → v2 `meta` migration is the single highest-stakes detection in this
skill. v2 returns `MetaDescriptor[]` (an array). The v1 object shape still
typechecks in stale codebases and via loose `MetaFunction` aliases, but the
runtime ignores it: the route renders with **no title and no meta tags**.

See [remix-v2-meta-sessions](../../remix-v2-meta-sessions/SKILL.md)
for canonical descriptor reference.

## 1. v1 object shape used in a v2 codebase (BREAKING — flag as CRITICAL)

**Severity:** CRITICAL. Silent SEO and social-preview regression in
production.

**Anti-pattern:**

```tsx
// BAD — v1 shape; v2 ignores this at runtime
export const meta = () => ({
  title: "My Page",
  description: "A page on my site",
});
```

**Why bad:** v2 expects an array of descriptors. An object literal does not
match the runtime contract; Remix discards it and emits nothing. The page
ships with the default browser-tab title (often `localhost` or the URL) and
no OG/Twitter tags. Typecheck passes if `@remix-run/*` is stale, or if the
return is typed loosely, or if the function lacks an annotation.

**Fix:**

```tsx
import type { MetaFunction } from "@remix-run/node";

export const meta: MetaFunction = () => [
  { title: "My Page" },
  { name: "description", content: "A page on my site" },
];
```

**Detection grep:** `export const meta` followed by `=>` and `{` (or
`return {`) inside the function body — not `[`. Read the full return
expression; an inline conditional like `return cond ? { ... } : [ ... ]`
needs both branches inspected.

## 2. v1 OG / Twitter shorthand keys

**Anti-pattern:**

```tsx
// BAD — v1 shorthand; key is dropped silently in v2
export const meta: MetaFunction = () => [
  { "og:title": "My Page" },
  { "twitter:card": "summary_large_image" },
];
```

**Why bad:** v2 has no shorthand for Open Graph or Twitter Cards. The keys
do not match any descriptor shape (`title`, `name`+`content`,
`property`+`content`, `tagName`, `script:ld+json`, `charset`,
`httpEquiv`+`content`). They render as nothing.

**Fix:**

```tsx
export const meta: MetaFunction = () => [
  { property: "og:title", content: "My Page" },
  { name: "twitter:card", content: "summary_large_image" },
];
```

Note: Open Graph uses `property=`; Twitter Cards use `name=`. They look
similar but are not interchangeable.

## 3. `document.title` set in `useEffect` (or during render)

**Anti-pattern:**

```tsx
// BAD — bypasses SSR; bots and previews see the default title
export default function Page() {
  useEffect(() => {
    document.title = "My Page";
  }, []);
  return <h1>...</h1>;
}
```

**Why bad:** The server renders the document `<head>` with whatever
`<Meta />` aggregates from route exports. Setting `document.title` on the
client only fires after hydration — search bots and social-preview scrapers
that do not execute JavaScript see the parent or default title. Users see a
visible flash from "Untitled" to "My Page".

`document.title` inside render (not in an effect) is worse: it causes a
hydration mismatch and runs on every render.

**Fix:** Move to the `meta` export. If the title depends on loader data,
type the export with `MetaFunction<typeof loader>` and read from `data`.

```tsx
export const meta: MetaFunction<typeof loader> = ({ data }) =>
  [{ title: data?.title ?? "Loading..." }];
```

## 4. `root.tsx` missing `<Meta />` or `<Links />`

**Anti-pattern:**

```tsx
// BAD — no <Meta /> or <Links /> aggregators in <head>
export default function App() {
  return (
    <html>
      <head>
        <title>My Site</title>
      </head>
      <body>
        <Outlet />
        <Scripts />
      </body>
    </html>
  );
}
```

**Why bad:** Every route `meta` and `links` export silently does nothing.
The symptom is "css is broken in production" or "meta tags are missing" —
no compile error, no runtime warning.

**Fix:** Both aggregators must live inside `<head>`. `<ScrollRestoration />`
and `<Scripts />` go at the end of `<body>`.

```tsx
import { Links, LiveReload, Meta, Outlet, Scripts, ScrollRestoration }
  from "@remix-run/react";

export default function App() {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body>
        <Outlet />
        <ScrollRestoration />
        <Scripts />
        <LiveReload />
      </body>
    </html>
  );
}
```

## 5. Missing parent `meta` merge (no `matches.flatMap`)

**Anti-pattern:**

```tsx
// BAD — leaf returns only its own title; root title/OG tags disappear
export const meta: MetaFunction = () => [{ title: "Dashboard" }];
```

**Why bad:** v2 picks the **last matching route's** meta array — it does
**not** merge across the hierarchy. A leaf route with no parent merge ships
without site-wide tags (default OG image, canonical site name, etc.).

This trips up reviewers familiar with v1, where parent + child meta merged
automatically with last-write-wins per key.

**Fix:** Use `matches` to pull parent descriptors, optionally filtering to
override specific keys (e.g. title):

```tsx
export const meta: MetaFunction = ({ matches }) => {
  const parentMeta = matches
    .flatMap((m) => m.meta ?? [])
    .filter((tag) => !("title" in tag)); // child overrides title only
  return [...parentMeta, { title: "Dashboard" }];
};
```

Alternative: put truly site-wide tags as plain JSX in `root.tsx`'s `<head>`
so they live outside the `<Meta />` aggregator and cannot be displaced.

## 6. `meta` reading `data` without null-guard

**Anti-pattern:**

```tsx
// BAD — crashes on 404 / parent loader returning null
export const meta: MetaFunction<typeof loader> = ({ data }) => [
  { title: data.post.title },
];
```

**Why bad:** `meta` runs on every render path including error boundaries
and 404s. If the loader threw a Response (e.g. `notFound()`), `data` is
`undefined`. Accessing `data.post.title` throws during render, the
document fails to render, and the user sees a generic error page instead
of the proper 404.

**Fix:** Guard at the top of the function:

```tsx
export const meta: MetaFunction<typeof loader> = ({ data }) => {
  if (!data?.post) return [{ title: "Not Found" }];
  return [{ title: data.post.title }];
};
```

## Detection notes for reviewers

- **Grep first, read second.** Run `rg "export const meta" app/` and read
  every match — the v1 shape is easy to miss in PR diffs because most
  reviewers skim past `meta` exports.
- **Check the import.** `MetaFunction` must come from `@remix-run/node`
  (or `@remix-run/cloudflare`). An import from `@remix-run/react` or a
  custom alias may have a loose return type that masks v1 shape.
- **Check `tsconfig.json` strictness.** A v2 codebase with
  `"strict": false` or no `MetaFunction` annotation can ship v1 shape
  without any typecheck failure.
- **Look for stale `v2_meta` future flag references.** A `remix.config.js`
  still mentioning `v2_meta` suggests a partial migration — confirm every
  `meta` export was updated.

## Hard gates reminder

Before flagging any `meta` issue, confirm the **Meta-shape check** in the
parent SKILL's Hard gates: you read the actual return expression and it
starts with `[` (array) or `{` (object). Diff-only inspection is insufficient.
