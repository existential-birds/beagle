# Sessions Reference

Remix v2 sessions are built around a storage factory that returns three
functions: `getSession`, `commitSession`, and `destroySession`. The factory
you choose controls where session data lives; the API is identical for all
of them.

## Storage Factories

| Factory | Import | When to use |
|---|---|---|
| `createCookieSessionStorage<Data, Flash>` | `@remix-run/node` | Default. Payload lives in the cookie itself (signed, size-limited). |
| `createMemorySessionStorage` | `@remix-run/node` | Dev-only. Lost on restart; not multi-process safe. |
| `createFileSessionStorage` | `@remix-run/node` | Single-server Node/Deno deployments. |
| `createSessionStorage` | `@remix-run/node` | Custom backend (DB, Redis) via `createData` / `readData` / `updateData` / `deleteData`. |

For most apps `createCookieSessionStorage` is correct; cookies are signed,
stateless, and require no separate session store. Switch to
`createSessionStorage` only when payload size exceeds ~4 KB or you need
server-side revocation.

## Secure Cookie Configuration

Remix sets NO secure defaults. Every flag is caller-responsibility. Missing
`httpOnly` exposes the session to XSS; missing `secure` lets the cookie
leak over HTTP; missing `sameSite` opens CSRF surface.

```ts
// app/session.server.ts
import { createCookieSessionStorage } from "@remix-run/node";

type SessionData = { userId: string };
type SessionFlashData = { error: string };

const SESSION_SECRET = process.env.SESSION_SECRET;
if (!SESSION_SECRET) throw new Error("SESSION_SECRET is required");

export const { getSession, commitSession, destroySession } =
  createCookieSessionStorage<SessionData, SessionFlashData>({
    cookie: {
      name: "__session",
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60 * 24 * 30, // 30 days
      secrets: [
        SESSION_SECRET,
        ...(process.env.SESSION_SECRET_OLD ? [process.env.SESSION_SECRET_OLD] : []),
      ],
    },
  });
```

Notes on each flag:

- `name`: Prefix `__` is a convention for "framework-owned" cookies; pick
  something distinct from app data cookies.
- `httpOnly: true`: Blocks `document.cookie` access from JavaScript.
  Mandatory.
- `secure`: Read from env. Hardcoding `true` breaks `http://localhost` dev;
  hardcoding `false` ships an insecure cookie to production.
- `sameSite`: `"lax"` is the modern default. Use `"strict"` if you can
  accept that links from external sites to authenticated pages will land
  the user logged-out on the first request. `"none"` requires `secure: true`.
- `path: "/"`: Cookie sent on every request to the domain.
- `maxAge`: Seconds. Omit for a session-lifetime cookie that disappears
  when the browser closes.
- `domain`: Set explicitly only when sharing the session across subdomains.
- `secrets`: An array. See secret rotation below.

## Secret Rotation

Remix signs new cookies with `secrets[0]` and verifies incoming cookies
against any entry in the array. Rotation is therefore a **prepend**:

```ts
secrets: [
  process.env.SESSION_SECRET,         // new — used for signing
  process.env.SESSION_SECRET_OLD,     // old — still validates existing sessions
],
```

Replacing the secret outright (instead of prepending) instantly invalidates
every existing session. After `maxAge` has elapsed since the rotation, you
can drop the old entry.

Never commit a real secret to source or to `.env.example`. Anyone with the
secret can forge session cookies.

## Reading and Writing Sessions

```ts
import type { LoaderFunctionArgs } from "@remix-run/node";
import { json } from "@remix-run/node";
import { getSession, commitSession } from "~/session.server";

export async function loader({ request }: LoaderFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  const userId = session.get("userId");
  return json({ userId });
}
```

The `Session` instance exposes `get`, `set`, `has`, `unset`, and `flash`.

## `commitSession` Is Mandatory on Mutations

Remix does NOT auto-commit. Calling `session.set("userId", id)` and then
`return json(data)` ships zero `Set-Cookie` header — the change exists only
in memory and is dropped when the response sends.

Every response that touches the session must attach the committed cookie:

```ts
import { redirect } from "@remix-run/node";
import { getSession, commitSession } from "~/session.server";

export async function action({ request }: ActionFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  session.set("userId", user.id);

  return redirect("/dashboard", {
    headers: { "Set-Cookie": await commitSession(session) },
  });
}
```

Same pattern works with `json`:

```ts
return json(data, {
  headers: { "Set-Cookie": await commitSession(session) },
});
```

## `destroySession` for Logout

```ts
import { redirect } from "@remix-run/node";
import { getSession, destroySession } from "~/session.server";

export async function action({ request }: ActionFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  return redirect("/login", {
    headers: { "Set-Cookie": await destroySession(session) },
  });
}
```

`destroySession` returns a `Set-Cookie` header with an expired date,
clearing the cookie in the browser. Logout MUST live in an `action`, not a
`loader` — a `<Link to="/logout">` pointing at a loader is CSRF-able via
`<img src="/logout">`. Use `<Form method="post" action="/logout">`.

## Flash Messages

`session.flash(key, value)` writes a value that is automatically cleared
the first time it's read with `session.get(key)`. Useful for
one-shot status messages (form errors, success toasts) that survive a
single redirect.

```ts
// login action, failure case
const session = await getSession(request.headers.get("Cookie"));
session.flash("error", "Invalid email or password");
return redirect("/login", {
  headers: { "Set-Cookie": await commitSession(session) },
});

// login loader, reading the flash
export async function loader({ request }: LoaderFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  const error = session.get("error");
  return json(
    { error },
    { headers: { "Set-Cookie": await commitSession(session) } },
  );
}
```

The loader **must** call `commitSession` after reading the flash — that's
what writes the cleared state back to the cookie. Skipping the commit
either keeps the message forever (if not read) or never clears it
(depending on which side of the bug you hit).

The typed second parameter on `createCookieSessionStorage<Data, Flash>`
distinguishes flash keys from regular session keys at the type level, but
both forms write to the same cookie.

## Database-Backed Sessions

When cookies aren't enough (large payloads, server-side revocation), use
`createSessionStorage`:

```ts
import { createCookie, createSessionStorage } from "@remix-run/node";

const sessionCookie = createCookie("__session", {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  secrets: [process.env.SESSION_SECRET!],
});

export const { getSession, commitSession, destroySession } = createSessionStorage({
  cookie: sessionCookie,
  async createData(data, expires) {
    const id = await db.session.insert({ data, expires });
    return id;
  },
  async readData(id) {
    return db.session.find(id);
  },
  async updateData(id, data, expires) {
    await db.session.update(id, { data, expires });
  },
  async deleteData(id) {
    await db.session.delete(id);
  },
});
```

The cookie holds only the session id; payload lives in your database.
Public API is identical to `createCookieSessionStorage`.
