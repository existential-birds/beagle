# Concurrency

## Critical Anti-Patterns

### 1. Goroutine Leak

**Problem**: Goroutines block forever, consuming memory.

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

**Problem**: Sender blocks forever if receiver dies.

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

**Problem**: Panic at runtime.

```go
// BAD - potential double close
close(ch)
close(ch)  // panic!

// GOOD - only sender closes, once
func produce(ch chan<- int) {
    defer close(ch)  // close happens exactly once
    for i := 0; i < 10; i++ {
        ch <- i
    }
}
```

### 4. Race Condition on Shared State

**Problem**: Data corruption, undefined behavior.

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

// BETTER - sync.Map for simple cases
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

**Problem**: Program exits before goroutines complete.

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

### 6. Loop Variable Capture

**Problem**: All goroutines see the same variable value.

```go
// BAD (pre-Go 1.22)
for _, item := range items {
    go func() {
        process(item)  // all see last item!
    }()
}

// GOOD - capture in closure
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}

// Note: Go 1.22+ fixes this by default
```

### 7. Context Not Propagated

**Problem**: Can't cancel downstream operations.

```go
// BAD
func Handler(ctx context.Context) error {
    result := doWork()  // ignores ctx
    return nil
}

// GOOD
func Handler(ctx context.Context) error {
    result, err := doWork(ctx)  // passes ctx
    if err != nil {
        return err
    }
    return nil
}
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

## Review Questions

1. Are all goroutines stoppable via context?
2. Are channels always closed by the sender?
3. Is shared state protected by mutex or sync types?
4. Are WaitGroups used to wait for goroutine completion?
5. Is context passed through the call chain?
