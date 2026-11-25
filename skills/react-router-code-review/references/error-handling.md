# Error Handling

## Critical Anti-Patterns

### 1. Missing Error Boundaries

**Problem**: Entire app crashes on route errors, poor UX.

```tsx
// BAD - No error handling
const router = createBrowserRouter([
  {
    path: "/",
    Component: Root,
    children: [
      {
        path: "users/:userId",
        Component: UserProfile,
        loader: async ({ params }) => {
          // If this fails, entire app shows error
          return fetch(`/api/users/${params.userId}`).then(r => r.json());
        }
      }
    ]
  }
]);

// GOOD - Error boundaries at route level (Data Mode uses ErrorBoundary or errorElement;
// Framework Mode route modules export `export function ErrorBoundary()`)
const router = createBrowserRouter([
  {
    path: "/",
    Component: Root,
    ErrorBoundary: RootErrorBoundary, // Catch all errors
    children: [
      {
        path: "users/:userId",
        Component: UserProfile,
        ErrorBoundary: UserErrorBoundary, // Scoped error handling
        loader: async ({ params }) => {
          const response = await fetch(`/api/users/${params.userId}`);
          if (!response.ok) {
            throw new Response("User not found", { status: 404 });
          }
          return response.json();
        }
      }
    ]
  }
]);

// Error boundary component
function UserErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    if (error.status === 404) {
      return <div>User not found</div>;
    }
    if (error.status === 403) {
      return <div>You don't have permission to view this user</div>;
    }
  }

  return <div>Something went wrong loading this user</div>;
}
```

### 2. Not Using isRouteErrorResponse

**Problem**: Unsafe error access, runtime errors in error handlers.

```tsx
// BAD - Unsafe error access
function ErrorBoundary() {
  const error = useRouteError();

  // error might not have these properties!
  return (
    <div>
      <h1>Error {error.status}</h1>
      <p>{error.statusText}</p>
      <p>{error.data}</p>
    </div>
  );
}

// GOOD - Type-safe error checking
import { isRouteErrorResponse, useRouteError } from "react-router";

function ErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    // Now we know error has status, statusText, data
    return (
      <div>
        <h1>Error {error.status}</h1>
        <p>{error.statusText}</p>
        {typeof error.data === "string" && <p>{error.data}</p>}
      </div>
    );
  }

  if (error instanceof Error) {
    return (
      <div>
        <h1>Unexpected Error</h1>
        <p>{error.message}</p>
        {import.meta.env.DEV && <pre>{error.stack}</pre>}
      </div>
    );
  }

  return <div>An unknown error occurred</div>;
}
```

### 3. Throwing Raw Errors Instead of Responses

**Problem**: Missing status codes, inconsistent error format.

```tsx
// BAD - Throwing raw errors
const loader = async ({ params }: LoaderFunctionArgs) => {
  const user = await db.user.findUnique({
    where: { id: params.userId }
  });

  if (!user) {
    throw new Error("User not found"); // No status code!
  }

  if (!user.isPublic && !currentUser) {
    throw new Error("Unauthorized"); // Should be 403, not 500!
  }

  return user;
};

// GOOD - Throwing Response objects
const loader = async ({ params }: LoaderFunctionArgs) => {
  const user = await db.user.findUnique({
    where: { id: params.userId }
  });

  if (!user) {
    throw new Response("User not found", { status: 404 });
  }

  if (!user.isPublic && !currentUser) {
    throw new Response("You must be logged in to view this profile", {
      status: 403
    });
  }

  return user;
};

// BETTER - Using data() (or Response.json()) for structured errors in React Router v7
// (Note: json() was removed in v7.)
import { data, isRouteErrorResponse, Link, useRouteError, type LoaderFunctionArgs } from "react-router";

const loader = async ({ params }: LoaderFunctionArgs) => {
  const user = await db.user.findUnique({
    where: { id: params.userId }
  });

  if (!user) {
    throw data(
      { message: "User not found", userId: params.userId },
      { status: 404 }
    );
  }

  if (!user.isPublic && !currentUser) {
    throw data(
      { message: "Login required", redirectTo: `/login?return=/users/${params.userId}` },
      { status: 403 }
    );
  }

  return user;
};

// Error boundary using structured error
function ErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    if (error.status === 403 && error.data?.redirectTo) {
      return (
        <div>
          <p>{error.data.message}</p>
          <Link to={error.data.redirectTo}>Log in</Link>
        </div>
      );
    }

    if (error.status === 404) {
      return <div>{error.data.message}</div>;
    }
  }

  return <div>Something went wrong</div>;
}
```

### 4. Not Differentiating Error Types

**Problem**: Same handling for different errors, poor UX.

