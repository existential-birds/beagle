# Race Detection

## Running the Race Detector

The Go race detector instruments memory accesses at compile time and detects concurrent unsynchronized access at runtime.

```bash
# Run tests with race detection
go test -race ./...

# Build a binary with race detection (for integration testing)
go build -race -o myserver ./cmd/server

# Run a specific test with race detection
go test -race -run TestHandlerConcurrency ./internal/server/
```

**Always run `-race` in CI.** Race conditions are intermittent; the race detector increases the chance of catching them.

## What the Race Detector Catches

The race detector detects **data races**: two goroutines access the same memory location concurrently, and at least one access is a write.

It catches:
- Concurrent map reads and writes
- Concurrent struct field modifications
- Concurrent slice access
- Concurrent variable increments

It does **not** catch:
- **Logical races (TOCTOU)** — checking a condition and acting on it non-atomically
- **Deadlocks** — goroutines waiting on each other forever
- **Starvation** — a goroutine never gets scheduled
- **Race conditions that don't execute** — it only detects races that actually occur during the test run

## Common Race Conditions in Web Handlers

### Race 1: Shared Map Without Lock

```go
// BAD — concurrent map write causes panic
var cache = map[string]string{}

func handler(w http.ResponseWriter, r *http.Request) {
    cache[r.URL.Path] = "value" // concurrent map write!
}

// Fix: use sync.Map or mutex
var cache sync.Map

func handler(w http.ResponseWriter, r *http.Request) {
    cache.Store(r.URL.Path, "value") // safe
}
```

Note: Concurrent map writes in Go cause a runtime panic, not just incorrect data.

### Race 2: Incrementing a Counter

```go
// BAD — data race on counter
var count int

func handler(w http.ResponseWriter, r *http.Request) {
    count++ // data race!
}

// Fix: use atomic
var count atomic.Int64

func handler(w http.ResponseWriter, r *http.Request) {
    count.Add(1) // safe
}
```

### Race 3: Slice Append

```go
// BAD — concurrent append is not safe
type Server struct {
    events []Event
}

func (s *Server) handleEvent(w http.ResponseWriter, r *http.Request) {
    event := decodeEvent(r)
    s.events = append(s.events, event) // data race!
}

// Fix: protect with mutex
type Server struct {
    mu     sync.Mutex
    events []Event
}

func (s *Server) handleEvent(w http.ResponseWriter, r *http.Request) {
    event := decodeEvent(r)
    s.mu.Lock()
    s.events = append(s.events, event)
    s.mu.Unlock()
}
```

### Race 4: Lazy Initialization

```go
// BAD — multiple goroutines may initialize simultaneously
type Server struct {
    client *http.Client
}

func (s *Server) getClient() *http.Client {
    if s.client == nil {        // race: read
        s.client = &http.Client{  // race: write
            Timeout: 10 * time.Second,
        }
    }
    return s.client
}

// Fix: use sync.Once
type Server struct {
    clientOnce sync.Once
    client     *http.Client
}

func (s *Server) getClient() *http.Client {
    s.clientOnce.Do(func() {
        s.client = &http.Client{
            Timeout: 10 * time.Second,
        }
    })
    return s.client
}
```

### Race 5: Read-Modify-Write on Struct Field

```go
// BAD — read and write are separate operations
type Server struct {
    healthy bool
}

func (s *Server) healthCheck(w http.ResponseWriter, r *http.Request) {
    if s.healthy {  // race: read
        writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
    }
}

func (s *Server) setHealthy(healthy bool) {
    s.healthy = healthy  // race: write
}

// Fix: use atomic.Bool
type Server struct {
    healthy atomic.Bool
}

func (s *Server) healthCheck(w http.ResponseWriter, r *http.Request) {
    if s.healthy.Load() {
        writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
    }
}

func (s *Server) setHealthy(healthy bool) {
    s.healthy.Store(healthy)
}
```

## Fixing Races: When to Use What

| Scenario | Use | Why |
|----------|-----|-----|
| Simple counter | `sync/atomic` (`atomic.Int64`) | Lock-free, minimal overhead |
| Boolean flag | `sync/atomic` (`atomic.Bool`) | Lock-free, minimal overhead |
| Read-heavy cache | `sync.RWMutex` | Multiple concurrent readers, exclusive writers |
| Write-heavy map | `sync.Mutex` | Simple exclusive access |
| Cross-goroutine communication | Channels | Idiomatic Go, naturally synchronizes |
| One-time initialization | `sync.Once` | Guaranteed single execution |
| Concurrent-safe map (simple keys) | `sync.Map` | Built-in safety, good for append-only or key-stable maps |

### sync.Mutex vs sync.RWMutex

Use `sync.RWMutex` when reads significantly outnumber writes:

```go
type Cache struct {
    mu   sync.RWMutex
    data map[string]*Entry
}

// Multiple goroutines can read concurrently
func (c *Cache) Get(key string) (*Entry, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    entry, ok := c.data[key]
    return entry, ok
}

// Only one goroutine can write at a time
func (c *Cache) Set(key string, entry *Entry) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.data[key] = entry
}
```

If reads and writes are roughly equal, use `sync.Mutex` (simpler, less overhead from lock upgrades).

### sync.Map vs Mutex-Protected Map

`sync.Map` is optimized for two patterns:
1. Write-once, read-many (append-only maps)
2. Multiple goroutines read/write disjoint key sets

For everything else, a mutex-protected `map` is usually faster and provides type safety.

## Testing for Race Conditions

### Write Concurrent Tests

```go
func TestHandlerConcurrency(t *testing.T) {
    srv := NewServer()
    ts := httptest.NewServer(srv)
    defer ts.Close()

    // Hammer the endpoint from multiple goroutines
    var wg sync.WaitGroup
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            resp, err := http.Get(ts.URL + "/api/data")
            if err != nil {
                t.Errorf("request failed: %v", err)
                return
            }
            resp.Body.Close()
        }()
    }
    wg.Wait()
}
```

### Test Specific Race Scenarios

```go
func TestCacheRace(t *testing.T) {
    cache := NewCache()

    var wg sync.WaitGroup

    // Concurrent writes
    for i := 0; i < 50; i++ {
        wg.Add(1)
        go func(i int) {
            defer wg.Done()
            cache.Set(fmt.Sprintf("key-%d", i), &Entry{Value: i})
        }(i)
    }

    // Concurrent reads
    for i := 0; i < 50; i++ {
        wg.Add(1)
        go func(i int) {
            defer wg.Done()
            cache.Get(fmt.Sprintf("key-%d", i))
        }(i)
    }

    wg.Wait()
}
```

## CI Integration

### GitHub Actions

```yaml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Test with race detector
        run: go test -race -count=1 ./...

      - name: Build with race detector (integration)
        run: go build -race -o ./bin/server ./cmd/server
```

### Key Flags

- `-race` enables the race detector
- `-count=1` disables test caching (ensures fresh run for race detection)
- The race detector adds ~2-10x runtime overhead and ~5-10x memory overhead
- Acceptable for CI and testing; do **not** ship race-enabled binaries to production

### Race Detector Environment Variables

```bash
# Customize race detector behavior
GORACE="log_path=/tmp/race.log" go test -race ./...

# Halt on first race (useful in CI)
GORACE="halt_on_error=1" go test -race ./...

# Increase history size for complex programs
GORACE="history_size=7" go test -race ./...
```
