# Server/Client Split Review

Anti-patterns in `.server.ts` / `.client.ts` boundaries, env var access, and module hygiene.

## What to flag

### 1. Server library imported in a route file without `.server.ts`

Remix's compiler strips `loader`, `action`, and `headers` from the client bundle along with the dependencies used **inside them** — but only if those dependencies have no module side effects. A top-level `new PrismaClient()`, an `initializeApp()` call, or even a `console.log` defeats tree-shaking. The dep leaks into the client bundle, breaks the build at runtime, or worse, ships secrets.

**Bad:**
```tsx
// app/lib/db.ts  -- no .server suffix
import { PrismaClient } from "@prisma/client";
export const prisma = new PrismaClient(); // top-level side effect

// app/routes/users.tsx
import { prisma } from "~/lib/db"; // leaks into client graph
```

**Good:**
```tsx
// app/lib/db.server.ts  -- never reaches client bundle
import { PrismaClient } from "@prisma/client";
export const prisma = new PrismaClient();

// app/routes/users.tsx
import { prisma } from "~/lib/db.server";
```

**Report as:** `[FILE:LINE] SERVER_LIB_WITHOUT_SERVER_SUFFIX` — `<lib>` imported from a non-`.server` module reachable from the client graph.

**Common server-only imports to scan for:** `@prisma/client`, `prisma`, `bcrypt`, `bcryptjs`, `argon2`, `jsonwebtoken`, `node:fs`, `node:path`, `node:crypto`, `fs`, `path`, `redis`, `ioredis`, `mongodb`, `pg`, `mysql2`, `aws-sdk`, `@aws-sdk/*`, `nodemailer`, `stripe` (server SDK — `@stripe/stripe-js` is the client version).

### 2. Secret env vars referenced in a component body or non-`.server` utility

`process.env` does not exist in the browser. References from a component body either crash at runtime, get inlined as `undefined`, or — worst case — get inlined as the actual secret string by some bundlers / Vite plugins.

**Bad:**
```tsx
// app/components/Checkout.tsx
export function Checkout() {
  const key = process.env.STRIPE_SECRET_KEY; // leaks to client
  return <CheckoutForm secretKey={key} />;
}
```

**Bad (transitive leak):**
```tsx
// app/lib/stripe.ts  -- no .server suffix
export const stripeKey = process.env.STRIPE_SECRET_KEY;
```

**Good:** read secrets only inside loaders/actions, or inside a `.server.ts` module:
```tsx
// app/lib/stripe.server.ts
import Stripe from "stripe";
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
```

**Report as:** `[FILE:LINE] SECRET_ENV_LEAK` — `process.env.<NAME>` read from a non-`.server` module reachable from the client graph.

**Scan for env names containing:** `SECRET`, `PRIVATE_KEY`, `TOKEN`, `PASSWORD`, `DATABASE_URL`, `API_KEY` (any provider), `JWT_*`, `WEBHOOK_SECRET`, `SESSION_SECRET`.

### 3. Raw `process.env` returned from root loader to client

Returning `process.env` (or even a large subset) from the root loader exposes every environment variable to every visitor as part of `window.ENV`. Common variant: spreading `...process.env` into a returned object.

**Bad:**
```tsx
// app/root.tsx
export async function loader() {
  return json({ ENV: process.env }); // every secret to every browser
}
```

**Also bad:**
```tsx
return json({ ENV: { ...process.env, EXTRA: "x" } });
```

**Good:** explicit whitelist of public keys only:
```tsx
return json({
  ENV: {
    STRIPE_PUBLIC_KEY: process.env.STRIPE_PUBLIC_KEY,
    POSTHOG_KEY: process.env.POSTHOG_KEY,
    PUBLIC_API_URL: process.env.PUBLIC_API_URL,
  },
});
```

**Report as:** `[FILE:LINE] PROCESS_ENV_RETURNED_FROM_LOADER` — entire `process.env` (or a spread of it) returned from a loader.

### 4. `typeof window === "undefined"` used as a substitute for `.server.ts`

Treeshaking is unreliable. A common pattern is to gate server code with `typeof window === "undefined"` at module top level — but the dead branch still pulls server deps into the client graph because the static `import` is hoisted regardless. The bundle either grows by megabytes, breaks at build time, or surfaces secrets.

**Bad:**
```tsx
// app/lib/logger.ts
import { createLogger } from "pino"; // hoisted import — always in client bundle
const logger = typeof window === "undefined"
  ? createLogger({ level: "info" })
  : { info: console.log, error: console.error };
export { logger };
```

