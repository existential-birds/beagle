# Centralized Error Handling and Recovery Middleware

## The AppHandler Pattern

Standard `http.HandlerFunc` has no return value, forcing each handler to write its own error responses. The `AppHandler` pattern lets handlers return errors, with a single centralized function mapping errors to HTTP responses.

### Custom Handler Type

```go
// AppHandler is an http.HandlerFunc that returns an error
type AppHandler func(w http.ResponseWriter, r *http.Request) error

// ServeHTTP implements http.Handler, calling the function and handling errors
func (fn AppHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    if err := fn(w, r); err != nil {
        handleError(w, r, err)
    }
}
```

Usage with a router:

```go
mux := http.NewServeMux()
mux.Handle("GET /users/{id}", AppHandler(getUser))
mux.Handle("POST /users", AppHandler(createUser))

func getUser(w http.ResponseWriter, r *http.Request) error {
    id := r.PathValue("id")
    user, err := db.FindUser(r.Context(), id)
    if err != nil {
        return fmt.Errorf("finding user %s: %w", id, err)
    }
    if user == nil {
        return ErrNotFound
    }
    return writeJSON(w, http.StatusOK, user)
}
```

Handlers focus on the happy path and return errors. The centralized `handleError` function takes care of logging and response formatting.

## Domain Errors

Define typed errors that map to HTTP status codes:

```go
type AppError struct {
    Code    int    `json:"-"`
    Message string `json:"error"`
    Detail  string `json:"detail,omitempty"`
}

func (e *AppError) Error() string { return e.Message }

var (
    ErrNotFound     = &AppError{Code: 404, Message: "resource not found"}
    ErrUnauthorized = &AppError{Code: 401, Message: "unauthorized"}
    ErrForbidden    = &AppError{Code: 403, Message: "forbidden"}
    ErrBadRequest   = &AppError{Code: 400, Message: "bad request"}
    ErrConflict     = &AppError{Code: 409, Message: "conflict"}
)
```

### Creating Errors with Detail

```go
func NewBadRequest(detail string) *AppError {
    return &AppError{
        Code:    400,
        Message: "bad request",
        Detail:  detail,
    }
}

// In a handler
func createUser(w http.ResponseWriter, r *http.Request) error {
    var input CreateUserInput
    if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
        return NewBadRequest("invalid JSON body")
    }
    if input.Email == "" {
        return NewBadRequest("email is required")
    }
    // ...
}
```

### Wrapping Domain Errors

Use `fmt.Errorf` with `%w` to add context while preserving the original error for `errors.As`:

```go
func getOrder(w http.ResponseWriter, r *http.Request) error {
    id := r.PathValue("id")
    order, err := db.FindOrder(r.Context(), id)
    if err != nil {
        return fmt.Errorf("finding order %s: %w", id, err)
    }
    if order == nil {
        return fmt.Errorf("order %s: %w", id, ErrNotFound)
    }
    return writeJSON(w, http.StatusOK, order)
}
```

## Centralized Error Handler

The `handleError` function maps errors to HTTP responses. Known `AppError` types get their specific status code; everything else is a 500.

```go
func handleError(w http.ResponseWriter, r *http.Request, err error) {
    logger := slog.Default()
    reqID := RequestIDFromContext(r.Context())

    var appErr *AppError
    if errors.As(err, &appErr) {
        logger.Warn("handled error",
            "error", appErr.Message,
            "detail", appErr.Detail,
            "status", appErr.Code,
            "request_id", reqID,
            "method", r.Method,
            "path", r.URL.Path,
        )
        writeJSON(w, appErr.Code, appErr)
        return
    }

    // Unexpected error -- do not leak internals
    logger.Error("unhandled error",
        "error", err.Error(),
        "request_id", reqID,
        "method", r.Method,
        "path", r.URL.Path,
    )
    writeJSON(w, 500, map[string]string{"error": "internal server error"})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(v)
}
```

Key principles:
- Known errors (AppError) are logged at Warn level with their detail
- Unknown errors are logged at Error level with the full message
- Clients never see internal error messages for unknown errors
- Every error log includes the request ID for correlation

