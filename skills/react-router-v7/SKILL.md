---
name: react-router-v7
description: React Router v7 best practices for data-driven routing. Use when implementing routes, loaders, actions, Form components, fetchers, navigation guards, protected routes, or URL search params. Triggers on createBrowserRouter, RouterProvider, useLoaderData, useActionData, useFetcher, NavLink, Outlet.
---

# React Router v7 Best Practices

## Quick Reference

**Router Setup (Data Mode)**:
```tsx
import { createBrowserRouter, RouterProvider } from "react-router";

const router = createBrowserRouter([
  {
    path: "/",
    Component: Root,
    ErrorBoundary: RootErrorBoundary,
    loader: rootLoader,
    children: [
      { index: true, Component: Home },
      { path: "products/:productId", Component: Product, loader: productLoader },
    ],
  },
]);

ReactDOM.createRoot(root).render(<RouterProvider router={router} />);
```

**Framework Mode (Vite plugin)**:
```ts
// react-router.config.ts
import type { Config } from "@react-router/dev/config";

export default {
  ssr: true,
} satisfies Config;
```

```ts
// app/routes.ts
import { index, route, type RouteConfig } from "@react-router/dev/routes";

export default [
  index("./routes/home.tsx"),
  route("products/:pid", "./routes/product.tsx"),
] satisfies RouteConfig;
```

## Route Configuration

### Nested Routes with Outlets

```tsx
createBrowserRouter([
  {
    path: "/dashboard",
    Component: Dashboard,
    children: [
      { index: true, Component: DashboardHome },
      { path: "settings", Component: Settings },
    ],
  },
]);

function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Outlet /> {/* Renders child routes */}
    </div>
  );
}
```

### Dynamic Segments and Splats

```tsx
{ path: "teams/:teamId" }           // params.teamId
{ path: ":lang?/categories" }       // Optional segment
{ path: "files/*" }                 // Splat: params["*"]
```

## Key Decision Points

### Form vs Fetcher

**Use `<Form>`**: Creating/deleting with URL change, adding to history
**Use `useFetcher`**: Inline updates, list operations, popovers - no URL change

### Loader vs useEffect

**Use loader**: Data before render, server-side fetch, automatic revalidation (in Framework Mode, use `clientLoader` + `HydrateFallback` for client-only route data needed before render)
**Use useEffect**: Post-mount user-interaction fetches, timers, or subscriptions

## Gates (decision sequencing)

Answer **in order**. **Pass** means the condition is true; pick the API on the same line and **stop**.

### `<Form>` vs `useFetcher`

1. **Must the URL or history stack change** (bookmark/share, back returns to prior screen)?  
   - **Pass →** `<Form>` / route `action` (or `useSubmit` + navigation). **Stop.**  
   - **Fail →** Step 2.
2. **Mutation stays on the same route** (inline edit, modal, list row, no address change)?  
   - **Pass →** `useFetcher()`. **Stop.**  
   - **Fail →** Re-check step 1; you may need a dedicated action route or POST to the current URL.

### `loader` vs `useEffect`

1. **Is data needed for correct first render** (or your intended `<Suspense>` boundary) for this route?  
   - **Pass →** `loader` (Framework: `clientLoader` + `HydrateFallback` when data must load in the browser before render). **Stop.**  
   - **Fail →** Step 2.
2. **Fetch only after mount** from user action, timer, or subscription (not route entry)?  
   - **Pass →** `useEffect` / event handlers. **Stop.**  
   - **Fail →** Prefer loader + revalidation over an effect that mirrors navigation.

## Additional Documentation

- **Data Loading**: See [references/loaders.md](references/loaders.md) for loader patterns, streaming promises, `clientLoader`, search params, and revalidation
- **Mutations**: See [references/actions.md](references/actions.md) for actions, `clientAction`, `Form`, fetchers, and validation
- **Navigation**: See [references/navigation.md](references/navigation.md) for `Link`, `NavLink`, programmatic nav, and layouts
- **Advanced**: See [references/advanced.md](references/advanced.md) for error boundaries, protected routes, middleware (`v8_middleware`), and lazy loading

## Mode Comparison

| Feature | Framework Mode | Data Mode | Declarative Mode |
|---------|---------------|-----------|------------------|
| Setup | Vite plugin (`react-router.config.ts`) | `createBrowserRouter` | `<BrowserRouter>` |
| Type Safety | Auto-generated (`./+types/<route>`) | Manual / `LoaderFunctionArgs` | Manual |
| SSR Support | Built-in | Manual | Limited |
| Use Case | Full-stack apps | SPAs with control | Simple/legacy |
