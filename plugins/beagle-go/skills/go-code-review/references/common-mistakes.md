# Common Mistakes

## Resource Leaks

### 1. Missing defer for Close

Resources leaked on early return. The `defer` should come immediately after the error check for the open/create call.

```go
// BAD
func readFile(path string) ([]byte, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    data, err := io.ReadAll(f)
    if err != nil {
        return nil, err  // file never closed!
    }
    f.Close()
    return data, nil
}

// GOOD - defer immediately
func readFile(path string) ([]byte, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer f.Close()
    return io.ReadAll(f)
}
```

### 2. Defer in Loop

`defer` runs at function exit, not loop iteration exit. In a loop, resources accumulate until the function returns.

```go
// BAD - files stay open until function returns
for _, path := range paths {
    f, _ := os.Open(path)
    defer f.Close()
    process(f)
}

// GOOD - wrap in closure for per-iteration cleanup
for _, path := range paths {
    func() {
        f, _ := os.Open(path)
        defer f.Close()
        process(f)
    }()
}
```

### 3. HTTP Response Body Not Closed

Every `http.Client` call that returns a non-nil response has a body that must be closed, even if you don't read it. Failing to close it leaks the underlying TCP connection.

```go
// BAD
resp, err := http.Get(url)
if err != nil {
    return err
}
data, _ := io.ReadAll(resp.Body)

// GOOD
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
data, _ := io.ReadAll(resp.Body)
```

## Naming and Style

### 4. Stuttering Names

Package names are part of the identifier at the call site. Repeating the package name in the type or function name creates redundancy.

```go
// BAD
package user
type UserService struct { ... }  // user.UserService

// GOOD
package user
type Service struct { ... }  // user.Service
```

### 5. Missing Doc Comments on Exports

Exported names without doc comments can't be documented by `godoc`/`pkgsite`. The comment should start with the name being documented.

```go
// BAD
func NewServer(addr string) *Server { ... }

// GOOD
// NewServer creates a new HTTP server listening on addr.
func NewServer(addr string) *Server { ... }
```

### 6. Naked Returns in Long Functions

Named returns are convenient in short functions, but in longer functions they obscure what's being returned. The threshold is roughly 5 lines — beyond that, be explicit.

```go
// BAD
func process(data []byte) (result string, err error) {
    // 50 lines of code...
    return  // what's being returned?
}

// GOOD - explicit returns
func process(data []byte) (string, error) {
    // 50 lines of code...
    return processedString, nil
}
```

## Initialization

### 7. Init Function Overuse

`init()` functions run before `main()`, create hidden dependencies, make testing harder, and can cause subtle ordering issues when multiple packages have init functions.

```go
// BAD - global state via init
var db *sql.DB

func init() {
    var err error
    db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal(err)
    }
}

// GOOD - explicit initialization
type App struct {
    db *sql.DB
}

func NewApp(dbURL string) (*App, error) {
    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        return nil, fmt.Errorf("opening db: %w", err)
    }
    return &App{db: db}, nil
}
```

### 8. Global Mutable State

Package-level mutable variables create race conditions in concurrent code and make testing unreliable because tests share state.

```go
// BAD
var config Config

func GetConfig() Config {
    return config
}

// GOOD - dependency injection
type Server struct {
    config Config
}

func NewServer(cfg Config) *Server {
    return &Server{config: cfg}
}
```

## Structured Logging (Go 1.21+)

### 9. Using `log` Instead of `slog`

The `log/slog` package (Go 1.21+) provides structured, leveled logging that's far more useful in production than unstructured `log.Println` output.

```go
// OLD - unstructured, hard to parse
log.Printf("failed to load user %d: %v", userID, err)

// MODERN - structured, machine-parseable
slog.Error("failed to load user",
    "user_id", userID,
    "error", err,
)

// With logger groups and attributes
logger := slog.With("service", "auth")
logger.Info("user logged in",
    "user_id", userID,
    "ip", req.RemoteAddr,
)
```

Key `slog` patterns:
- Use `slog.With()` to add common attributes to a logger
- Pass `*slog.Logger` as a dependency, don't use the global default in libraries
- Implement `slog.LogValuer` for custom types that appear frequently in logs
- Use `slog.Group()` to namespace related attributes

## Performance

### 10. String Concatenation in Loop

String concatenation with `+` in a loop creates a new string allocation on every iteration, resulting in O(n^2) memory usage.

```go
// BAD
var result string
for _, s := range items {
    result += s + ", "
}

// GOOD
var b strings.Builder
for _, s := range items {
    b.WriteString(s)
    b.WriteString(", ")
}
result := b.String()
```

### 11. Slice Preallocation

When you know the final size, preallocate to avoid repeated backing array copies as the slice grows.

```go
// BAD - grows dynamically
var results []Result
for _, item := range items {
    results = append(results, process(item))
}

// GOOD - preallocate known size
results := make([]Result, 0, len(items))
for _, item := range items {
    results = append(results, process(item))
}
```

### 12. Range Over Integer (Go 1.22+)

Go 1.22 added `range` over integers, replacing the classic C-style for loop for simple counting:

```go
// OLD
for i := 0; i < n; i++ {
    process(i)
}

// MODERN (Go 1.22+)
for i := range n {
    process(i)
}
```

## Sync and Performance

### 13. sync.Pool Misuse

Objects returned to a `sync.Pool` must be reset first, otherwise the next consumer gets stale data.

```go
// BAD - not resetting before Put
buf := bufPool.Get().(*bytes.Buffer)
buf.WriteString("data")
bufPool.Put(buf)  // still has "data"!

// GOOD - reset before returning to pool
buf := bufPool.Get().(*bytes.Buffer)
defer func() {
    buf.Reset()
    bufPool.Put(buf)
}()
buf.WriteString("data")
```

### 14. Functional Options

Constructors with many parameters are hard to read and painful to extend. The functional options pattern provides a clean API with sensible defaults.

```go
// BAD - parameter bloat
func NewServer(addr string, timeout time.Duration, logger *slog.Logger, maxConns int) *Server

// GOOD - functional options
type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{addr: addr, timeout: 30 * time.Second}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

## Testing

### 15. Table-Driven Tests Missing

Table-driven tests reduce repetition and make it easy to add new cases.

```go
// BAD
func TestAdd(t *testing.T) {
    if Add(1, 2) != 3 {
        t.Error("1+2 should be 3")
    }
    if Add(0, 0) != 0 {
        t.Error("0+0 should be 0")
    }
}

// GOOD
func TestAdd(t *testing.T) {
    tests := []struct {
        a, b, want int
    }{
        {1, 2, 3},
        {0, 0, 0},
        {-1, 1, 0},
    }
    for _, tt := range tests {
        got := Add(tt.a, tt.b)
        if got != tt.want {
            t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
        }
    }
}
```

## Review Questions

1. Is `defer Close()` called immediately after opening resources?
2. Are HTTP response bodies always closed?
3. Are package-level names not stuttering with package name?
4. Do exported symbols have doc comments?
5. Is mutable global state avoided?
6. Are slices preallocated when size is known?
7. Is `slog` used instead of `log` for structured output (Go 1.21+)?
