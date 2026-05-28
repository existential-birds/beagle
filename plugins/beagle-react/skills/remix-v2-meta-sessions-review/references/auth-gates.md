# Auth Gates — Anti-Patterns

Remix has no built-in auth. The convention is a `requireUserId(request)`
helper that **throws** `redirect()` from inside loaders and actions, paired
with `commitSession`/`destroySession` on every mutation. The common failure
modes are gating in the wrong layer (component instead of loader), missing
`commitSession`, and logout-as-GET (CSRF-able).

See [beagle-react:remix-v2-meta-sessions](../../remix-v2-meta-sessions/SKILL.md)
for the canonical pattern.

## 1. Auth check in a React component (instead of loader)

**Anti-pattern:**

```tsx
// BAD — SSRs protected HTML and ships loader data to unauthenticated users
export default function Dashboard() {
  const user = useUser();
  if (!user) return <Navigate to="/login" />;
  return <PrivateContent />;
}
```

**Why bad:** Remix renders the entire route tree on the server. The
loader runs, fetches private data, and ships it down in the HTML payload.
By the time the React component decides "no user, redirect," the secret
data is already on the wire. The client then double-renders: a brief
flash of `<PrivateContent />` (or nothing if the loader threw), then the
redirect.

This pattern also creates a race: the protected component renders against
loader data that may be `null` or partial, often causing runtime errors
before the redirect fires.

**Fix:** Gate in the loader. Throw the redirect — Remix short-circuits
the request and never invokes the component.

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

// app/routes/dashboard.tsx
export async function loader({ request }: LoaderFunctionArgs) {
  const userId = await requireUserId(request);
  // ...fetch only data this user is allowed to see
  return json({ userId });
}
```

**Detection:** Search for `<Navigate to=` and `useNavigate()` calls in
route components that also have a `loader` export. Any auth check at the
component level is suspect.

## 2. Logout implemented in a `loader`

**Anti-pattern:**

```tsx
// app/routes/logout.tsx — BAD
export async function loader({ request }: LoaderFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  return redirect("/", {
    headers: { "Set-Cookie": await destroySession(session) },
  });
}

// Used as: <Link to="/logout">Log out</Link>
```

**Why bad:** Loaders run on GET requests. Any third-party page can
trigger logout by including `<img src="https://yoursite.com/logout">`,
or by linking from a malicious page. This is a classic CSRF vector — the
Remix sessions docs explicitly call it out.

Beyond CSRF, GET requests should be idempotent and safe per HTTP
semantics. Logout mutates server state (destroys the session); it must
be a POST.

**Fix:** Move to an `action` and use `<Form method="post">`.

```tsx
// app/routes/logout.tsx — GOOD
export async function action({ request }: ActionFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  return redirect("/", {
    headers: { "Set-Cookie": await destroySession(session) },
  });
}

// Used as:
<Form method="post" action="/logout">
  <button type="submit">Log out</button>
</Form>
```

**Detection:** Any route module named `logout.*` with a `loader` export
is almost always wrong. Also flag any `<Link to="/logout">` regardless of
the route's implementation — if the route correctly uses an `action`,
`<Link>` will hit the loader and 404 or do nothing.

## 3. Session mutation without `commitSession`

**Anti-pattern:**

```ts
// BAD — session.set runs, but no Set-Cookie header; mutation is lost
export async function action({ request }: ActionFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  session.set("userId", user.id);
  return json({ ok: true }); // no headers
}
```

**Why bad:** Remix does NOT auto-commit sessions. `session.set` mutates
the in-memory session object; without `commitSession`, the response has
no `Set-Cookie` header and the browser keeps the old cookie. The login
"succeeds" but the user is not actually logged in.

This bug is silent: typecheck passes, the action returns 200, the form
reports success — but the next request has no session.

**Fix:** Every mutation that writes to `session` (including
`session.set`, `session.unset`, `session.flash`) must produce a response
with `"Set-Cookie": await commitSession(session)`.

```ts
session.set("userId", user.id);
return redirect("/dashboard", {
  headers: { "Set-Cookie": await commitSession(session) },
});
```

**Detection grep:** Find `session.set(`, `session.unset(`, `session.flash(`.
For each, read forward to the next `return` and confirm the response
includes `commitSession`. If the function calls `redirect()` or `json()`
without a `headers.Set-Cookie`, that is the bug.

## 4. `session.flash` without `commitSession` on the reading side

**Anti-pattern:**

```ts
// app/routes/login.tsx loader — BAD
export async function loader({ request }: LoaderFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  const error = session.get("error"); // reads flash
  return json({ error }); // no commit — flash persists forever
}
```

**Why bad:** Flash messages are read-once: Remix clears them when the
session is **committed** after the read. Returning the loader response
without `commitSession` leaves the flash in the cookie. On the next
request the user sees the same error again. Worse, depending on read
order across loaders, the flash may appear to clear on some requests and
not others.

**Fix:** After reading a flash, commit the session and attach the
header. This is the standard 2-line pattern — `session.flash` and
`commitSession` on consecutive lines is correct; do not confuse it with
anti-pattern #3.

```ts
export async function loader({ request }: LoaderFunctionArgs) {
  const session = await getSession(request.headers.get("Cookie"));
  const error = session.get("error");
  return json(
    { error },
    { headers: { "Set-Cookie": await commitSession(session) } },
  );
}
```

**Note for reviewers:** A loader that calls `session.get(key)` for a
non-flash key (e.g. `userId`) does NOT need to commit — `get` does not
mutate. Only flash reads trigger the auto-clear-on-commit behavior.

## Patterns NOT to flag

- **Auth check in an `action` (not loader)** — correct for POST-only
  routes. Logout, delete, settings updates all gate via `requireUserId`
  inside `action`, not `loader`.
- **`throw redirect(...)`** — canonical pattern; the throw is intentional
  and short-circuits the loader.
- **`commitSession` in a loader** — required when reading a flash (#4
  above). Do not flag as "session shouldn't be mutated in a loader."
- **`flash` immediately followed by `commitSession` on the next line** —
  the standard pattern.
- **`requireUserId` returning early via throw** — no top-level `return`
  is needed in the loader; the thrown response is the exit.

## Detection notes for reviewers

- Open every route module under `app/routes/`. For each `loader` and
  `action`, ask: does this require auth? If yes, is `requireUserId`
  called? If the answer is "auth is checked in the component," that is
  the bug.
- Grep `<Link to="/logout"` and `<Link to={routes.logout}` — almost
  always wrong.
- Grep `session.set(`, `session.unset(`, `session.flash(`. Verify each
  is followed by a response with `commitSession` in the headers.
- For loaders that read user-facing errors: confirm `commitSession` on
  the response if the data came from `session.get` of a key written via
  `session.flash`.

## Hard gates reminder

Before flagging an auth issue, confirm the route is actually intended
to be protected (read the route's purpose). Public routes do not need
`requireUserId`, and flagging a missing auth gate on a public route is
a false positive.
