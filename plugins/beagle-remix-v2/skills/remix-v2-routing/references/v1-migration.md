# v1 → v2 Routing Migration

Remix v1 used a **nested-folder** convention where directories created URL segments and double-underscore folder names marked pathless layouts. v2 replaces that with a **flat-file** convention where dots in filenames create URL slashes. The grammars are not compatible — leftover v1 files in a v2 project silently produce wrong URLs.

## Side-by-Side Convention Map

| Concept               | v1 (nested folders)            | v2 (flat routes)              |
|-----------------------|--------------------------------|-------------------------------|
| Index route           | `index.tsx`                    | `_index.tsx`                  |
| Pathless layout       | `__auth/` (double underscore)  | `_auth.tsx` (single)          |
| Nested URL            | folder hierarchy               | dot delimiter in filename     |
| Dynamic segment       | `$param.tsx`                   | `$param.tsx` (unchanged)      |
| Splat                 | `$.tsx`                        | `$.tsx` (unchanged)           |
| Escape literal        | n/a                            | `[.]`, `[]` brackets          |
| Opt-out of layout     | move out of folder             | trailing `_` (`foo_.bar.tsx`) |
| Co-locate non-routes  | adjacent files in folder       | `feature/route.tsx` + siblings|

## The Two Silent-Break Cases

These are the most common upgrade failures because the file still compiles, the dev server still starts, and the URL still resolves — just to something other than what v1 produced.

### 1. `index.tsx` → `_index.tsx`

In v1, `index.tsx` rendered at the parent path. In v2, `index.tsx` is read as a literal segment and renders at `/index`. Rename every index file:

```text
v1                                  v2
app/routes/index.tsx                app/routes/_index.tsx
app/routes/concerts/index.tsx       app/routes/concerts._index.tsx
app/routes/__auth/login.tsx         app/routes/_auth.login.tsx
```

### 2. `__double` underscore → `_single` underscore

v1 pathless layouts used a **folder** named `__auth` (with the folder itself containing routes). v2 uses a **file** named `_auth.tsx` (the parent module) plus dot-delimited children:

```text
v1                                  v2
app/routes/__auth/login.tsx         app/routes/_auth.tsx
app/routes/__auth/signup.tsx        app/routes/_auth.login.tsx
                                    app/routes/_auth.signup.tsx
```

A v1 `__auth` folder copied verbatim into v2 produces the literal URL `/__auth/login`.

## Folder-Hierarchy → Dot-Delimited

```text
v1                                          v2
app/routes/concerts/index.tsx               app/routes/concerts._index.tsx
app/routes/concerts/$city.tsx               app/routes/concerts.$city.tsx
app/routes/concerts/trending.tsx            app/routes/concerts.trending.tsx
```

If you prefer folders for organization, v2 supports them via the **folder + `route.tsx`** pattern. Only `route.tsx` becomes a route; siblings are colocated source:

```text
app/routes/
  concerts/
    route.tsx            ← becomes /concerts
    queries.server.ts    ← NOT a route
    Chart.tsx            ← NOT a route
```

Without a `route.tsx` inside, the folder is ignored entirely.

## v1 Compatibility Adapter: `@remix-run/v1-route-convention`

If a v1 route tree is large and you need to ship before migrating, install the official fallback adapter:

```bash
npm install -D @remix-run/v1-route-convention
```

Wire it in `remix.config.js`:

```js
// remix.config.js
const { createRoutesFromFolders } = require("@remix-run/v1-route-convention");

/** @type {import('@remix-run/dev').AppConfig} */
module.exports = {
  ignoredRouteFiles: ["**/.*"],
  routes(defineRoutes) {
    return createRoutesFromFolders(defineRoutes, {
      ignoredFilePatterns: ["**/.*", "**/*.css"],
    });
  },
};
```

The adapter preserves v1 nested-folder behavior — `index.tsx`, `__double` underscores, and folder-as-URL all keep working. Treat it as a migration aid, not a long-term answer: new code should adopt v2 conventions.

## `ignoredRouteFiles` for Non-Route Files

The flat structure means everything under `app/routes/` is a route candidate. CSS, server helpers, and test files dropped in there get treated as routes and surface as build warnings or 404-shaped routes. Two options:

**Option 1 — Folder convention**: move helpers into a `feature/` folder; only `route.tsx` becomes a route, siblings are inert.

**Option 2 — `ignoredRouteFiles`** in `remix.config.js`:

```js
// remix.config.js
module.exports = {
  ignoredRouteFiles: [
    "**/.*",                    // dotfiles
    "**/*.css",                 // stylesheets
    "**/*.test.{ts,tsx}",       // test files
    "**/*.server.{ts,tsx}",     // server-only modules
  ],
};
```

Globs that match are skipped during route discovery.

## Manual `routes()` for Programmatic Definitions

You can also define routes programmatically. The callback receives `defineRoutes` and runs **alongside** filesystem routes — it does not replace them. Use `ignoredRouteFiles` if you want the manual definitions to be authoritative:

```js
// remix.config.js
module.exports = {
  ignoredRouteFiles: ["**/*"],   // ignore filesystem entirely
  routes(defineRoutes) {
    return defineRoutes((route) => {
      route("/", "home.tsx", { index: true });
      route("/concerts/:city", "concerts/city.tsx");
    });
  },
};
```

## Migration Checklist

1. Rename every `index.tsx` → `_index.tsx` (in folders, also flatten with dots).
2. Convert every `__name/` folder → `_name.tsx` parent + dotted children.
3. Flatten folder hierarchies to dot-delimited filenames (or use folder + `route.tsx`).
4. Audit imports: every `react-router-dom` import must become `@remix-run/react`.
5. Add `ignoredRouteFiles` for any non-route files left under `app/routes/`.
6. If you can't migrate everything at once, install `@remix-run/v1-route-convention` and wire it into `remix.config.js` as a temporary fallback.
