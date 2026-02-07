# Structured Logging with slog

`log/slog` is the standard library structured logging package (Go 1.21+). It replaces the older `log` package for production services.

## Setting Up slog

### Production: JSON Handler

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))
slog.SetDefault(logger)
```

Output:
```json
{"time":"2024-01-15T10:30:00Z","level":"INFO","msg":"request completed","method":"GET","path":"/api/users","status":200,"duration_ms":42}
```

### Development: Text Handler

```go
logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
    Level:     slog.LevelDebug,
    AddSource: true,
}))
slog.SetDefault(logger)
```

Output:
```
time=2024-01-15T10:30:00Z level=INFO source=main.go:42 msg="request completed" method=GET path=/api/users status=200 duration_ms=42
```

### Choosing Based on Environment

```go
func setupLogger(env string) *slog.Logger {
    var handler slog.Handler
    switch env {
    case "production":
        handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
            Level: slog.LevelInfo,
        })
    default:
        handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
            Level:     slog.LevelDebug,
            AddSource: true,
        })
    }
    return slog.New(handler)
}
```

## Log Levels

slog provides four levels:

| Level | Value | Use for |
|-------|-------|---------|
| `slog.LevelDebug` | -4 | Verbose diagnostic info, disabled in production |
| `slog.LevelInfo` | 0 | Normal operations (request completed, job started) |
| `slog.LevelWarn` | 4 | Handled errors, degraded operation, approaching limits |
| `slog.LevelError` | 8 | Unhandled errors, panics, failed critical operations |

```go
slog.Debug("cache miss", "key", cacheKey)
slog.Info("request completed", "method", r.Method, "status", 200)
slog.Warn("rate limit approaching", "current", count, "limit", max)
slog.Error("database connection failed", "error", err)
```

## Logging Middleware

Capture HTTP method, path, response status, and request duration for every request.

```go
func Logger(logger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            // Wrap ResponseWriter to capture status code
            wrapped := &statusWriter{ResponseWriter: w, status: http.StatusOK}

            next.ServeHTTP(wrapped, r)

            logger.Info("request completed",
                "method", r.Method,
                "path", r.URL.Path,
                "status", wrapped.status,
                "duration_ms", time.Since(start).Milliseconds(),
                "request_id", RequestIDFromContext(r.Context()),
            )
        })
    }
}

type statusWriter struct {
    http.ResponseWriter
    status int
}

func (w *statusWriter) WriteHeader(code int) {
    w.status = code
    w.ResponseWriter.WriteHeader(code)
}
```

### Logging Errors vs Success at Different Levels

```go
func Logger(logger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            wrapped := &statusWriter{ResponseWriter: w, status: http.StatusOK}

            next.ServeHTTP(wrapped, r)

            attrs := []any{
                "method", r.Method,
                "path", r.URL.Path,
                "status", wrapped.status,
                "duration_ms", time.Since(start).Milliseconds(),
                "request_id", RequestIDFromContext(r.Context()),
            }

            switch {
            case wrapped.status >= 500:
                logger.Error("server error", attrs...)
            case wrapped.status >= 400:
                logger.Warn("client error", attrs...)
            default:
                logger.Info("request completed", attrs...)
            }
        })
    }
}
```

## Adding Request ID to All Log Entries

Use `slog.With` to create a child logger that includes the request ID in every log call within that request's scope:

```go
func LoggerWithContext(baseLogger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            reqID := RequestIDFromContext(r.Context())

            // Create a child logger with request_id baked in
            logger := baseLogger.With("request_id", reqID)

            // Store logger in context for use in handlers
            ctx := context.WithValue(r.Context(), loggerKey, logger)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

type contextKey string
const loggerKey contextKey = "logger"

func LoggerFromContext(ctx context.Context) *slog.Logger {
    if logger, ok := ctx.Value(loggerKey).(*slog.Logger); ok {
        return logger
    }
    return slog.Default()
}
```

Usage in handlers:

```go
func handleOrder(w http.ResponseWriter, r *http.Request) {
    logger := LoggerFromContext(r.Context())
    logger.Info("processing order", "order_id", orderID)
    // Output includes request_id automatically
}
```

## Child Loggers with Additional Context

Build up context as you go deeper into the call stack:

```go
func processOrder(ctx context.Context, order *Order) error {
    logger := LoggerFromContext(ctx).With(
        "order_id", order.ID,
        "customer_id", order.CustomerID,
    )

    logger.Info("validating order")
    if err := validate(order); err != nil {
        logger.Warn("validation failed", "error", err)
        return fmt.Errorf("validating order: %w", err)
    }

    logger.Info("charging payment")
    // ...
    return nil
}
```

## Structured Logging Best Practices

### Use consistent key names

```go
// Good: consistent naming across the codebase
slog.Info("query executed", "duration_ms", dur, "row_count", count)
slog.Info("request completed", "duration_ms", dur, "status", code)

// Bad: inconsistent naming
slog.Info("query executed", "elapsed", dur, "rows", count)
slog.Info("request completed", "time_ms", dur, "statusCode", code)
```

### Use slog.Group for namespaced attributes

```go
slog.Info("request",
    slog.Group("http",
        slog.String("method", r.Method),
        slog.String("path", r.URL.Path),
        slog.Int("status", status),
    ),
    slog.Group("timing",
        slog.Int64("duration_ms", dur),
    ),
)
// JSON: {"msg":"request","http":{"method":"GET","path":"/api","status":200},"timing":{"duration_ms":42}}
```

### Never log sensitive data

```go
// BAD
slog.Info("user login", "password", password, "token", authToken)

// GOOD
slog.Info("user login", "user_id", userID)
```

### Log errors with the "error" key

```go
// Consistent error key makes searching/filtering easy
slog.Error("database query failed", "error", err, "query", queryName)
slog.Warn("cache miss", "error", err, "key", cacheKey)
```

## StatusWriter Considerations

The basic `statusWriter` does not implement optional `http.ResponseWriter` interfaces. If you need `http.Flusher`, `http.Hijacker`, or `http.Pusher` support, implement them explicitly:

```go
type statusWriter struct {
    http.ResponseWriter
    status      int
    wroteHeader bool
}

func (w *statusWriter) WriteHeader(code int) {
    if !w.wroteHeader {
        w.status = code
        w.wroteHeader = true
    }
    w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Flush() {
    if f, ok := w.ResponseWriter.(http.Flusher); ok {
        f.Flush()
    }
}

func (w *statusWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
    if h, ok := w.ResponseWriter.(http.Hijacker); ok {
        return h.Hijack()
    }
    return nil, nil, fmt.Errorf("hijack not supported")
}
```
