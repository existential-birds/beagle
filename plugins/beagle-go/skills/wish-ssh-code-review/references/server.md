# Server Setup

## Host Key Management

### 1. Use Persistent Keys

```go
// BAD - generates new key each start (fingerprint changes)
s, err := wish.NewServer(
    wish.WithAddress(":22"),
    // no host key specified - generates random
)

// GOOD - load from file
s, err := wish.NewServer(
    wish.WithAddress(":22"),
    wish.WithHostKeyPath("/data/ssh_host_ed25519_key"),
)

// GOOD - generate if missing, persist for reuse
func ensureHostKey(path string) error {
    if _, err := os.Stat(path); os.IsNotExist(err) {
        _, priv, err := ed25519.GenerateKey(rand.Reader)
        if err != nil {
            return err
        }
        // save to file...
    }
    return nil
}
```

### 2. Support Multiple Key Types

```go
s, err := wish.NewServer(
    wish.WithAddress(":22"),
    wish.WithHostKeyPath("/data/ssh_host_ed25519_key"),
    wish.WithHostKeyPEM(rsaKeyBytes),  // additional key type
)
```

## Middleware Configuration

### 1. Correct Middleware Order

```go
// Middleware executes in order - first added runs first
wish.WithMiddleware(
    // 1. Logging - see all connections
    logging.Middleware(),

    // 2. Timeout - prevent hung connections
    wish.WithIdleTimeout(10*time.Minute),
    wish.WithMaxTimeout(30*time.Minute),

    // 3. Active terminal - handle PTY/window sizing
    activeterm.Middleware(),

    // 4. Your app handler - BubbleTea or custom
    bubbletea.Middleware(teaHandler),
)
```

### 2. Custom Middleware

```go
func customMiddleware() wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            // Before handling
            log.Info("connection", "user", s.User(), "remote", s.RemoteAddr())

            // Call next handler
            next(s)

            // After handling (session ended)
            log.Info("disconnected", "user", s.User())
        }
    }
}
```

### 3. Metrics Middleware

```go
func metricsMiddleware(metrics *Metrics) wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            metrics.ActiveConnections.Inc()
            start := time.Now()

            defer func() {
                metrics.ActiveConnections.Dec()
                metrics.SessionDuration.Observe(time.Since(start).Seconds())
            }()

            next(s)
        }
    }
}
```

## Server Lifecycle

### 1. Graceful Shutdown

```go
func run() error {
    s, err := wish.NewServer(...)
    if err != nil {
        return err
    }

    // Start server in goroutine
    errCh := make(chan error, 1)
    go func() {
        errCh <- s.ListenAndServe()
    }()

    // Wait for shutdown signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

    select {
    case err := <-errCh:
        return err
    case <-quit:
    }

    // Graceful shutdown with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    return s.Shutdown(ctx)
}
```

### 2. Health Checks

```go
// Run HTTP health endpoint alongside SSH
http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("ok"))
})

go http.ListenAndServe(":8080", nil)
```

## Connection Handling

### 1. Connection Limits

```go
// Limit concurrent connections
var connLimiter = make(chan struct{}, 100)

func connectionLimitMiddleware() wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            select {
            case connLimiter <- struct{}{}:
                defer func() { <-connLimiter }()
                next(s)
            default:
                s.Exit(1)
            }
        }
    }
}
```

### 2. Rate Limiting

```go
import "golang.org/x/time/rate"

var limiter = rate.NewLimiter(rate.Every(time.Second), 10)  // 10/sec

func rateLimitMiddleware() wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            if !limiter.Allow() {
                io.WriteString(s, "Too many connections, try again later\n")
                s.Exit(1)
                return
            }
            next(s)
        }
    }
}
```

## Anti-Patterns

### 1. No Error Handling on ListenAndServe

```go
// BAD
go s.ListenAndServe()

// GOOD
go func() {
    if err := s.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
        log.Fatal("server error", "error", err)
    }
}()
```

### 2. Ignoring Context in Shutdown

```go
// BAD - no timeout
s.Shutdown(context.Background())  // could hang forever

// GOOD
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
s.Shutdown(ctx)
```

## Review Questions

1. Are host keys persisted (not regenerated on restart)?
2. Is middleware order correct (logging first)?
3. Is graceful shutdown implemented with timeout?
4. Are connection/rate limits in place?
5. Is there a health check endpoint?
