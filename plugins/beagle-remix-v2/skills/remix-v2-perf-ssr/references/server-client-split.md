# Server/Client Split — `.server.ts`, `.client.ts`, and Env Vars

Remix v2 enforces a hard split between server-only and browser-only code through file naming conventions. This is not optional ergonomics — it's the only reliable way to keep server libraries out of the client bundle.

## Why tree-shaking is not enough

Remix's compiler strips `loader`, `action`, and `headers` exports from client bundles **and** the dependencies used inside them — but only if those dependencies have no module side effects. Real-world code routinely violates that:

```tsx
// app/lib/db.ts — looks fine, but tree-shaking is broken here
import { PrismaClient } from "@prisma/client";

// Top-level side effect — even if no client code calls `db`,
// this `new` expression cannot be tree-shaken out.
export const db = new PrismaClient();
```

Common side-effect patterns that defeat tree-shaking:

- Top-level `new` expressions (`new PrismaClient()`, `new OpenAI()`).
- Top-level function calls (`initializeApp(config)`, `console.log("...")`).
- Module-evaluation imports with effects (Sentry init, OpenTelemetry instrumentation).
- Higher-order function wrappers around loaders: `export const loader = withAuth(async (args) => {...})` — `withAuth` runs at module evaluation time and pins server-only deps into the client graph.

**Rule**: any module that imports `node:*` builtins (`fs`, `path`, `crypto`), database clients (`prisma`, `pg`, `mysql2`), crypto/auth libs (`bcrypt`, `jsonwebtoken`, `argon2`), or reads `process.env` at the top level must be named `*.server.ts` or live under `app/.server/`.

## `.server.*` file convention

Two equivalent forms:

```text
app/lib/db.server.ts          # filename suffix — works in both compilers
app/.server/db.ts             # directory form — Vite-only
```

Build behavior:

- **Vite plugin** (`@remix-run/dev` with Vite): if a `.server` module is reachable from the client graph, the build **fails loud** with an error pointing at the offending import chain.
- **Classic Compiler** (legacy `esbuild`-based): `.server` violations are **silent** — the bad import is replaced with an empty module at runtime, producing confusing `X is not a function` errors. The Classic Compiler also supports only the filename suffix, not the directory form.

Prefer Vite for new projects. If stuck on the Classic Compiler, be extra vigilant about `.server` naming.

```tsx
// app/lib/db.server.ts — never bundled into the client
import { PrismaClient } from "@prisma/client";
import { env } from "./env.server";

export const db = new PrismaClient({
  datasources: { db: { url: env.DATABASE_URL } },
});

// app/routes/users.tsx — safe to import a .server module
import { json } from "@remix-run/node";
import { db } from "~/lib/db.server";

export async function loader() {
  return json({ users: await db.user.findMany() });
}
```

## `.client.*` file convention

The mirror of `.server`: modules that should never be bundled or evaluated on the server.

```text
app/lib/analytics.client.ts
app/.client/leaflet-init.ts
```

On the server, exports from a `.client` module are `undefined`. This matters: a route component that imports a `.client` value at the top level and uses it in render will crash during SSR. Use `.client` modules from inside `useEffect`, event handlers, or `<ClientOnly>` children — never in render or at module top level of a server-rendered component.

```tsx
// app/lib/analytics.client.ts
import posthog from "posthog-js";

export function track(event: string, props?: Record<string, unknown>) {
  posthog.capture(event, props);
}

// In a route component:
import { useEffect } from "react";
import { track } from "~/lib/analytics.client";

export default function Page() {
  useEffect(() => {
    track("page_viewed");  // safe — useEffect runs only on the client
  }, []);
  return <h1>Hello</h1>;
}
```

## Env vars: server vs `window.ENV`

Server-only env vars are read via `process.env.X` **only inside `loader`, `action`, or a `.server` module**:

