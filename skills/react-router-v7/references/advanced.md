# Advanced Patterns

## Contents

- [Error Boundaries](#error-boundaries)
  - [Root Error Boundary (Required)](#root-error-boundary-required)
  - [Throwing Errors in Loaders](#throwing-errors-in-loaders)
  - [Nested Error Boundaries](#nested-error-boundaries)
- [Protected Routes](#protected-routes)
  - [Component-Based Protection](#component-based-protection)
  - [Middleware (`future.v8_middleware` — Framework & Data Mode)](#middleware-futurev8_middleware--framework--data-mode)
- [Lazy Loading / Code Splitting](#lazy-loading--code-splitting)
  - [Data Mode Lazy Loading](#data-mode-lazy-loading)
  - [Declarative Mode Lazy Loading](#declarative-mode-lazy-loading)
- [Common Route Patterns](#common-route-patterns)
  - [Optional Segments](#optional-segments)
  - [Catch-All / Splat Routes](#catch-all--splat-routes)
  - [Multiple Params](#multiple-params)
- [Index vs Path Routes](#index-vs-path-routes)

---

## Error Boundaries

### Root Error Boundary (Required)

```tsx
import { createBrowserRouter, useRouteError, isRouteErrorResponse } from "react-router";

function RootErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    return (
      <>
        <h1>{error.status} {error.statusText}</h1>
        <p>{error.data}</p>
      </>
    );
  } else if (error instanceof Error) {
    return (
      <div>
        <h1>Error</h1>
        <p>{error.message}</p>
        <pre>{error.stack}</pre>
      </div>
    );
  } else {
    return <h1>Unknown Error</h1>;
  }
}

createBrowserRouter([
  {
    path: "/",
    ErrorBoundary: RootErrorBoundary,
    Component: Root,
  },
]);
```

### Throwing Errors in Loaders

Note: React Router v7 removed `json()` and `defer()`. Return plain objects directly, or use `data()` / `Response` when specifying custom status codes or headers:

```tsx
import { data, type LoaderFunctionArgs } from "react-router";

export async function loader({ params }: LoaderFunctionArgs) {
  const record = await db.getRecord(params.id!);
  if (!record) {
    throw data("Record Not Found", { status: 404 });
  }
  return record;
}
```

### Nested Error Boundaries

```tsx
createBrowserRouter([
  {
    path: "/app",
    ErrorBoundary: AppErrorBoundary,
    children: [
      {
        path: "invoices/:id",
        ErrorBoundary: InvoiceErrorBoundary,
        Component: Invoice,
      },
    ],
  },
]);
```

## Protected Routes

### Component-Based Protection

```tsx
import type { ReactNode } from "react";
import { Navigate, useLocation, useNavigate } from "react-router";

function RequireAuth({ children }: { children: ReactNode }) {
  const auth = useAuth();
  const location = useLocation();

  if (!auth.user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return children;
}

// Route configuration
{
  path: "/protected",
  element: (
    <RequireAuth>
      <ProtectedPage />
    </RequireAuth>
  ),
}

// In login handler - redirect back
function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const from = location.state?.from?.pathname || "/";

  function handleLogin() {
    auth.signin(() => {
      navigate(from, { replace: true });
    });
  }
}
```

### Middleware (`future.v8_middleware` — Framework & Data Mode)

In React Router v7.9+, middleware is supported in **both** Framework Mode and Data Mode via `future: { v8_middleware: true }` (default in v8).

**Framework Mode** (`react-router.config.ts` + route module):
```ts
// react-router.config.ts
import type { Config } from "@react-router/dev/config";

export default {
  future: { v8_middleware: true },
} satisfies Config;
```

```tsx
// app/routes/dashboard.tsx (Framework Mode)
import { redirect, createContext } from "react-router";
import type { Route } from "./+types/dashboard";

export const userContext = createContext<User | null>(null);

export const middleware: Route.MiddlewareFunction[] = [
  async function authMiddleware({ request, context }, next) {
    const userId = getUserId(request);
    if (!userId) {
      throw redirect("/login");
    }

    const user = await getUserById(userId);
    context.set(userContext, user);

    return next();
  },
];

export async function loader({ context }: Route.LoaderArgs) {
  const user = context.get(userContext);
  return { user };
}
```

**Data Mode** (`createBrowserRouter` with `RouterContextProvider`):
```tsx
import {
  createBrowserRouter,
  createContext,
  redirect,
  RouterContextProvider,
  type LoaderFunctionArgs,
} from "react-router";

const userContext = createContext<User | null>(null);

const router = createBrowserRouter(
  [
    {
      path: "/dashboard",
      middleware: [
        async ({ context }, next) => {
          const user = await fetchCurrentUser();
          if (!user) throw redirect("/login");
          context.set(userContext, user);
          return next();
        },
      ],
      loader: async ({ context }: LoaderFunctionArgs) => ({
        user: context.get(userContext),
      }),
      Component: Dashboard,
    },
  ],
  {
    future: { v8_middleware: true },
    getContext() {
      return new RouterContextProvider();
    },
  },
);
```

## Lazy Loading / Code Splitting

### Data Mode Lazy Loading

```tsx
createBrowserRouter([
  {
    path: "/app",
    lazy: async () => {
      const [{ default: Component }, { loader }] = await Promise.all([
        import("./app"),
        import("./app-loader"),
      ]);
      return { Component, loader };
    },
  },
]);
```

### Declarative Mode Lazy Loading

```tsx
import React from "react";

const About = React.lazy(() => import("./pages/About"));

<Routes>
  <Route
    path="about"
    element={
      <React.Suspense fallback={<>Loading...</>}>
        <About />
      </React.Suspense>
    }
  />
</Routes>
```

## Common Route Patterns

### Optional Segments

```tsx
{ path: ":lang?/categories" }     // Optional dynamic segment
{ path: "users/:userId/edit?" }   // Optional static segment at end
```

### Catch-All / Splat Routes

```tsx
{ path: "files/*" }

// Access splat in loader
loader: ({ params }: LoaderFunctionArgs) => {
  const filePath = params["*"]; // "path/to/file.txt"
}
```

### Multiple Params

```tsx
{ path: "users/:userId/posts/:postId" }

// params.userId, params.postId available in loader/component
```

## Index vs Path Routes

```tsx
createBrowserRouter([
  {
    path: "/dashboard",
    Component: Dashboard,
    children: [
      // Index route - renders when parent path matches exactly
      { index: true, Component: DashboardHome },

      // Path route - renders at parent + path
      { path: "settings", Component: Settings },
      { path: "profile", Component: Profile },
    ],
  },
]);
```

**Index renders at**: `/dashboard`
**Settings renders at**: `/dashboard/settings`
