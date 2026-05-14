# Meta v2 Reference

The Remix v2 `meta` route export returns an **array of `MetaDescriptor`
objects**. This is the single most important fact about v2 meta: a v1-style
object literal (`{ title, description }`) typechecks against the old
`MetaFunction` signature in stale codebases but produces zero rendered meta
tags at runtime.

## Imports

```ts
import type { MetaFunction } from "@remix-run/node";
// MetaDescriptor union type is exported from @remix-run/react
import type { MetaDescriptor } from "@remix-run/react";
```

`<Meta />` (from `@remix-run/react`) is the aggregator placed inside `<head>`
in `root.tsx`. It walks the matched route tree and renders descriptors from
the last matching route's `meta` export.

## Descriptor Types

A `MetaDescriptor` is a union of:

| Shape | Renders as |
|---|---|
| `{ title: string }` | `<title>` |
| `{ name: string, content: string }` | `<meta name=... content=...>` |
| `{ property: string, content: string }` | `<meta property=... content=...>` (OG, Twitter) |
| `{ httpEquiv: string, content: string }` | `<meta http-equiv=... content=...>` |
| `{ charset: "utf-8" }` | `<meta charset="utf-8">` |
| `{ tagName: "link", ...HtmlLinkAttrs }` | `<link>` (canonical, alternate) |
| `{ "script:ld+json": object }` | `<script type="application/ld+json">` |

Use the explicit `{ property, content }` shape for any `og:*` or `twitter:*`
tag — the v1 shorthand `{ "og:title": "..." }` is silently dropped in v2.

## Complete Example

```tsx
// app/routes/posts.$slug.tsx
import type { LoaderFunctionArgs, MetaFunction } from "@remix-run/node";
import { json } from "@remix-run/node";
import { useLoaderData } from "@remix-run/react";

export async function loader({ params }: LoaderFunctionArgs) {
  const post = await getPost(params.slug);
  if (!post) throw new Response("Not Found", { status: 404 });
  return json({ post });
}

export const meta: MetaFunction<typeof loader> = ({ data, location }) => {
  // Null-guard: meta runs on error/404 too; data may be undefined.
  if (!data?.post) return [{ title: "Not Found" }];

  const url = `https://example.com${location.pathname}`;
  return [
    { title: `${data.post.title} | My Blog` },
    { name: "description", content: data.post.excerpt },
    { property: "og:title", content: data.post.title },
    { property: "og:description", content: data.post.excerpt },
    { property: "og:url", content: url },
    { property: "og:type", content: "article" },
    { name: "twitter:card", content: "summary_large_image" },
    { tagName: "link", rel: "canonical", href: url },
    {
      "script:ld+json": {
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        headline: data.post.title,
        datePublished: data.post.publishedAt,
        author: { "@type": "Person", name: data.post.authorName },
      },
    },
  ];
};
```

## The `matches` Argument (parent meta access)

v2 replaces v1's `parentsData` with a `matches` array. Each match exposes
`id`, `pathname`, `params`, `data`, `handle`, and `meta` — the descriptors
the parent route's `meta` function returned (or would return).

```tsx
import type { MetaFunction } from "@remix-run/node";

export const meta: MetaFunction = ({ matches }) => {
  const parentMeta = matches
    .flatMap((m) => m.meta ?? [])
    // Child overrides the title; everything else from parents is kept.
    .filter((tag) => !("title" in tag));

  return [...parentMeta, { title: "Dashboard" }];
};
```

To read a specific parent loader's data:

```tsx
import type { MetaFunction } from "@remix-run/node";
import type { loader as rootLoader } from "~/root";

export const meta: MetaFunction<typeof loader, { root: typeof rootLoader }> = ({
  data,
  matches,
}) => {
  const rootMatch = matches.find((m) => m.id === "root");
  const siteName = rootMatch?.data?.siteName ?? "Site";
  return [{ title: `${data.title} | ${siteName}` }];
};
```

## Parent Merge Behavior (v1 vs v2)

v1 merged parent + child meta automatically with last-write-wins per key.
v2 picks the array returned by the **last matching route only**; sibling
routes are not combined and parent descriptors are NOT inherited unless the
child opts in via `matches`.

Consequence: if `root.tsx` defines its title via a `meta` export, every leaf
route that needs a title must either return a `{ title }` of its own OR
flatMap the parent meta. Most teams sidestep this by putting `charset`,
`viewport`, and any truly site-wide tags as **plain JSX** inside `<head>`:

```tsx
// app/root.tsx
<head>
  <meta charSet="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <Meta />
  <Links />
</head>
```

This keeps site-wide tags out of the merge logic entirely.

## JSON-LD (`script:ld+json`)

The `"script:ld+json"` descriptor is the only supported way to emit
structured-data scripts through the `meta` export. The value is a plain
object that Remix serializes as JSON.

```tsx
{
  "script:ld+json": {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "Example Corp",
    url: "https://example.com",
  },
}
```

Two routes both emitting `script:ld+json` with identical contents will
produce a React "same key" warning. Remix does not auto-deduplicate; keep
JSON-LD blocks in a single route (typically the leaf), not in `root` plus
the leaf.

## v1 → v2 Migration Pitfalls

1. **Object return still typechecks against the v1 `MetaFunction`.** Grep
   for `export const meta` followed by `return {` or `=> ({`. If the function
   returns an object literal, the route renders no meta tags. Convert to an
   array of descriptors.

2. **`parentsData` was removed.** Replace with `matches`. The
   `@remix-run/v1-meta` compatibility package exposes `getMatchesData()` for
   gradual migration; new code should use `matches` directly.

3. **OG shorthand keys are dropped.** Replace `{ "og:title": "..." }` with
   `{ property: "og:title", content: "..." }`.

4. **Default merge reversed.** Child routes inherit nothing from parents
   unless they merge via `matches.flatMap`. Codebases relying on inherited
   titles will render the parent's title on the leaf — or no title at all.

5. **`v2_meta: true` future flag** was the migration switch in late v1.
   Codebases that ran with it enabled before upgrading rarely have issues;
   codebases that jumped straight to v2 with v1-shaped `meta` exports are
   the ones that need cleanup.

6. **`charset` and `viewport` rendered through the `meta` export** can
   duplicate when parent merge happens manually. Most teams keep both as
   inline JSX in `root.tsx` to avoid the issue.

## Client-Side `document.title` Is Wrong

Setting `document.title = "..."` (or doing the same inside `useEffect`)
bypasses SSR — search bots and social previews see the default title, and
users see a visible flash on hydration. Always use the `meta` export with
`{ title }`. If the title must update from client state, return it from a
loader and re-render via revalidation.
