# CSRF — Anti-Patterns

Remix has **no built-in CSRF protection**. The community convention is
`remix-utils/csrf` with a dedicated signed cookie, an
`AuthenticityTokenProvider` in `root.tsx`, and `csrf.validate(request)` in
every mutating action. The common failure modes are no protection at all,
shared session/CSRF cookies, manual `fetch` POSTs that bypass token
injection, and shared secrets.

See [remix-v2-meta-sessions](../../remix-v2-meta-sessions/SKILL.md)
for the canonical wiring.

## 1. No CSRF protection at all

**Anti-pattern:** App ships without any token validation, relying on
"Remix is safe by default."

**Why bad:** Remix is **not** safe by default. The only protection
against cross-origin POSTs is whatever `SameSite` value the session
cookie carries. `SameSite=Lax` blocks cookies on cross-site POST
navigations in all current browsers. (Chrome briefly had a 2-minute
"Lax+POST" window in 2020 — removed in 2021.) The real `Lax`-vs-`Strict`
tradeoff is subdomain takeover: with `Lax`, a compromised subdomain can
initiate top-level GET nav with credentials; with `Strict`, deep-link
navigations from external sites lose session. Additional gaps:

- Subdomain takeovers: an attacker controlling `evil.example.com` can
  forge POSTs to `app.example.com` since `SameSite` treats sibling
  subdomains as same-site.
- Apps that use `SameSite=None` for legitimate cross-site needs (OAuth
  popups, iframe embeds) have no cookie-level CSRF protection at all.

**Fix:** Add `remix-utils/csrf`. Wire the provider in `root.tsx`, the
input in every `<Form>`, and `csrf.validate(request)` at the top of
every mutating action.

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

**Acceptable alternative:** If `remix-utils/csrf` is not in use, the app
must (a) set `sameSite: "strict"` on the session cookie AND (b) verify
the `Origin` header in every action. Document the threat model in the
repo. Flag any app that does neither.

## 2. CSRF token stored in the session cookie

**Anti-pattern:**

```ts
// BAD — reuses the session cookie for CSRF; types don't match
export const csrf = new CSRF({
  cookie: sessionCookie, // same cookie used for session storage
  secret: process.env.SESSION_SECRET!,
});
```

**Why bad:** The session cookie value is a serialized object (the
session data). The CSRF cookie value is a signed string (the token).
`remix-utils/csrf` writes its own value to the configured cookie; if
that cookie is also being used for session storage, every commit clobbers
the other.

At runtime: `csrf.validate(request)` throws on every request because the
serialized session object does not match the signed-token format.
Alternatively, session reads return `undefined` because CSRF overwrote
the value.

**Fix:** Use a dedicated `createCookie("csrf", ...)` with its own name
and its own secret env var. The CSRF cookie and the session cookie are
two separate cookies, each with their own `Set-Cookie` header on
responses that mutate them.

## 3. Manual `fetch` POST bypassing the token

**Anti-pattern:**

```tsx
// BAD — skips AuthenticityTokenInput; csrf.validate throws on the server
async function deletePost(id: string) {
  await fetch(`/posts/${id}/delete`, { method: "POST" });
}
```

**Why bad:** Two failure modes:

1. **If the action validates CSRF:** every manual POST returns 403 because
   no token was attached. The feature is broken.
2. **If the action does NOT validate CSRF:** this is the exact entry
   point an attacker uses. Cross-origin pages can submit the same POST
   and the server processes it.

Either way, the manual `fetch` route is wrong.

**Fix:** Use `<Form>` or `useFetcher().submit(...)` so
`AuthenticityTokenInput` (rendered inside the form) or
`useAuthenticityToken` (read inside `submit`) attaches the token.

```tsx
import { Form } from "@remix-run/react";
import { AuthenticityTokenInput } from "remix-utils/csrf/react";

export default function DeletePostForm({ id }: { id: string }) {
  return (
    <Form method="post" action={`/posts/${id}/delete`}>
      <AuthenticityTokenInput />
      <button type="submit">Delete</button>
    </Form>
  );
}
```

For programmatic submission, use `useFetcher`:

```tsx
const fetcher = useFetcher();
const token = useAuthenticityToken();

function deletePost(id: string) {
  const formData = new FormData();
  formData.set("csrf", token);
  fetcher.submit(formData, { method: "post", action: `/posts/${id}/delete` });
}
```

**Detection:** Grep `fetch("/`, `fetch(`/`, and `fetch(` followed by
`method: "POST"` (or PUT, PATCH, DELETE). Each call site is suspect —
verify whether the target action validates CSRF, and whether the call
attaches a token via headers.

## 4. Shared secrets across session cookie and CSRF

**Anti-pattern:**

```ts
// BAD — one env var feeds both session and CSRF
const SECRET = process.env.APP_SECRET!;

export const sessionStorage = createCookieSessionStorage({
  cookie: { name: "__session", secrets: [SECRET], /* ... */ },
});

export const csrf = new CSRF({
  cookie: csrfCookie, // separate cookie (good)
  secret: SECRET,     // same secret (bad)
});
```

**Why bad:** A compromise of one secret compromises both subsystems
simultaneously. Rotation of one forces rotation of the other, so teams
either rotate neither or accept higher blast radius. The two concerns
have different threat models and lifetimes; they should have independent
secrets.

This is also bad rotation hygiene: prepending a new `SESSION_SECRET`
while keeping `CSRF_SECRET` static means tokens issued before rotation
still validate against post-rotation session cookies — which is fine but
defeats the point of separate secrets.

**Fix:** Two env vars, two independent rotation schedules.

```ts
const SESSION_SECRET = process.env.SESSION_SECRET!;
const CSRF_SECRET = process.env.CSRF_SECRET!;
```

## Patterns NOT to flag

- **`<Form method="post">` without explicit CSRF input** — only flag if
  the app declares `remix-utils/csrf` as the protection mechanism and
  the form is missing `<AuthenticityTokenInput />`. If the app uses
  another approach (Origin check, `SameSite=Strict`), absence of
  `AuthenticityTokenInput` is correct.
- **`csrf.validate(request)` thrown without try/catch** — letting
  `CSRFError` propagate to the route error boundary is acceptable. Only
  flag if the error boundary doesn't return a 403 status.
- **`sameSite: "lax"` with CSRF library** — `remix-utils/csrf` is the
  primary defense; `"lax"` on the session cookie is fine.

## Reviewer note: `csrf.commitToken` return shape

`csrf.commitToken(request)` returns `[token, cookieHeader | undefined]`.
The cookie header may be undefined when the existing CSRF cookie is still
valid. Reviewers should look for the `cookieHeader ? { ... } : {}`
conditional in `root.tsx` and not flag the empty-headers branch as dead
code.

## Detection notes for reviewers

- Search `node_modules/.package-lock.json` or `package.json` for
  `remix-utils`. If absent, the app has no library-based CSRF.
- Search every `action` export. For each, confirm either
  `csrf.validate(request)` is called or an `Origin` header check is
  present, or the action is documented as intentionally unprotected
  (e.g. a public webhook with its own auth).
- Grep `fetch(` inside `app/` for any string that looks like an
  internal route path. Each one is a candidate for the manual-POST
  bypass.
- Compare `secrets: [` in session config with the `secret:` argument in
  `new CSRF({ ... })`. Same env var? Flag it.

## Hard gates reminder

Before flagging CSRF gaps, confirm the threat model. Internal admin
tools behind a VPN with no public exposure may legitimately skip CSRF.
Public-facing apps must have one of: library-based tokens,
`SameSite=Strict` + `Origin` checks, or documented compensating
controls.
