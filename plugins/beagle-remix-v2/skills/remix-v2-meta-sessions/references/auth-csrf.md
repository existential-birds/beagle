# Auth and CSRF Reference

Remix v2 ships **no** built-in auth and **no** built-in CSRF protection. The
conventional patterns are a `requireUserId(request)` helper that throws
`redirect()` from loaders and actions, optionally paired with `remix-auth`
for strategy-based flows, plus `remix-utils/csrf` for token-based CSRF.

## The `requireUserId` Helper

The canonical Remix auth pattern is a helper that loads the session,
returns the `userId` if present, and **throws** `redirect(...)` otherwise.
Thrown responses short-circuit the loader; there's no top-level `return`
needed at the call site.

```ts
// app/auth.server.ts
import { redirect } from "@remix-run/node";
import { getSession } from "./session.server";

export async function requireUserId(request: Request): Promise<string> {
  const session = await getSession(request.headers.get("Cookie"));
  const userId = session.get("userId");
  if (!userId) {
    const url = new URL(request.url);
    const redirectTo = `${url.pathname}${url.search}`;
    throw redirect(`/login?redirectTo=${encodeURIComponent(redirectTo)}`);
  }
  return userId;
}

// Optional "may be logged out" variant.
export async function getUserId(request: Request): Promise<string | null> {
  const session = await getSession(request.headers.get("Cookie"));
  return session.get("userId") ?? null;
}
```

Usage in a protected loader:

```ts
// app/routes/dashboard.tsx
import type { LoaderFunctionArgs } from "@remix-run/node";
import { json } from "@remix-run/node";
import { requireUserId } from "~/auth.server";

export async function loader({ request }: LoaderFunctionArgs) {
  const userId = await requireUserId(request);
  const data = await getDashboardData(userId);
  return json({ data });
}
```

Same pattern works in actions — call `requireUserId` first, then run the
mutation. Treating auth as the first line of every protected loader and
action is the SSR-correct approach: unauthenticated users never see the
protected component's HTML, never receive its loader data, and never get
a flash of protected content.

## Auth Checks in React Components Are Wrong

```tsx
// DO NOT DO THIS
function Dashboard() {
  const user = useUser();
  if (!user) return <Navigate to="/login" />;
  return <ProtectedContent />;
}
```

The component still SSRs and ships its HTML to unauthenticated users. The
loader's data is already in the document. The `<Navigate>` redirect fires
after hydration — a visible flash of protected content. Always gate at the
loader.

## Login Action

```ts
// app/routes/login.tsx
import type { ActionFunctionArgs } from "@remix-run/node";
import { redirect } from "@remix-run/node";
import { getSession, commitSession } from "~/session.server";
import { verifyLogin } from "~/models/user.server";

export async function action({ request }: ActionFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  const form = await request.formData();
  const email = String(form.get("email") ?? "");
  const password = String(form.get("password") ?? "");

  const user = await verifyLogin(email, password);

  if (!user) {
    session.flash("error", "Invalid email or password");
    return redirect("/login", {
      headers: { "Set-Cookie": await commitSession(session) },
    });
  }

  session.set("userId", user.id);
  return redirect("/dashboard", {
    headers: { "Set-Cookie": await commitSession(session) },
  });
}
```

Failed-login response uses `session.flash` so the message survives the
redirect and clears on the next read. Successful login sets `userId` and
redirects; both paths attach `commitSession` as `Set-Cookie`.

## Logout Action

Logout MUST live in an `action`, never a `loader`. A `<Link to="/logout">`
pointing at a loader is CSRF-able via `<img src="/logout">` — any
third-party page can force-logout your users.

```ts
// app/routes/logout.tsx
import type { ActionFunctionArgs } from "@remix-run/node";
import { redirect } from "@remix-run/node";
import { getSession, destroySession } from "~/session.server";

export async function action({ request }: ActionFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  return redirect("/login", {
    headers: { "Set-Cookie": await destroySession(session) },
  });
}
```

In the UI:

```tsx
<Form method="post" action="/logout">
  <button type="submit">Log out</button>
</Form>
```

## `remix-auth` Brief Overview

For multi-strategy auth (OAuth, magic links, multiple providers),
`remix-auth` provides an `Authenticator<User>` that wraps your session
storage and runs strategy classes.

