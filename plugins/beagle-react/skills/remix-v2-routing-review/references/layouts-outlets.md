# Layouts and Outlets

Parent route modules must render `<Outlet />` so children can mount inside them. Pathless layouts (`_auth.tsx`) wrap URLs without adding a segment. Misuse shows up as blank pages, duplicated chrome, and dotted routes whose authors *thought* there was a layout.

See [remix-v2-routing](../../remix-v2-routing/SKILL.md) for canonical layout shape.

---

## Parent module missing `<Outlet />`

**Pattern**: A route module that has dotted child routes (`concerts.$city.tsx`, `concerts._index.tsx`) but its parent (`concerts.tsx`) does not render `<Outlet />`.

```tsx
// app/routes/concerts.tsx — smell
import { useLoaderData } from "@remix-run/react";

export default function ConcertsLayout() {
  const data = useLoaderData<typeof loader>();
  return (
    <section>
      <nav>{/* subnav */}</nav>
      {/* missing <Outlet /> — children never render */}
    </section>
  );
}
```

**Why bad**: Without `<Outlet />`, the parent renders but children mount nowhere. `/concerts/salt-lake-city` shows the parent chrome and a blank where the city detail should be.

**Fix**:

```tsx
import { Outlet } from "@remix-run/react";

export default function ConcertsLayout() {
  return (
    <section>
      <nav>{/* subnav */}</nav>
      <Outlet />
    </section>
  );
}
```

**Do NOT flag** when the parent module is intentionally a wrapper with fixed content and *no* sibling children exist in `app/routes/`. Check: if no `concerts.*.tsx` siblings exist, the wrapper-only shape may be deliberate (rare; usually a refactor remnant).

---

## Pathless layout that forgets to be a layout

**Pattern**: A `_auth.tsx` module that renders standalone content with no `<Outlet />`, while sibling `_auth.login.tsx` / `_auth.signup.tsx` files exist.

```tsx
// app/routes/_auth.tsx — smell
export default function AuthLayout() {
  return <div className="auth-shell"><h1>Sign in</h1></div>;
  // no Outlet — /login renders the AuthLayout but never the Login child
}
```

**Why bad**: The pathless parent owns the URL match for `/login`, but its render output replaces the child instead of wrapping it.

**Fix**:

```tsx
import { Outlet } from "@remix-run/react";

export default function AuthLayout() {
  return (
    <div className="auth-shell">
      <Outlet />
    </div>
  );
}
```

---

## Orphan dotted children with no parent module

**Pattern**: Files like `users.profile.settings.tsx` exist but `users.tsx` and `users.profile.tsx` do not.

```text
app/routes/
  users.profile.settings.tsx         # exists
  users.tsx                          # missing
  users.profile.tsx                  # missing
```

**Why bad**: The URL `/users/profile/settings` works, but reviewers (and the next developer) will look for a `users.tsx` layout that doesn't exist. The dotted name implies nesting that the filesystem doesn't back up.

**Fix**: Either add the missing parent layouts, or use trailing-underscore segments to make the flat intent explicit:

```text
# Make nesting real
app/routes/users.tsx
app/routes/users.profile.tsx
app/routes/users.profile.settings.tsx

# Or make flatness explicit
app/routes/users_.profile_.settings.tsx       → /users/profile/settings (flat)
```

---

## Duplicated layout chrome in every child

**Pattern**: Each child route (`dashboard.home.tsx`, `dashboard.billing.tsx`, `dashboard.team.tsx`) renders the same header/sidebar JSX inline instead of pulling it from a parent.

```tsx
// app/routes/dashboard.home.tsx — smell
export default function DashboardHome() {
  return (
    <div>
      <DashboardSidebar />        {/* duplicated */}
      <DashboardHeader />         {/* duplicated */}
      <main>{/* page content */}</main>
    </div>
  );
}
```

**Why bad**: Layout duplication causes flash-on-navigation (the chrome unmounts and remounts between sibling routes), keyboard-focus loss, and divergence over time as one copy gets updated and others don't. The whole point of nested routes is that the parent stays mounted.

**Fix**: Lift chrome into `dashboard.tsx` and render `<Outlet />`.

```tsx
// app/routes/dashboard.tsx — single source
import { Outlet } from "@remix-run/react";

export default function DashboardLayout() {
  return (
    <div>
      <DashboardSidebar />
      <DashboardHeader />
      <main><Outlet /></main>
    </div>
  );
}

// app/routes/dashboard.home.tsx — child renders only its content
export default function DashboardHome() {
  return <h1>Home</h1>;
}
```

---

## `_index` under a pathless parent at root

**Pattern**: A file named `_auth._index.tsx`.

**Why bad**: This renders at `/` wrapped in the `_auth` layout — almost never what was intended. Authors usually want `_auth.login.tsx` (renders at `/login`) or a top-level `_index.tsx` outside the auth shell.

**Fix**: Decide what URL you actually want.

```text
_auth._index.tsx       → /  (wrapped in AuthLayout) — usually wrong
_auth.login.tsx        → /login (wrapped in AuthLayout)
_index.tsx             → /  (no AuthLayout)
```

---

## Index file at a URL where it conflicts with a sibling

**Pattern**: Both `users.tsx` and `users._index.tsx` rendering content, where `users.tsx` does not render `<Outlet />`.

**Why bad**: `users.tsx` is the layout for the `/users` segment; `users._index.tsx` is the child that renders at exactly `/users`. If the parent doesn't outlet, the index never shows.

**Fix**: Parent renders `<Outlet />`, index renders the at-segment content.

```tsx
// app/routes/users.tsx
import { Outlet } from "@remix-run/react";
export default function UsersLayout() {
  return <section><Outlet /></section>;
}

// app/routes/users._index.tsx
export default function UsersIndex() {
  return <h1>All users</h1>;
}
```

---

## Verification

For each layout/outlet flag:

1. Quote the relevant module(s) and confirm `<Outlet />` is absent.
2. List the sibling files in `app/routes/` that depend on the parent.
3. Confirm the parent isn't a deliberate wrapper-only (no children → not a layout violation).
4. If pathless: check the URL the file actually produces against the URL the author commented.