```tsx
// app/lib/env.server.ts
export const env = {
  DATABASE_URL: must("DATABASE_URL"),
  STRIPE_SECRET_KEY: must("STRIPE_SECRET_KEY"),
};

function must(key: string): string {
  const v = process.env[key];
  if (!v) throw new Error(`Missing env: ${key}`);
  return v;
}
```

**Never** reference `process.env` in a component body or in a non-`.server` utility imported by a component. `process.env` doesn't exist in the browser, and the bundler may inline the value, leaking the secret.

### Public env vars via `window.ENV`

Public values (Stripe publishable key, PostHog key, public API URLs) reach the client through the root loader, injected into `window.ENV` via a `<script>` tag:

```tsx
// app/root.tsx
import { json, type LoaderFunctionArgs } from "@remix-run/node";
import { Outlet, Scripts, ScrollRestoration, useLoaderData } from "@remix-run/react";

export async function loader(_args: LoaderFunctionArgs) {
  return json({
    ENV: {
      STRIPE_PUBLIC_KEY: process.env.STRIPE_PUBLIC_KEY,
      POSTHOG_KEY: process.env.POSTHOG_KEY,
      PUBLIC_API_URL: process.env.PUBLIC_API_URL,
    },
  });
}

export default function App() {
  const data = useLoaderData<typeof loader>();
  return (
    <html lang="en">
      <body>
        <Outlet />
        <ScrollRestoration />
        <script
          dangerouslySetInnerHTML={{
            __html: `window.ENV = ${JSON.stringify(data.ENV)}`,
          }}
        />
        <Scripts />
      </body>
    </html>
  );
}

// app/types/globals.d.ts
declare global {
  interface Window {
    ENV: {
      STRIPE_PUBLIC_KEY: string;
      POSTHOG_KEY: string;
      PUBLIC_API_URL: string;
    };
  }
}
```

**Critical**: only put **public** values into `ENV`. Anything in `window.ENV` is exposed to every visitor. Never `return json({ ENV: process.env })` — that ships every secret.

### `JSON.stringify` is not safe-for-inline-script

`JSON.stringify` does **not** escape `</script>` or U+2028/U+2029 line separators. If any string in your `ENV` payload contains `</script>`, it breaks out of the script context — an XSS vector. For hardened apps use `serialize-javascript`:

```tsx
import serialize from "serialize-javascript";

<script
  dangerouslySetInnerHTML={{
    __html: `window.ENV = ${serialize(data.ENV, { isJSON: true })}`,
  }}
/>
```

Or hand-escape `<`, `>`, `&`, `'`, U+2028, U+2029 before injection.

## Anti-patterns

- **`import { prisma } from "~/lib/db"`** with no `.server` suffix. Fix: rename to `db.server.ts`.
- **`process.env.STRIPE_SECRET_KEY` in a component**. Fix: read in loader, pass via `useLoaderData()` only if it's the **publishable** key — never the secret.
- **`export const loader = withAuth(async (args) => {...})`** — wrapper runs at module evaluation. Fix: call `await requireAuth(args)` **inside** the loader body.
- **`useState(localStorage.getItem("theme"))`** in a server-rendered component. Fix: initialize to a server-safe default, then sync from `localStorage` in `useEffect`; or wrap in `<ClientOnly>`.
- **Importing `node:fs`, `path`, `bcrypt`, `jsonwebtoken` from a non-`.server` utility consumed by a route component**. Fix: rename the file to `*.server.ts`.
- **`typeof window === "undefined"` at module top level** to branch imports — the dead branch can still pull server deps into the client graph. Fix: split into `.server.ts` and `.client.ts` files.

## Diagnosing leaks

If a build succeeds but the client bundle crashes with `Module not found: 'fs'` or `prisma is undefined`:

1. Grep for the offending import in any non-`.server` file.
2. Use Remix's build output to inspect what's in the client bundle (`build/client/assets/`).
3. Move the import into a `.server.ts` module and re-build. Vite will surface any remaining client-graph references.

The whole point of the `.server` convention is to convert silent runtime leaks into loud build failures. Use it liberally.