```tsx
// BAD - Generic error handling
function ErrorBoundary() {
  const error = useRouteError();

  // Everything gets same treatment
  return <div>Error: {String(error)}</div>;
}

// GOOD - Specific handling per error type
function ErrorBoundary() {
  const error = useRouteError();

  // Network/fetch errors
  if (error instanceof TypeError && error.message.includes("fetch")) {
    return (
      <div className="error">
        <h1>Network Error</h1>
        <p>Unable to connect to the server. Please check your connection.</p>
        <button onClick={() => window.location.reload()}>Retry</button>
      </div>
    );
  }

  // Route errors
  if (isRouteErrorResponse(error)) {
    if (error.status === 404) {
      return (
        <div className="error">
          <h1>Page Not Found</h1>
          <p>The page you're looking for doesn't exist.</p>
          <Link to="/">Go home</Link>
        </div>
      );
    }

    if (error.status === 403) {
      return (
        <div className="error">
          <h1>Access Denied</h1>
          <p>You don't have permission to access this resource.</p>
          <Link to="/login">Log in</Link>
        </div>
      );
    }

    if (error.status === 500) {
      return (
        <div className="error">
          <h1>Server Error</h1>
          <p>Something went wrong on our end. Please try again later.</p>
        </div>
      );
    }

    // Generic HTTP error
    return (
      <div className="error">
        <h1>Error {error.status}</h1>
        <p>{error.statusText}</p>
      </div>
    );
  }

  // JavaScript errors
  if (error instanceof Error) {
    return (
      <div className="error">
        <h1>Unexpected Error</h1>
        <p>{error.message}</p>
        {import.meta.env.DEV && (
          <details>
            <summary>Stack trace</summary>
            <pre>{error.stack}</pre>
          </details>
        )}
      </div>
    );
  }

  // Unknown error
  return (
    <div className="error">
      <h1>Unknown Error</h1>
      <p>An unexpected error occurred.</p>
    </div>
  );
}
```

### 5. Missing Root Error Boundary

**Problem**: Uncaught errors bubble to browser, blank screen.

```tsx
// BAD - No root error boundary
const router = createBrowserRouter([
  {
    path: "/",
    Component: Root,
    children: [
      // children routes...
    ]
  }
]);

// GOOD (SPA Data Mode mounted inside #root) - Root error boundary renders normal JSX inside #root
const router = createBrowserRouter([
  {
    path: "/",
    Component: Root,
    ErrorBoundary: RootErrorBoundary,
    children: [
      {
        path: "users",
        Component: Users,
        ErrorBoundary: UsersErrorBoundary, // Scoped
      },
    ]
  }
]);

function RootErrorBoundary() {
  const error = useRouteError();

  return (
    <div className="error-page">
      <header>
        <Link to="/">
          <img src="/logo.png" alt="My App" />
        </Link>
      </header>
      <main>
        {isRouteErrorResponse(error) ? (
          <>
            <h1>Error {error.status}</h1>
            <p>{error.statusText}</p>
          </>
        ) : error instanceof Error ? (
          <>
            <h1>Unexpected Error</h1>
            <p>{error.message}</p>
          </>
        ) : (
          <h1>Unknown Error</h1>
        )}
        <Link to="/">Go back home</Link>
      </main>
    </div>
  );
}

// Framework Mode (`app/root.tsx`) owns the full HTML document:
// wrap `ErrorBoundary` with `export function Layout({ children })` (which renders <html><head><body>)
// or return a complete `<html><head><Meta /><Links /></head><body>...<Scripts /></body></html>` shell.
```

### 6. Not Logging Errors

**Problem**: No visibility into production errors, hard to debug.

```tsx
// BAD - Silent errors
function ErrorBoundary() {
  const error = useRouteError();
  return <div>Error occurred</div>;
}

// GOOD - Errors logged to monitoring service
function ErrorBoundary() {
  const error = useRouteError();

  React.useEffect(() => {
    // Log to error tracking service
    if (isRouteErrorResponse(error)) {
      logError({
        type: "RouteError",
        status: error.status,
        statusText: error.statusText,
        data: error.data,
      });
    } else if (error instanceof Error) {
      logError({
        type: "JavaScriptError",
        message: error.message,
        stack: error.stack,
      });
    } else {
      logError({
        type: "UnknownError",
        error: String(error),
      });
    }
  }, [error]);

  return <ErrorDisplay error={error} />;
}

// BETTER - Centralized error logging (useEffect runs client-only; guard window defensively)
function useErrorLogging(error: unknown) {
  React.useEffect(() => {
    if (import.meta.env.DEV || typeof window === "undefined") return;

    // Send to monitoring service (Sentry, etc.)
    if (isRouteErrorResponse(error)) {
      window.analytics?.track("Route Error", {
        status: error.status,
        statusText: error.statusText,
        path: window.location.pathname,
      });
    } else if (error instanceof Error) {
      window.analytics?.track("JavaScript Error", {
        message: error.message,
        stack: error.stack,
        path: window.location.pathname,
      });
    }
  }, [error]);
}

function ErrorBoundary() {
  const error = useRouteError();
  useErrorLogging(error);

  return <ErrorDisplay error={error} />;
}
```

## Review Questions

1. Does every route (or parent) have an `ErrorBoundary` / `errorElement`?
2. Is `isRouteErrorResponse` used to check error types?
3. Are loaders/actions throwing `Response` / `data()` objects with status codes?
4. Are different error types handled differently?
5. Is there a root error boundary (matching Data Mode `#root` vs Framework Mode `app/root.tsx` `Layout`)?
6. Are errors logged to a monitoring service?