**Good (split files):**
```tsx
// app/lib/logger.server.ts
import { createLogger } from "pino";
export const logger = createLogger({ level: "info" });

// app/lib/logger.client.ts
export const logger = { info: console.log, error: console.error };

// Import the right one from a route based on where it runs:
//   loader: import { logger } from "~/lib/logger.server";
//   component effect: import { logger } from "~/lib/logger.client";
```

**Good (function-body branch — acceptable for isomorphic helpers that don't import server libs):**
```tsx
export function getEnvLabel(): "server" | "client" {
  return typeof window === "undefined" ? "server" : "client";
}
```

**Report as:** `[FILE:LINE] TYPEOF_WINDOW_INSTEAD_OF_SERVER_SUFFIX` — module top-level branches on `typeof window` but still imports server-only deps.

### 5. Higher-order function wrapping a loader

`export const loader = withAuth(async (args) => { ... })` evaluates `withAuth` at module load — a module-level side effect that pins server-only deps into the client graph. The compiler's `loader` stripping can't see through the wrapper.

**Bad:**
```tsx
import { withAuth } from "~/lib/auth"; // wrapper imports prisma at top
export const loader = withAuth(async ({ params }) => { /* ... */ });
```

**Good (call the helper inside the loader body):**
```tsx
import type { LoaderFunctionArgs } from "@remix-run/node";
import { requireAuth } from "~/lib/auth.server";

export async function loader(args: LoaderFunctionArgs) {
  await requireAuth(args);
  // ...
}
```

**Report as:** `[FILE:LINE] HOF_WRAPPING_LOADER` — `loader` (or `action`) is wrapped in a higher-order function; helpers should be called inside the body.

### 6. `.client.ts` module imported into a server-only path

`.client.ts` modules are stripped from the server bundle — their exports are `undefined` during SSR. If a loader, action, or `.server` module imports from `.client.ts`, calls into it will throw `Cannot read properties of undefined`.

**Bad:**
```tsx
// app/lib/analytics.client.ts
export function track(event: string) { window.posthog.capture(event); }

// app/routes/checkout.tsx
import { track } from "~/lib/analytics.client";
export async function loader() {
  track("checkout_loaded"); // undefined.call during SSR — crash
  return null;
}
```

**Good:** call `.client` code only inside `useEffect`/event handlers:
```tsx
import { useEffect } from "react";
import { track } from "~/lib/analytics.client";

export default function Checkout() {
  useEffect(() => track("checkout_loaded"), []);
  return <CheckoutForm />;
}
```

**Report as:** `[FILE:LINE] CLIENT_MODULE_USED_ON_SERVER` — `.client.ts` import called from loader/action/`.server` module.

### 7. Secret env in a `links` or `meta` export

`links` and `meta` exports run on both server and client. References to `process.env.SECRET_*` inside them will be inlined into the client document.

**Bad:**
```tsx
export const meta: MetaFunction = () => [
  { name: "x-admin-token", content: process.env.ADMIN_TOKEN }, // leaked
];
```

**Good:** never read secrets in `links`/`meta`. If a route's meta legitimately depends on server-side config, return the value from the loader and read it via `useLoaderData()` in the component (not in `meta`, which receives only loader data anyway):
```tsx
export const meta: MetaFunction<typeof loader> = ({ data }) => [
  { name: "x-feature", content: data?.featureFlag ?? "" },
];
```

**Report as:** `[FILE:LINE] SECRET_ENV_IN_META_OR_LINKS` — secret env value referenced in `meta` or `links` export.

## Verify before flagging

- For "server lib without `.server.ts`," confirm the importing file is reachable from the client graph (route module, non-`.server` utility transitively imported by a component). Imports from inside another `.server.ts` are fine.
- For "secret env leak," confirm the env name actually looks secret. `STRIPE_PUBLIC_KEY`, `POSTHOG_KEY`, `PUBLIC_API_URL` are conventionally public. `STRIPE_SECRET_KEY`, `JWT_SECRET`, `DATABASE_URL` are conventionally private. If the project uses a different convention (`NEXT_PUBLIC_*`, `PUBLIC_*`, `VITE_*`), note that.
- For "`typeof window` substitute," confirm the file actually imports server deps. A pure isomorphic helper that branches on `typeof window` is fine — the issue is the static import at the top.
- For "HOF wrapping loader," confirm the wrapper actually imports server deps. A trivial type-only wrapper is fine.
- For "client module used on server," confirm the call site is in loader/action/`.server` code, not in `useEffect`/handler/`<ClientOnly>`.

## Verbatim quote requirements

Findings on this surface require a verbatim quote of:
- the `import` statement being flagged, OR
- the `process.env.<NAME>` reference being flagged, AND
- the surrounding context (file path + whether the call site is loader/action/component body/effect/handler).

A finding like "this file leaks prisma to the client" with no import path or call site is not reportable.
