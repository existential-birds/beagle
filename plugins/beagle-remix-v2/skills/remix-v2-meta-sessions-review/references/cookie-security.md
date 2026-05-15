# Cookie Security — Anti-Patterns

Remix sets **no** secure defaults on cookies. Every flag is caller
responsibility. The common failure mode is a `createCookieSessionStorage`
config that ships to production missing `httpOnly`, `secure`, or rotation
support.

See [beagle-remix-v2:remix-v2-meta-sessions](../../remix-v2-meta-sessions/SKILL.md)
for the canonical setup.

## 1. Missing `httpOnly`

**Anti-pattern:**

```ts
// BAD — no httpOnly; cookie is readable from JavaScript
export const { getSession, commitSession } = createCookieSessionStorage({
  cookie: {
    name: "__session",
    secure: true,
    sameSite: "lax",
    secrets: [process.env.SESSION_SECRET!],
  },
});
```

**Why bad:** Without `httpOnly: true`, any XSS payload that lands on the
page can read the session cookie via `document.cookie` and exfiltrate it.
Defense-in-depth: even if your CSP catches one XSS vector, `httpOnly` makes
the cookie inert.

**Fix:** Add `httpOnly: true`. There is no legitimate reason to read a
session cookie from client JS — anything the page needs should come from
loader data.

```ts
cookie: {
  name: "__session",
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  secrets: [process.env.SESSION_SECRET!],
},
```

## 2. Missing or hardcoded `secure`

**Anti-pattern A — missing:**

```ts
// BAD — no secure flag; cookie sent over HTTP
cookie: {
  name: "__session",
  httpOnly: true,
  sameSite: "lax",
  secrets: [process.env.SESSION_SECRET!],
},
```

**Anti-pattern B — hardcoded `true`:**

```ts
// BAD — breaks local development; cookie never set on http://localhost
cookie: {
  name: "__session",
  httpOnly: true,
  secure: true,
  sameSite: "lax",
  secrets: [process.env.SESSION_SECRET!],
},
```

**Why bad:** Missing `secure` allows the cookie to be sent over plain
HTTP — any network-level adversary can sniff it. Hardcoding `secure: true`
blocks the cookie from being set at all on `http://localhost`, so
developers see "login does nothing" and either disable security entirely
or invent workarounds.

**Fix:** Tie `secure` to `NODE_ENV` so it is `true` in production and
`false` in development:

```ts
secure: process.env.NODE_ENV === "production",
```

## 3. Hardcoded session secrets in source

**Anti-pattern:**

```ts
// BAD — secret is now in git history forever
cookie: {
  name: "__session",
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  secrets: ["dev-secret-please-change"],
},
```

**Also bad:** A committed `.env.example` with a realistic-looking secret.
Junior devs copy it to `.env` and never rotate.

**Why bad:** Anyone with read access to the repo (current contributors,
former contributors, anyone who saw a leaked archive) can forge session
cookies and impersonate any user. The blast radius scales with the user
base.

**Fix:** Read from environment with a fail-fast guard. Never commit real
values. Use `.env.example` only for keys, not values — or use clearly fake
placeholders like `__set_a_strong_secret__`.

```ts
const SESSION_SECRET = process.env.SESSION_SECRET;
if (!SESSION_SECRET) throw new Error("SESSION_SECRET is required");

export const { getSession, commitSession, destroySession } =
  createCookieSessionStorage({
    cookie: {
      name: "__session",
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      secrets: [SESSION_SECRET],
    },
  });
```

## 4. Single-string `secrets` with no rotation plan

**Anti-pattern A — string, not array:**

```ts
// BAD — type-coerces in some Remix versions, but blocks rotation
secrets: process.env.SESSION_SECRET!, // string, not string[]
```

**Anti-pattern B — array with only one entry, no rotation slot:**

```ts
// BAD — works, but no migration path when you need to rotate
secrets: [process.env.SESSION_SECRET!],
```

Anti-pattern B is **not a CRITICAL** finding on its own — it works
correctly. Flag it as a recommendation when reviewing a session config
that has been in production long enough to need rotation, or when adjacent
code suggests the team is unaware rotation is supported.

**Why it matters:** `secrets` is an array because Remix signs new cookies
with `secrets[0]` and accepts any entry for verification. That is the
mechanism for rotating without invalidating existing sessions.

**Fix:** Always declare as an array; add an `_OLD` env slot for rotation.

```ts
secrets: [
  SESSION_SECRET,
  ...(process.env.SESSION_SECRET_OLD ? [process.env.SESSION_SECRET_OLD] : []),
],
```

## 5. Replace-not-prepend secret rotation

**Anti-pattern:** Operator deploys with `SESSION_SECRET` changed to a new
value and no `SESSION_SECRET_OLD`:

```bash
# BAD — instant logout for every user
SESSION_SECRET=new-strong-secret
```

**Why bad:** Remix signs with `secrets[0]` and verifies with any array
entry. If you replace the only entry, every existing cookie fails
verification and every user is logged out. Worse, users may interpret the
mass logout as a security incident.

**Fix:** Prepend the new secret. Keep the old one in `secrets` for at
least `maxAge` (so existing sessions remain valid until they expire
naturally), then remove it.

```bash
SESSION_SECRET=new-strong-secret
SESSION_SECRET_OLD=previous-strong-secret  # remove after maxAge elapses
```

Detection: a PR that changes `SESSION_SECRET` in deployment config
without adding/keeping `SESSION_SECRET_OLD` is a smell — flag with a
note about the rotation pattern.

## 6. Cookie-specific edge cases

**`sameSite` choice:**

- `"lax"` — acceptable default. Cookies sent on top-level navigations
  (including form GETs) but not on cross-origin sub-requests. Do NOT flag
  `"lax"` unless the app relies on the session cookie alone for CSRF
  protection (no `remix-utils/csrf` and no `Origin` checks).
- `"strict"` — required if you're using session cookie alone for CSRF
  defense.
- `"none"` — REQUIRES `secure: true`. Flag any `"none"` without `secure`,
  and flag any `"none"` without a documented cross-site use case (e.g.
  iframe embeds, OAuth callbacks).

**Missing `path`:** Defaults to the path of the request that set the
cookie. Most apps want `path: "/"` so the cookie covers all routes;
omitting it is rarely intentional. Flag as a minor issue.

**Missing `maxAge`/`expires`:** Cookie becomes a session cookie (cleared
on browser close). May be intentional for short-lived auth; ask the
author rather than flagging blindly.

## Detection notes for reviewers

- Search every `createCookieSessionStorage(` and `createCookie(` call.
  Open each and verify: `httpOnly`, `secure`, `sameSite`, `secrets`.
- Search for `secrets: [` followed by a string literal — that is the
  hardcoded-secret pattern.
- Search `.env.example` and any committed env files for realistic-looking
  values.
- `git log -p -- .env*` to confirm no real secret was ever committed.
  If one was, secret rotation is required regardless of current state.

## Hard gates reminder

Before flagging cookie config, confirm the file is actually wiring the
production session — not a test fixture, demo, or commented-out example.
Read the surrounding module to verify the exported `commitSession` is
imported by route modules.
