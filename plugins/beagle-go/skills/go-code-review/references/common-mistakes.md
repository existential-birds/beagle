# Common Mistakes

## Resource Leaks

### 1. Missing defer for Close

**Problem**: Resources leaked on early return.

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

**Problem**: Resources accumulate until function returns.

```go
// BAD - files stay open until loop ends
for _, path := range paths {
    f, _ := os.Open(path)
    defer f.Close()  // deferred until function returns
    process(f)
}

// GOOD - close in each iteration or use closure
for _, path := range paths {
    func() {
        f, _ := os.Open(path)
        defer f.Close()
        process(f)
    }()
}
```

### 3. HTTP Response Body Not Closed

**Problem**: Connection pool exhaustion.

```go
// BAD
resp, err := http.Get(url)
if err != nil {
    return err
}
// body never closed!
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

**Problem**: Redundant when used with package name.

```go
// BAD
package user
type UserService struct { ... }  // user.UserService

// GOOD
package user
type Service struct { ... }  // user.Service
```

### 5. Missing Doc Comments on Exports

**Problem**: godoc can't generate documentation.

```go
// BAD
func NewServer(addr string) *Server { ... }

// GOOD
// NewServer creates a new HTTP server listening on addr.
func NewServer(addr string) *Server { ... }
```

### 6. Naked Returns in Long Functions

**Problem**: Hard to track what's being returned.

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

**Problem**: Hidden side effects, hard to test.

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

**Problem**: Race conditions, hard to test.

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

## Performance

### 9. String Concatenation in Loop

**Problem**: O(n²) allocation overhead.

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

### 10. Slice Preallocation

**Problem**: Repeated reallocations.

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

## Testing

### 11. Table-Driven Tests Missing

**Problem**: Verbose, repetitive test code.

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
