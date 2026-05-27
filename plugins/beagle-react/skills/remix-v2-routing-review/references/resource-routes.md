# Resource Routes

A route module without a `default` export is a **resource route**: it returns raw `Response` objects (PDF, JSON, RSS, sitemap, webhook). Parent loaders do not run, no UI mounts, and `<Link>` cannot navigate to it client-side without a full document request.

See [beagle-react:remix-v2-routing](../../remix-v2-routing/SKILL.md) for canonical resource-route shape.

---

## Accidental `default` export on a resource route

**Pattern**: A module meant to serve JSON, a PDF, or a webhook target also exports a default component.

```tsx
// app/routes/reports.$id[.pdf].tsx — smell
import type { LoaderFunctionArgs } from "@remix-run/node";
import invariant from "tiny-invariant";

export async function loader({ params }: LoaderFunctionArgs) {
  invariant(params.id, "id is required");
  const pdf = await generateReportPDF(params.id);
  return new Response(pdf, { headers: { "Content-Type": "application/pdf" } });
}

export default function ReportPage() {     // <-- turns it into a UI route
  return <div>Report</div>;
}
```

**Why bad**: A default export turns the module into a UI route. Parent loaders run, the error boundary mounts, Remix expects HTML, and the raw-Response fast path is dropped. The downstream symptom is a blank page or a parse error in the browser.

**Fix**: Delete the default export.

```tsx
// app/routes/reports.$id[.pdf].tsx — correct resource route
import type { LoaderFunctionArgs } from "@remix-run/node";
import invariant from "tiny-invariant";

export async function loader({ params }: LoaderFunctionArgs) {
  invariant(params.id, "id is required");
  const pdf = await generateReportPDF(params.id);
  return new Response(pdf, { headers: { "Content-Type": "application/pdf" } });
}
// No default export — that is what makes this a resource route.
```

**Do NOT flag** absence of a default export on its own. Absence *is* the convention. Only flag when a default export is present *and* the loader/action returns a non-HTML `Response`.

---

## `<Link>` to a resource route without `reloadDocument`

**Pattern**: Standard `<Link to="/api/report.pdf">` or `<Link to="/sitemap.xml">` pointing at a resource route.

```tsx
// smell
import { Link } from "@remix-run/react";

export function DownloadButton({ id }: { id: string }) {
  return <Link to={`/reports/${id}.pdf`}>Download</Link>;
}
```

**Why bad**: Client-side navigation tries to fetch the resource as a Remix route module. The browser ends up with a PDF byte stream where it expected route data, producing a parse error or blank page. The user clicks the link and nothing happens.

**Fix**: Use `reloadDocument` on the `<Link>` (forces a full document request) or use a plain `<a>`.

```tsx
import { Link } from "@remix-run/react";

export function DownloadButton({ id }: { id: string }) {
  return <Link reloadDocument to={`/reports/${id}.pdf`}>Download</Link>;
}

// Or:
export function DownloadAnchor({ id }: { id: string }) {
  return <a href={`/reports/${id}.pdf`}>Download</a>;
}
```

---

## Splat params accessed by the wrong key

**Pattern**: A splat route reading `params.splat`, `params.rest`, `params.path`, or any name other than `"*"`.

```tsx
// app/routes/files.$.tsx — smell
import type { LoaderFunctionArgs } from "@remix-run/node";

export async function loader({ params }: LoaderFunctionArgs) {
  const path = params.splat;           // undefined — wrong key
  return new Response(await readBlob(path), { /* … */ });
}
```

**Why bad**: Splat values are stored under the `"*"` key in `params`, not under a name derived from the filename. `params.splat` is always `undefined`, so the resource serves nothing or 500s on the `undefined` argument.

**Fix**: Bracket-access `params["*"]` and narrow before use.

```tsx
import type { LoaderFunctionArgs } from "@remix-run/node";

export async function loader({ params }: LoaderFunctionArgs) {
  const rest = params["*"];
  if (!rest) throw new Response("Not found", { status: 404 });
  return new Response(await readBlob(rest), { /* … */ });
}
```

There is no named splat in v2 — bracket access is the only correct way.

---

## Relying on parent loader side effects in a resource route

**Pattern**: A resource route assumes its `_auth.tsx` parent runs first and rejects unauthenticated requests, but the resource is requested directly (e.g., a `<Link reloadDocument>` or external curl).

**Why bad**: Parent loaders do **not** run for resource routes. Auth checks living only in a parent `_layout.tsx` are silently skipped on `GET /api/sensitive.json`.

**Fix**: Run the auth check inside the resource route's own loader (or action), not in a parent layout.

```tsx
// app/routes/api.sensitive[.]json.tsx
import type { LoaderFunctionArgs } from "@remix-run/node";
import { json } from "@remix-run/node";
import { requireUser } from "~/sessions.server";

export async function loader({ request }: LoaderFunctionArgs) {
  const user = await requireUser(request);     // local auth check
  return json(await loadSensitiveDataFor(user.id));
}
```

---

## Mixing `<Form>` action with a resource-route action

**Pattern**: A resource route exposes `action()` and is the target of a `<Form action="/api/webhook">`, but the form expects to revalidate parent loaders or navigate after submit.

**Why bad**: Resource-route actions don't trigger parent-loader revalidation the way UI-route actions do. Forms posting to a resource route should expect a raw `Response` back, not a navigation.

**Fix**: For mutations that need revalidation, post to the owning UI route's action. Reserve resource-route actions for webhooks or programmatic clients that consume the raw `Response`.

---

## Verification

For each resource-route finding:

1. Confirm the module has (or lacks) a `default` export — quote the export line.
2. Confirm what the `loader`/`action` returns (HTML, JSON, raw Response).
3. For `<Link>` flags: confirm the `to` target maps to a resource route (no default export) and the `<Link>` lacks `reloadDocument`.
4. For splat flags: quote the `params.<key>` access — if it's not `params["*"]`, it's wrong.