```ts
// app/auth.server.ts
import { Authenticator } from "remix-auth";
import { FormStrategy } from "remix-auth-form";
import { sessionStorage } from "~/session.server";

export const authenticator = new Authenticator<User>(sessionStorage);

authenticator.use(
  new FormStrategy(async ({ form }) => {
    const email = String(form.get("email"));
    const password = String(form.get("password"));
    const user = await verifyLogin(email, password);
    if (!user) throw new Error("Invalid credentials");
    return user;
  }),
  "user-pass",
);
```

In an action:

```ts
return authenticator.authenticate("user-pass", request, {
  successRedirect: "/dashboard",
  failureRedirect: "/login",
});
```

`remix-auth` requires session storage and writes the user into the session
itself. If you already have a working `requireUserId` helper, adding
`remix-auth` only makes sense once you have multiple strategies to manage.

## CSRF: Remix Has None

Remix ships no CSRF tooling. Same-origin `<Form>` posts rely entirely on
the `SameSite` value of the session cookie. `SameSite=Lax` blocks most
cross-origin POSTs but allows top-level GET navigations and has a known
exception for `<form method="post">` POSTs in some browsers. Subdomain
takeovers and older browsers leave further gaps.

The community answer is `remix-utils/csrf` — a separate signed cookie that
issues per-session tokens, validated in every mutating action.

## CSRF Setup with `remix-utils`

The CSRF token lives in its OWN cookie, never the session cookie. The
session cookie holds a serialized object; the CSRF cookie holds a signed
string. Reusing one cookie for both throws on validate.

```ts
// app/utils/csrf.server.ts
import { createCookie } from "@remix-run/node";
import { CSRF } from "remix-utils/csrf/server";

export const csrfCookie = createCookie("csrf", {
  path: "/",
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  secrets: [process.env.CSRF_SECRET!],
});

export const csrf = new CSRF({
  cookie: csrfCookie,
  secret: process.env.CSRF_SECRET!,
});
```

Issue the token in `root.tsx`'s loader and provide it to the component
tree:

```tsx
// app/root.tsx
import type { LoaderFunctionArgs } from "@remix-run/node";
import { json } from "@remix-run/node";
import { Outlet, Scripts, ScrollRestoration, useLoaderData } from "@remix-run/react";
import { AuthenticityTokenProvider } from "remix-utils/csrf/react";
import { csrf } from "~/utils/csrf.server";

export async function loader({ request }: LoaderFunctionArgs) {
  const [token, cookieHeader] = await csrf.commitToken(request);
  return json(
    { csrf: token },
    { headers: cookieHeader ? { "Set-Cookie": cookieHeader } : {} },
  );
}

export default function App() {
  const { csrf: token } = useLoaderData<typeof loader>();
  return (
    <html lang="en">
      {/* head ... */}
      <body>
        <AuthenticityTokenProvider token={token}>
          <Outlet />
        </AuthenticityTokenProvider>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}
```

Attach the token to every mutating form:

```tsx
import { Form } from "@remix-run/react";
import { AuthenticityTokenInput } from "remix-utils/csrf/react";

export default function CommentForm() {
  return (
    <Form method="post">
      <AuthenticityTokenInput />
      <textarea name="body" />
      <button type="submit">Post</button>
    </Form>
  );
}
```

For `useFetcher().submit(...)` calls, use `useAuthenticityToken()` to read
the token and include it in the submission payload manually.

## Validating in Actions

Every mutating action must call `csrf.validate(request)`. Skip it and the
action becomes the entry point an attacker uses.

```ts
import type { ActionFunctionArgs } from "@remix-run/node";
import { CSRFError } from "remix-utils/csrf/server";
import { csrf } from "~/utils/csrf.server";

export async function action({ request }: ActionFunctionArgs) {
  try {
    await csrf.validate(request);
  } catch (err) {
    if (err instanceof CSRFError) {
      throw new Response("Bad CSRF", { status: 403 });
    }
    throw err;
  }
  // ...continue with mutation
}
```

`CSRFError` exposes codes (`missing_token_in_cookie`, `invalid_token_in_cookie`,
`tampered_token_in_cookie`, `missing_token_in_body`, `mismatched_token`) for
finer-grained handling if needed.

## The Manual `fetch` POST Bypass

Hand-rolled `fetch("/api/x", { method: "POST" })` skips
`AuthenticityTokenInput` entirely, so `csrf.validate(request)` throws. The
fix is to use `<Form>` or `useFetcher().submit(...)`, which round-trip
through the form-data submission path the token wiring expects. If you
genuinely need a JSON `fetch`, manually attach the token in the body or
header — and audit every mutating action to confirm `csrf.validate` is the
first thing it does. An action without validation, reachable via plain
`fetch`, is an open CSRF hole regardless of any other defense.
