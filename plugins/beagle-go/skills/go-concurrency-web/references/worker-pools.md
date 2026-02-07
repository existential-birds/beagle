# Worker Pools

## Why Worker Pools

Worker pools prevent goroutine leaks and OOM by bounding concurrency. Without a pool, every incoming request that spawns a goroutine can create unbounded parallelism:

- 10,000 requests/second = 10,000 goroutines = ~20 MB minimum (stacks start at ~2 KB, grow as needed)
- Each goroutine may hold open database connections, file descriptors, or network sockets
- The Go scheduler slows down with millions of goroutines

A worker pool with N workers guarantees at most N concurrent background tasks, regardless of request volume.

## Sizing Workers

### CPU-Bound Tasks

For tasks that primarily consume CPU (compression, hashing, image processing):

- **Workers = `runtime.NumCPU()`** or slightly more
- More workers than CPUs adds context-switching overhead with no throughput gain

### I/O-Bound Tasks

For tasks that wait on external services (HTTP calls, database queries, email sending):

- **Workers = 10x to 100x the number of CPUs** is common
- The bottleneck is the external service, not CPU
- Tune based on the external service's capacity and latency

### General Guidance

```go
// CPU-bound: match CPU count
pool := NewWorkerPool(runtime.NumCPU(), 1000, logger)

// I/O-bound: more workers, they spend most time waiting
pool := NewWorkerPool(50, 5000, logger)
```

## Queue Sizing and Backpressure

The buffered channel acts as a queue. Its size determines backpressure behavior:

```go
// Small queue = fast backpressure signal
jobs: make(chan Job, 10)

// Large queue = absorbs bursts but uses more memory
jobs: make(chan Job, 10000)
```

### Handling a Full Queue

When the queue is full, `Submit` blocks. For HTTP handlers, blocking is usually unacceptable. Use a non-blocking submit:

```go
func (wp *WorkerPool) TrySubmit(job Job) bool {
    select {
    case wp.jobs <- job:
        return true
    default:
        wp.logger.Warn("worker pool full, dropping job", "job_id", job.ID)
        return false
    }
}

// In handler
func (s *Server) handleWebhook(w http.ResponseWriter, r *http.Request) {
    webhook := decodeWebhook(r)
    if !s.workers.TrySubmit(Job{
        ID:      "webhook-" + webhook.ID,
        Execute: func(ctx context.Context) error {
            return s.processWebhook(ctx, webhook)
        },
    }) {
        http.Error(w, "server busy, try again later", http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusAccepted)
}
```

## Graceful Shutdown Integration

Worker pools must integrate with your server's shutdown sequence. Process in-flight jobs before exiting:

```go
func main() {
    logger := slog.Default()
    pool := NewWorkerPool(10, 1000, logger)

    srv := &http.Server{
        Addr:    ":8080",
        Handler: newRouter(pool),
    }

    // Start server
    go func() {
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            logger.Error("server error", "err", err)
        }
    }()

    // Wait for interrupt
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("shutting down server...")

    // 1. Stop accepting new requests
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    srv.Shutdown(ctx)

    // 2. Drain the worker pool (finish in-flight jobs)
    logger.Info("draining worker pool...")
    pool.Shutdown()

    logger.Info("shutdown complete")
}
```

## Error Handling and Retry Patterns

### Logging Errors

At minimum, log all job failures:

```go
func (wp *WorkerPool) worker(id int) {
    defer wp.wg.Done()
    for job := range wp.jobs {
        start := time.Now()
        if err := job.Execute(context.Background()); err != nil {
            wp.logger.Error("job failed",
                "worker", id,
                "job_id", job.ID,
                "duration", time.Since(start),
                "err", err,
            )
        } else {
            wp.logger.Info("job completed",
                "worker", id,
                "job_id", job.ID,
                "duration", time.Since(start),
            )
        }
    }
}
```

### Retry with Backoff

For transient failures, wrap jobs with retry logic:

```go
type RetryJob struct {
    Job
    MaxRetries int
    Backoff    time.Duration
}

func (wp *WorkerPool) workerWithRetry(id int) {
    defer wp.wg.Done()
    for job := range wp.jobs {
        retryJob, hasRetry := job.(RetryJob) // type assertion if using interface
        maxRetries := 1
        backoff := time.Second

        if hasRetry {
            maxRetries = retryJob.MaxRetries
            backoff = retryJob.Backoff
        }

        var lastErr error
        for attempt := 0; attempt < maxRetries; attempt++ {
            if attempt > 0 {
                time.Sleep(backoff * time.Duration(attempt))
            }
            if err := job.Execute(context.Background()); err != nil {
                lastErr = err
                wp.logger.Warn("job attempt failed",
                    "worker", id,
                    "job_id", job.ID,
                    "attempt", attempt+1,
                    "err", err,
                )
                continue
            }
            lastErr = nil
            break
        }

        if lastErr != nil {
            wp.logger.Error("job exhausted retries",
                "worker", id,
                "job_id", job.ID,
                "err", lastErr,
            )
        }
    }
}
```

## Context Propagation

Workers should use their own context, not the request context. The request context is cancelled when the HTTP response is sent, which happens before the background job runs:

```go
// BAD — request context cancels when response is written
s.workers.Submit(Job{
    ID: "send-email",
    Execute: func(ctx context.Context) error {
        return s.email.Send(r.Context(), user) // r.Context() is already cancelled!
    },
})

// GOOD — use background context with timeout
s.workers.Submit(Job{
    ID: "send-email",
    Execute: func(ctx context.Context) error {
        ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
        defer cancel()
        return s.email.Send(ctx, user)
    },
})
```

If you need to pass values from the request context (like trace IDs), extract them before submitting:

```go
traceID := traceIDFromContext(r.Context())
userID := userIDFromContext(r.Context())

s.workers.Submit(Job{
    ID: "audit-log-" + userID,
    Execute: func(ctx context.Context) error {
        ctx = withTraceID(ctx, traceID)
        return s.audit.Log(ctx, userID, action)
    },
})
```

## errgroup as a Simpler Alternative

For fan-out/fan-in within a single request (parallel API calls, batch processing), `golang.org/x/sync/errgroup` is simpler than a worker pool:

```go
// errgroup for bounded parallel work
func (s *Server) handleBatchProcess(w http.ResponseWriter, r *http.Request) {
    items := decodeItems(r)

    g, ctx := errgroup.WithContext(r.Context())
    g.SetLimit(10) // max 10 concurrent goroutines

    results := make([]*Result, len(items))
    for i, item := range items {
        i, item := i, item
        g.Go(func() error {
            result, err := s.processItem(ctx, item)
            if err != nil {
                return fmt.Errorf("processing item %d: %w", i, err)
            }
            results[i] = result
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        handleError(w, r, err)
        return
    }

    writeJSON(w, http.StatusOK, results)
}
```

### When to Use errgroup vs Worker Pool

| Scenario | Use |
|----------|-----|
| Parallel work within a single request | `errgroup` |
| Background tasks that outlive the request | Worker pool |
| Fan-out to multiple APIs then combine results | `errgroup` |
| Fire-and-forget tasks (emails, webhooks) | Worker pool |
| Batch processing an upload | `errgroup` |
| Long-running async processing | Worker pool |

### errgroup Key Points

- `g.SetLimit(n)` bounds concurrency (available since Go 1.20)
- Context cancellation propagates automatically — if one goroutine returns an error, the context is cancelled for all others
- `g.Wait()` blocks until all goroutines complete and returns the first error
- Safe to write to `results[i]` from goroutine `i` without a mutex because each goroutine writes to a distinct index