## JSON Error Response Format

All error responses follow a consistent structure:

```json
{
    "error": "resource not found",
    "detail": "order abc-123"
}
```

The `detail` field is optional and omitted when empty. This consistency makes it easy for API clients to parse errors.

## Recovery Middleware

Panics in Go HTTP handlers crash the server (when not using `net/http`'s default recovery, which only logs and closes the connection). Recovery middleware catches panics and returns a proper error response.

```go
func Recovery(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if rec := recover(); rec != nil {
                slog.Error("panic recovered",
                    "panic", rec,
                    "stack", string(debug.Stack()),
                    "request_id", RequestIDFromContext(r.Context()),
                    "method", r.Method,
                    "path", r.URL.Path,
                )
                writeJSON(w, 500, map[string]string{"error": "internal server error"})
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

### Why Recovery Must Be Outermost

Recovery catches panics by wrapping the call to `next.ServeHTTP` in a deferred `recover()`. If any middleware outside of recovery panics, it won't be caught:

```go
// CORRECT: recovery wraps everything
handler := Recovery(RequestID(Logger(router)))

// WRONG: panics in RequestID or Logger are not caught
handler := RequestID(Logger(Recovery(router)))
```

### Stack Trace Logging

`runtime/debug.Stack()` returns the goroutine's stack trace at the point of the panic. Log this at Error level for debugging, but never include it in the HTTP response.

```go
import "runtime/debug"

slog.Error("panic recovered",
    "panic", rec,
    "stack", string(debug.Stack()),
)
```

### Never Expose Panic Details to Clients

The panic value (`rec`) often contains internal information -- file paths, memory addresses, or internal state. Always return a generic error message:

```go
// GOOD: generic message to client
writeJSON(w, 500, map[string]string{"error": "internal server error"})

// BAD: leaking panic info
writeJSON(w, 500, map[string]string{"error": fmt.Sprintf("%v", rec)})
```

## Combining AppHandler with Recovery

The `AppHandler` pattern handles returned errors; recovery handles panics. Together they cover all failure modes:

```go
// AppHandler catches returned errors
func getUser(w http.ResponseWriter, r *http.Request) error {
    user, err := db.FindUser(r.Context(), r.PathValue("id"))
    if err != nil {
        return fmt.Errorf("finding user: %w", err) // caught by AppHandler
    }
    return writeJSON(w, 200, user)
}

// Recovery catches panics (e.g., nil pointer dereference)
// Applied as outermost middleware
handler := Recovery(
    RequestID(
        Logger(router),
    ),
)
```

Handlers should return errors, not panic. Recovery is a safety net for unexpected situations (nil pointer dereference, index out of range, third-party library panics).

## Testing Error Handling

```go
func TestHandleError_AppError(t *testing.T) {
    w := httptest.NewRecorder()
    r := httptest.NewRequest("GET", "/test", nil)

    handleError(w, r, ErrNotFound)

    if w.Code != 404 {
        t.Errorf("expected 404, got %d", w.Code)
    }

    var body map[string]string
    json.NewDecoder(w.Body).Decode(&body)
    if body["error"] != "resource not found" {
        t.Errorf("expected 'resource not found', got %q", body["error"])
    }
}

func TestHandleError_UnknownError(t *testing.T) {
    w := httptest.NewRecorder()
    r := httptest.NewRequest("GET", "/test", nil)

    handleError(w, r, fmt.Errorf("database connection refused"))

    if w.Code != 500 {
        t.Errorf("expected 500, got %d", w.Code)
    }

    var body map[string]string
    json.NewDecoder(w.Body).Decode(&body)
    if body["error"] != "internal server error" {
        t.Errorf("expected 'internal server error', got %q", body["error"])
    }
}

func TestRecoveryMiddleware(t *testing.T) {
    panicking := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        panic("something went wrong")
    })

    handler := Recovery(panicking)
    w := httptest.NewRecorder()
    r := httptest.NewRequest("GET", "/test", nil)

    handler.ServeHTTP(w, r)

    if w.Code != 500 {
        t.Errorf("expected 500, got %d", w.Code)
    }
}
```
