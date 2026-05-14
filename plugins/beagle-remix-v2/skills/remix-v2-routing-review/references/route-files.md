# Route File Naming Smells

Flat-routes v2 reads filenames literally: dots become URL slashes, `_` prefixes hide segments, brackets escape, and anything under `app/routes/` without a folder wrapper is treated as a route module. The smells below are violations of that grammar.

See [beagle-remix-v2:remix-v2-routing](../../remix-v2-routing/SKILL.md) for the canonical filename table.

---

## `index.tsx` instead of `_index.tsx`

**Pattern**: A file named `index.tsx` (no leading underscore) under `app/routes/` in a v2 project.

**Why bad**: In v2 flat-routes, `index.tsx` is interpreted as a literal URL segment, producing `/index`. The leading underscore is what marks it as an index route. Files left over from a v1 codebase silently route to the wrong URL after upgrade.

**Fix**:

```text
# Before
app/routes/index.tsx                 → /index   (wrong)
app/routes/concerts/index.tsx        → /concerts/index   (wrong, also v1 folder shape)

# After
app/routes/_index.tsx                → /
app/routes/concerts._index.tsx       → /concerts
```

---

## `__double` underscore folders (v1 pathless layouts)

**Pattern**: A folder under `app/routes/` named `__auth/`, `__app/`, etc., containing route files.

**Why bad**: v1 used double-underscore *folders* for pathless layouts (`app/routes/__auth/login.tsx`). v2 flat-routes uses a single-underscore *file* (`app/routes/_auth.tsx` + `app/routes/_auth.login.tsx`). v2's filesystem walker does not recognize the double-underscore folder convention — the routes either fail to mount or mount with the wrong URL.

**Fix**:

```text
# Before (v1)
app/routes/__auth/login.tsx          → expected /login under shared layout
app/routes/__auth/signup.tsx

# After (v2)
app/routes/_auth.tsx                 → pathless layout module with <Outlet />
app/routes/_auth.login.tsx           → /login   (inherits _auth)
app/routes/_auth.signup.tsx          → /signup  (inherits _auth)
```

If the v1 tree must stay during migration, wire `@remix-run/v1-route-convention` in `remix.config.js` — see [references/v1-holdovers.md](v1-holdovers.md). Don't flag double-underscore folders when the adapter is installed.

---

## Wrong escape syntax for literal characters

**Pattern**: Attempting to escape a literal dot, dollar, or other convention character with a backslash, quotes, or HTML entities.

```text
sitemap\.xml.tsx          # backslash — no
"sitemap.xml".tsx         # quotes   — no
$.cash.tsx                # trying to escape $ unprintably
```

**Why bad**: Only `[...]` brackets escape convention characters in v2. Anything else leaves the special character active — the dot becomes a path delimiter, the `$` becomes a dynamic segment.

**Fix**: Wrap the literal character(s) in brackets.

```text
sitemap[.]xml.tsx                    → /sitemap.xml
reports.$id[.pdf].tsx                → /reports/:id.pdf
[$]bill.tsx                          → /$bill   (literal dollar sign in URL)
```

---

## Dot vs underscore confusion

**Pattern**: Using a dot where an underscore was meant (or vice versa), creating routes that don't match the URL the author wrote in the comment.

```text
_auth.login.tsx     → /login              (correct — pathless _auth, child login)
_auth_login.tsx     → /_auth_login        (literal — author probably wanted /login)
_auth/login.tsx     → ignored or broken   (v1-style folder, no route.tsx)
auth._login.tsx     → /auth/_login        (leading underscore on child is a hidden index)
```

**Why bad**: Each character is grammar:
- `.` = URL slash and parent nesting
- `_` prefix = pathless (no URL contribution) or index marker
- `_` suffix on a segment = opt-out of layout nesting

Mixing them produces URLs that don't match intent and routes that miss their layout.

**Fix**: Pick the right grammar. Quick guide:

| Goal                                    | Filename                  | URL                |
|-----------------------------------------|---------------------------|--------------------|
| URL with shared layout                  | `parent.child.tsx`        | `/parent/child`    |
| URL **without** shared layout           | `parent_.child.tsx`       | `/parent/child`    |
| Shared layout, **no** URL segment       | `_auth.tsx` + `_auth.x.tsx` | `/x`             |
| Index under a layout                    | `parent._index.tsx`       | `/parent`          |

---

## Non-route files directly under `app/routes/`

**Pattern**: CSS, server-only helpers, test files, or component files placed at `app/routes/something.css`, `app/routes/utils.server.ts`, `app/routes/Chart.test.tsx`, etc.

**Why bad**: Remix's filesystem walker treats every file in `app/routes/` as a route module unless told otherwise. Non-route files surface as build warnings, mount as broken routes, or land at unexpected URLs.

**Fix**: Either move into a folder with a `route.tsx`, or list them in `ignoredRouteFiles`.

```text
# Folder convention — only route.tsx becomes a route
app/routes/dashboard/
  route.tsx
  queries.server.ts        # not a route
  Chart.tsx                # not a route
  Chart.test.tsx           # not a route
```

```js
// remix.config.js — ignore by glob
/** @type {import('@remix-run/dev').AppConfig} */
module.exports = {
  ignoredRouteFiles: ["**/.*", "**/*.css", "**/*.test.*", "**/*.server.*"],
};
```

---

## Trailing-underscore opt-out with no layout to escape

**Pattern**: A file named `admin_.users.tsx` when no sibling `admin.tsx` (parent layout) exists.

**Why bad**: The trailing underscore is meaningful only when there is a parent layout to skip. Without one, the underscore is noise — reviewers waste time looking for the layout it's escaping. Also signals the author misunderstands the grammar, which often hides a deeper routing bug.

**Fix**: Drop the trailing underscore. Or, if a parent layout *should* exist, add it (`admin.tsx`).

```text
# Smell
app/routes/admin_.users.tsx          # no admin.tsx exists

# Fix
app/routes/admin.users.tsx
```

---

## Verification

For each route-file smell:

1. List the path (`app/routes/<file>`).
2. Quote the literal filename.
3. Confirm v2 (see Hard gate 3 in [SKILL.md](../SKILL.md)).
4. Cross-check against `remix.config.js` — `@remix-run/v1-route-convention` and `ignoredRouteFiles` change which files are legitimate.
