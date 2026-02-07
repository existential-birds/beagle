# Graceful Shutdown

Every production Go HTTP server must handle shutdown gracefully: finish in-flight requests, close database connections, and flush buffers before exiting. An abrupt `os.Exit` or unhandled signal drops active requests and can corrupt data.

## Full Pattern

```go
package main

import (
    "context"
    "database/sql"
    "fmt"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func run(ctx context.Context) error {
    ctx, cancel := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
    defer cancel()

    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close()

    srv := NewServer(db, slog.Default())

    httpServer := &http.Server{
        Addr:    ":8080",
        Handler: srv,
    }

    errCh := make(chan error, 1)
    go func() {
        slog.Info("server starting", "addr", httpServer.Addr)
        if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            errCh <- err
        }
    }()

    // Wait for interrupt signal or server error
    select {
    case <-ctx.Done():
    case err := <-errCh:
        return fmt.Errorf("server listen: %w", err)
    }
    slog.Info("shutting down gracefully")

    // Give outstanding requests time to complete
    shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer shutdownCancel()

    if err := httpServer.Shutdown(shutdownCtx); err != nil {
        return fmt.Errorf("server shutdown: %w", err)
    }

    return nil
}

func main() {
    if err := run(context.Background()); err != nil {
        slog.Error("application error", "err", err)
        os.Exit(1)
    }
}
```

## Why `run()` Returns an Error

Separating `run()` from `main()` provides several benefits:

1. **Testability** -- You can call `run()` in tests with a cancelable context and verify behavior without starting a real process.
2. **Clean error handling** -- `run()` uses normal Go error returns instead of `log.Fatal()`, which calls `os.Exit(1)` and skips deferred cleanup.
3. **Deferred cleanup runs** -- Since `run()` returns instead of exiting, all `defer` statements (db.Close(), cancel(), etc.) execute in order.
4. **Single exit point** -- `main()` is the only place that calls `os.Exit`, making the exit path predictable.

```go
// BAD -- defers never run, no cleanup
func main() {
    db, err := sql.Open(...)
    if err != nil {
        log.Fatal(err) // calls os.Exit(1), skips defer db.Close()
    }
    defer db.Close()
    // ...
}

// GOOD -- all defers run, clean exit
func main() {
    if err := run(context.Background()); err != nil {
        slog.Error("application error", "err", err)
        os.Exit(1)
    }
}
```

## signal.NotifyContext vs signal.Notify

### signal.NotifyContext (preferred)

```go
ctx, cancel := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
defer cancel()

<-ctx.Done() // blocks until signal received
```

Benefits:
- Returns a standard `context.Context` that integrates with the rest of the application
- Cancelation propagates to all child contexts automatically
- `defer cancel()` cleans up signal registration
- Idiomatic for modern Go code

### signal.Notify (older pattern)

```go
quit := make(chan os.Signal, 1)
signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

<-quit // blocks until signal received
```

Use `signal.Notify` only when you need to handle the same signal multiple times or perform special signal-specific logic. For typical graceful shutdown, `signal.NotifyContext` is cleaner.

## Shutdown Timeout Configuration

The shutdown timeout controls how long the server waits for in-flight requests to complete before forcefully closing connections.

```go
shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
defer shutdownCancel()
```

### Choosing a Timeout Value

| Scenario | Recommended Timeout |
|----------|-------------------|
| API with fast queries | 5-10 seconds |
| Long-polling / SSE | 30 seconds |
| File uploads | 60 seconds |
| WebSocket connections | 30-60 seconds |

Make the timeout configurable:

```go
type Config struct {
    ShutdownTimeout time.Duration `env:"SHUTDOWN_TIMEOUT" default:"10s"`
}

shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
```

### What Happens When the Timeout Expires

If `httpServer.Shutdown(shutdownCtx)` exceeds the timeout, it returns `context.DeadlineExceeded`. At that point:
- Any remaining connections are forcefully closed
- The server stops accepting new connections (this happens immediately on Shutdown call)
- Clients with active requests receive connection-reset errors

## Cleanup Ordering

Resources must be cleaned up in reverse order of creation. The server should stop accepting new requests before closing the resources those requests depend on.

