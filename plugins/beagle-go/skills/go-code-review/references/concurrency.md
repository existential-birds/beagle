# Concurrency

## Critical Anti-Patterns

### 1. Goroutine Leak

Goroutines that block forever consume memory and can accumulate over time, eventually exhausting resources.

```go
// BAD - no way to stop the goroutine
func startWorker() {
    go func() {
        for {
            doWork()
        }
    }()
}

// GOOD - context cancellation
func startWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            default:
                doWork()
            }
        }
    }()
}
```

### 2. Unbounded Channel Send

If the receiver dies or falls behind, the sender blocks forever. Always provide an escape hatch via context.

```go
// BAD - blocks if nobody reads
ch <- result

// GOOD - respect context
select {
case ch <- result:
case <-ctx.Done():
    return ctx.Err()
}
```

### 3. Closing Channel Multiple Times

Closing a closed channel panics at runtime. The rule: only the sender closes the channel, and only once.

```go
// BAD - potential double close
close(ch)
close(ch)  // panic!

// GOOD - only sender closes, once
func produce(ch chan<- int) {
    defer close(ch)
    for i := 0; i < 10; i++ {
        ch <- i
    }
}
```

### 4. Race Condition on Shared State

Concurrent reads and writes to maps, slices, or structs without synchronization cause data corruption and crashes.

```go
// BAD - concurrent map access
var cache = make(map[string]int)
func Get(key string) int {
    return cache[key]  // race!
}
func Set(key string, val int) {
    cache[key] = val  // race!
}

// GOOD - mutex protection
var (
    cache   = make(map[string]int)
    cacheMu sync.RWMutex
)
func Get(key string) int {
    cacheMu.RLock()
    defer cacheMu.RUnlock()
    return cache[key]
}
func Set(key string, val int) {
    cacheMu.Lock()
    defer cacheMu.Unlock()
    cache[key] = val
}

// ALTERNATIVE - sync.Map for simple concurrent access patterns
var cache sync.Map
func Get(key string) (int, bool) {
    v, ok := cache.Load(key)
    if !ok {
        return 0, false
    }
    return v.(int), true
}
```

### 5. Missing WaitGroup

Without synchronization, the calling function may return before spawned goroutines finish their work.

```go
// BAD - may exit before done
for _, item := range items {
    go process(item)
}
return  // goroutines may not finish

// GOOD
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()
```

### 6. Loop Variable Capture (Pre-Go 1.22)

**Go 1.22+ fixed this** — each iteration gets its own variable. Only flag in codebases with `go.mod` specifying Go < 1.22.

```go
// ISSUE in Go < 1.22 - all goroutines see the last item
for _, item := range items {
    go func() {
        process(item)  // captures loop variable
    }()
}

// FIX for Go < 1.22 - capture in closure parameter
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}

// Go 1.22+ - this is fine, each iteration has its own variable
for _, item := range items {
    go func() {
        process(item)  // safe
    }()
}
```

### 7. Context Not Propagated

When context isn't passed to downstream calls, cancellation signals don't reach them. This means timeouts and cancellation from the caller have no effect.

```go
// BAD
func Handler(ctx context.Context) error {
    result := doWork()  // ignores ctx
    return nil
}

// GOOD
func Handler(ctx context.Context) error {
    result, err := doWork(ctx)
    if err != nil {
        return err
    }
    return nil
}
```

## sync.OnceValue and sync.OnceFunc (Go 1.21+)

These replace the common `sync.Once` + package-level variable pattern with a cleaner API:

```go
// OLD PATTERN
var (
    dbOnce sync.Once
    db     *sql.DB
)
func getDB() *sql.DB {
    dbOnce.Do(func() {
        db, _ = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    })
    return db
}

// NEW PATTERN (Go 1.21+) - type-safe, no package variable
var getDB = sync.OnceValue(func() *sql.DB {
    db, _ := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    return db
})

// With error handling
var getDB = sync.OnceValues(func() (*sql.DB, error) {
    return sql.Open("postgres", os.Getenv("DATABASE_URL"))
})
```

## Worker Pool Pattern

```go
func processItems(ctx context.Context, items []Item) error {
    const workers = 5

    jobs := make(chan Item)
    errs := make(chan error, 1)

    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range jobs {
                if err := process(ctx, item); err != nil {
                    select {
                    case errs <- err:
                    default:
                    }
                    return
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(errs)
    }()

    for _, item := range items {
        select {
        case jobs <- item:
        case err := <-errs:
            return err
        case <-ctx.Done():
            return ctx.Err()
        }
    }
    close(jobs)

    return <-errs
}
```

## errgroup Pattern

The `golang.org/x/sync/errgroup` package simplifies the worker pool pattern with built-in context cancellation:

```go
func processItems(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(5)

    for _, item := range items {
        g.Go(func() error {
            return process(ctx, item)
        })
    }

    return g.Wait()
}
```

## Review Questions

1. Are all goroutines stoppable via context?
2. Are channels always closed by the sender?
3. Is shared state protected by mutex or sync types?
4. Are WaitGroups used to wait for goroutine completion?
5. Is context passed through the call chain?
6. Is loop variable capture handled correctly for the target Go version?
7. Are `sync.OnceValue`/`sync.OnceFunc` used instead of `sync.Once` + variable (Go 1.21+)?
