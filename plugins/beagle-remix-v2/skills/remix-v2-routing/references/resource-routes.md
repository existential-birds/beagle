# Resource Routes

A **resource route** is a route module that returns a raw HTTP `Response` instead of HTML. PDFs, sitemaps, RSS feeds, JSON APIs, OAuth callbacks, webhooks, and file downloads are all resource routes.

## The Defining Rule: No `default` Export

A route becomes a resource route when its module has **no `default` export**. That single fact controls everything else about its behavior — there's no decorator, no config flag, no naming convention. The presence or absence of `export default function` is the switch.

```tsx
// app/routes/reports.$id[.pdf].tsx   →   /reports/42.pdf
import type { LoaderFunctionArgs } from "@remix-run/node";

export async function loader({ params }: LoaderFunctionArgs) {
  const pdf = await generateReportPDF(params.id!);
  return new Response(pdf, {
    status: 200,
    headers: { "Content-Type": "application/pdf" },
  });
}

// NOTE: no `export default` — this is what makes it a resource route.
```

If you add a default export — even an empty one — Remix treats this as a UI route and the resource-route fast path disappears.

## What Changes When There's No Default Export

| Behavior              | UI route (default export) | Resource route (no default) |
|-----------------------|---------------------------|-----------------------------|
| Response type         | HTML document             | Raw `Response`              |
| Parent loaders run    | Yes                       | **No**                      |
| `ErrorBoundary` mount | Yes                       | No (errors propagate)       |
| `<Link>` navigation   | Client-side               | Requires `reloadDocument`   |
| Meta / Links / Scripts| Injected                  | Not injected                |
| Hydration             | Yes                       | N/A                         |

The most important entry: **parent loaders are skipped**. A GET to a resource route does not invoke ancestor loaders. Auth checks that live in a `_layout.tsx` parent will not run. Re-check auth inside the resource route's own loader.

## Linking to Resource Routes

A normal `<Link>` tries to fetch the route the way it would fetch any other Remix route. For a resource route, that yields a parse error or a blank page because Remix is expecting a route-shaped response. Two valid options:

```tsx
import { Link } from "@remix-run/react";

// 1. Force a full document request via Remix's Link
<Link reloadDocument to="/reports/42.pdf">Download</Link>

// 2. Or just use a plain anchor
<a href="/reports/42.pdf">Download</a>
```

`reloadDocument` tells Remix: don't client-route this — let the browser do a regular navigation, which is what binary responses need.

## Example: Sitemap

```tsx
// app/routes/sitemap[.]xml.tsx   →   /sitemap.xml
import type { LoaderFunctionArgs } from "@remix-run/node";

export async function loader({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const xml = await buildSitemap(url.origin);
  return new Response(xml, {
    status: 200,
    headers: {
      "Content-Type": "application/xml",
      "Cache-Control": "public, max-age=3600",
    },
  });
}
```

Note the `[.]` bracket-escape on the filename so the dot is treated as a literal character, not a URL-segment delimiter.

## Example: JSON API Endpoint

```tsx
// app/routes/api.users.$id.tsx
import type { LoaderFunctionArgs } from "@remix-run/node";
import { json } from "@remix-run/node";

export async function loader({ params, request }: LoaderFunctionArgs) {
  await requireApiKey(request);                // parent loaders DID NOT run
  const user = await getUser(params.id!);
  if (!user) throw new Response("Not found", { status: 404 });
  return json(user);
}
```

`json()` from `@remix-run/node` is a thin wrapper over `new Response(JSON.stringify(...), { headers: { "Content-Type": "application/json" } })` — use it freely in resource routes.

## Example: Webhook Receiver (Action Only)

A resource route can export only `action` if it's purely a write endpoint:

```tsx
// app/routes/webhooks.stripe.tsx
import type { ActionFunctionArgs } from "@remix-run/node";

export async function action({ request }: ActionFunctionArgs) {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const event = await verifyStripeSignature(request);
  await handleStripeEvent(event);
  return new Response(null, { status: 204 });
}
```

No `loader`, no `default` export — GETs will 405 from Remix's default method handling.

## Common Mistakes

- **Default export on a JSON/PDF/webhook route**: Turns it into a UI route. Parent loaders run, an `ErrorBoundary` mounts, Remix expects HTML. Delete the default export.
- **`<Link to="/api/foo.pdf">`** without `reloadDocument`: Client navigation tries to parse the binary as a route module. Returns a parse error or blank page.
- **Relying on auth in a parent layout's loader**: Parent loaders don't run for resource routes. Re-do the auth check inline.
- **Forgetting the bracket escape on dotted URLs**: `sitemap.xml.tsx` produces `/sitemap/xml`, not `/sitemap.xml`. Use `sitemap[.]xml.tsx`.
- **Returning a plain string or object**: Always return a `Response` (or `json(...)`). Returning a string yields `Content-Type: text/html` and a status the browser may not handle correctly for non-HTML payloads.