```go
func run(ctx context.Context) error {
    ctx, cancel := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
    defer cancel()

    // 1. Open database (first resource created)
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close() // 4. Close database LAST (after server is done)

    // 2. Create cache client
    cache := redis.NewClient(...)
    defer cache.Close() // 3. Close cache after server, before database

    srv := NewServer(db, cache, slog.Default())

    httpServer := &http.Server{
        Addr:    ":8080",
        Handler: srv,
    }

    go func() {
        if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            slog.Error("server error", "err", err)
        }
    }()

    <-ctx.Done()

    // Shutdown server FIRST -- drains in-flight requests that use db and cache
    shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer shutdownCancel()

    if err := httpServer.Shutdown(shutdownCtx); err != nil {
        return fmt.Errorf("server shutdown: %w", err)
    }

    // Then defers run in LIFO order: cache.Close(), then db.Close()
    return nil
}
```

The ordering is:
1. Stop accepting new connections (`Shutdown` called)
2. Wait for in-flight requests to finish (up to timeout)
3. Close cache (deferred, LIFO)
4. Close database (deferred, LIFO)

### With Background Workers

If you have background goroutines (job processors, consumers), shut them down after the HTTP server but before closing shared resources:

```go
<-ctx.Done()

// 1. Stop HTTP server
httpServer.Shutdown(shutdownCtx)

// 2. Stop background workers (they may still use db)
workerCancel()
workerWg.Wait()

// 3. Defers close db, cache, etc.
return nil
```

## Health Check Endpoint

In container orchestrators (Kubernetes, ECS), the health check should start failing before the server shuts down. This tells the load balancer to stop sending new traffic.

```go
type Server struct {
    db       *sql.DB
    logger   *slog.Logger
    router   *http.ServeMux
    healthy  atomic.Bool
}

func NewServer(db *sql.DB, logger *slog.Logger) *Server {
    s := &Server{
        db:     db,
        logger: logger,
        router: http.NewServeMux(),
    }
    s.healthy.Store(true)
    s.routes()
    return s
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
    if !s.healthy.Load() {
        w.WriteHeader(http.StatusServiceUnavailable)
        fmt.Fprintln(w, "shutting down")
        return
    }
    w.WriteHeader(http.StatusOK)
    fmt.Fprintln(w, "ok")
}

// Call before starting Shutdown
func (s *Server) SetUnhealthy() {
    s.healthy.Store(false)
}
```

### Shutdown Sequence with Health Check

```go
<-ctx.Done()
slog.Info("shutting down gracefully")

// 1. Mark unhealthy -- load balancer stops sending new traffic
srv.SetUnhealthy()

// 2. Wait for load balancer to detect unhealthy status
// This depends on your health check interval (typically 5-10s)
time.Sleep(5 * time.Second)

// 3. Shut down server -- drain remaining in-flight requests
shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
defer shutdownCancel()

if err := httpServer.Shutdown(shutdownCtx); err != nil {
    return fmt.Errorf("server shutdown: %w", err)
}
```

The sleep between marking unhealthy and calling Shutdown gives the load balancer time to route traffic elsewhere. Without this, new requests may arrive at a server that is already draining.

## Complete Production Template

```go
func run(ctx context.Context) error {
    cfg, err := loadConfig()
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }

    ctx, cancel := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
    defer cancel()

    db, err := sql.Open("postgres", cfg.DatabaseURL)
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close()

    if err := db.PingContext(ctx); err != nil {
        return fmt.Errorf("pinging db: %w", err)
    }

    srv := NewServer(db, slog.Default())

    httpServer := &http.Server{
        Addr:         cfg.Addr,
        Handler:      srv,
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    errCh := make(chan error, 1)
    go func() {
        slog.Info("server starting", "addr", httpServer.Addr)
        if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            errCh <- fmt.Errorf("server listen: %w", err)
        }
    }()

    // Wait for signal or server error
    select {
    case err := <-errCh:
        return err
    case <-ctx.Done():
    }

    slog.Info("shutting down gracefully")
    srv.SetUnhealthy()
    time.Sleep(cfg.HealthDrainDelay)

    shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
    defer shutdownCancel()

    if err := httpServer.Shutdown(shutdownCtx); err != nil {
        return fmt.Errorf("server shutdown: %w", err)
    }

    slog.Info("server stopped")
    return nil
}
```
