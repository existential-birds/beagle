# Context Propagation in Go Middleware

## Type-Safe Context Keys

Never use plain `string` or `int` as context keys. Define an unexported type so keys from different packages cannot collide.

```go
// Define in your middleware package
type contextKey string

const (
    requestIDKey contextKey = "request_id"
    userKey      contextKey = "user"
    tenantIDKey  contextKey = "tenant_id"
)
```

Why this matters:
- `context.WithValue` uses interface equality for key comparison
- Two packages using `"user"` as a string key would overwrite each other
- An unexported `contextKey` type is unique to your package

## Request ID Propagation

Assign a request ID early in the middleware chain. Propagate it through context so every layer can include it in logs, error reports, and outgoing requests.

```go
func RequestID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("X-Request-ID")
        if id == "" {
            id = uuid.New().String()
        }
        ctx := context.WithValue(r.Context(), requestIDKey, id)
        w.Header().Set("X-Request-ID", id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func RequestIDFromContext(ctx context.Context) string {
    id, _ := ctx.Value(requestIDKey).(string)
    return id
}
```

Usage in downstream code:

```go
func handleOrder(w http.ResponseWriter, r *http.Request) {
    reqID := RequestIDFromContext(r.Context())
    slog.Info("processing order", "request_id", reqID)

    // Pass to outgoing HTTP calls
    outReq, _ := http.NewRequestWithContext(r.Context(), "GET", url, nil)
    outReq.Header.Set("X-Request-ID", reqID)
}
```

## User Metadata

Store authenticated user information in context after validation in auth middleware.

```go
type User struct {
    ID    string
    Email string
    Roles []string
}

const userKey contextKey = "user"

func AuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        user, err := validateToken(token)
        if err != nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        ctx := context.WithValue(r.Context(), userKey, user)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func UserFromContext(ctx context.Context) (*User, bool) {
    u, ok := ctx.Value(userKey).(*User)
    return u, ok
}
```

### Multi-Tenant Context

For multi-tenant applications, propagate the tenant ID alongside the user:

```go
const tenantIDKey contextKey = "tenant_id"

func TenantMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        user, ok := UserFromContext(r.Context())
        if !ok {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        tenantID := extractTenantID(user)
        ctx := context.WithValue(r.Context(), tenantIDKey, tenantID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func TenantIDFromContext(ctx context.Context) string {
    id, _ := ctx.Value(tenantIDKey).(string)
    return id
}
```

## Typed Helper Functions

Always provide exported helper functions for extracting context values. This encapsulates the key and type assertion in one place.

```go
// Good: callers use typed helpers
user, ok := UserFromContext(ctx)
reqID := RequestIDFromContext(ctx)
tenantID := TenantIDFromContext(ctx)

// Bad: callers reach into context directly
user := ctx.Value("user").(*User) // unsafe, untyped key
```

Always check the `ok` return from type assertions:

```go
func UserFromContext(ctx context.Context) (*User, bool) {
    u, ok := ctx.Value(userKey).(*User)
    return u, ok
}

// In handlers
user, ok := UserFromContext(r.Context())
if !ok {
    http.Error(w, "unauthorized", http.StatusUnauthorized)
    return
}
```

## Passing Context to Downstream Services

### Database Queries

Pass `r.Context()` to database calls so they respect request cancellation:

```go
func getUser(ctx context.Context, db *sql.DB, id string) (*User, error) {
    row := db.QueryRowContext(ctx, "SELECT id, email FROM users WHERE id = $1", id)
    var u User
    if err := row.Scan(&u.ID, &u.Email); err != nil {
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return &u, nil
}
```

### Outgoing HTTP Requests

Use `http.NewRequestWithContext` to propagate cancellation and pass along tracing headers:

```go
func callDownstream(ctx context.Context, url string) (*http.Response, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("creating request: %w", err)
    }
    req.Header.Set("X-Request-ID", RequestIDFromContext(ctx))
    return http.DefaultClient.Do(req)
}
```

## Context Timeout and Cancellation

For long operations, derive a context with a timeout to prevent requests from hanging:

```go
func slowHandler(w http.ResponseWriter, r *http.Request) {
    // Give the operation 5 seconds max
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
    defer cancel()

    result, err := longRunningQuery(ctx)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            http.Error(w, "request timed out", http.StatusGatewayTimeout)
            return
        }
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    json.NewEncoder(w).Encode(result)
}
```

### Timeout Middleware

Apply a blanket timeout to all requests:

```go
func Timeout(duration time.Duration) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ctx, cancel := context.WithTimeout(r.Context(), duration)
            defer cancel()
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

Note: this cancels the context but does not stop the handler goroutine. Handlers must check `ctx.Done()` or use context-aware I/O to actually stop work.

## Anti-patterns

### Using context.WithValue for function parameters

```go
// BAD: hiding dependencies in context
ctx = context.WithValue(ctx, "db", db)
// ...later...
db := ctx.Value("db").(*sql.DB)

// GOOD: explicit parameter
func handleOrder(ctx context.Context, db *sql.DB, orderID string) error {
    // ...
}
```

Context is for request-scoped metadata that crosses API boundaries, not for dependency injection.

### Storing large objects in context

```go
// BAD: large payload in context
ctx = context.WithValue(ctx, "body", largeRequestBody)

// GOOD: pass as parameter or store a reference/ID
ctx = context.WithValue(ctx, requestIDKey, reqID)
```

### Not checking ok from type assertion

```go
// BAD: panics if value is nil or wrong type
user := ctx.Value(userKey).(*User)

// GOOD: always check
user, ok := ctx.Value(userKey).(*User)
if !ok {
    return ErrUnauthorized
}
```
