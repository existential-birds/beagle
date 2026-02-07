# Test Structure

## File Organization

### 1. Test File Location

```
package/
├── user.go
├── user_test.go       # same package tests
├── user_internal_test.go  # internal tests if needed
└── testdata/          # test fixtures
    └── users.json
```

### 2. Test Naming Convention

```go
// Function test
func TestFunctionName(t *testing.T) {}

// Method test
func TestTypeName_MethodName(t *testing.T) {}

// Scenario test
func TestGetUser_WhenNotFound_ReturnsError(t *testing.T) {}
```

## Test Patterns

### 1. Setup and Teardown

```go
func TestMain(m *testing.M) {
    // Global setup
    setup()

    code := m.Run()

    // Global teardown
    teardown()
    os.Exit(code)
}

// Per-test setup
func TestFoo(t *testing.T) {
    db := setupTestDB(t)
    t.Cleanup(func() {
        db.Close()
    })
}
```

### 2. Helper Functions

```go
// Mark as helper for better stack traces
func assertNoError(t *testing.T, err error) {
    t.Helper()  // marks this as helper
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}

func createTestUser(t *testing.T, name string) *User {
    t.Helper()
    u, err := NewUser(name)
    if err != nil {
        t.Fatalf("creating test user: %v", err)
    }
    return u
}
```

### 3. Testdata Directory

```go
func TestParseConfig(t *testing.T) {
    // Load from testdata directory
    data, err := os.ReadFile("testdata/config.json")
    if err != nil {
        t.Fatal(err)
    }

    cfg, err := ParseConfig(data)
    // ...
}
```

## Table-Driven Tests

### 1. Basic Structure

```go
func TestParse(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {
            name:  "valid number",
            input: "42",
            want:  42,
        },
        {
            name:    "invalid input",
            input:   "abc",
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Parse(tt.input)

            if tt.wantErr {
                if err == nil {
                    t.Error("expected error, got nil")
                }
                return
            }

            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }

            if got != tt.want {
                t.Errorf("Parse(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

### 2. With Setup Function

```go
func TestHandler(t *testing.T) {
    tests := []struct {
        name       string
        setup      func() *Handler
        input      Request
        wantStatus int
    }{
        {
            name: "authorized user",
            setup: func() *Handler {
                return NewHandler(WithAuth(true))
            },
            input:      Request{UserID: 1},
            wantStatus: 200,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            h := tt.setup()
            resp := h.Handle(tt.input)
            if resp.Status != tt.wantStatus {
                t.Errorf("status = %d, want %d", resp.Status, tt.wantStatus)
            }
        })
    }
}
```

### 3. With Assertions

```go
func TestProcess(t *testing.T) {
    tests := []struct {
        name   string
        input  []int
        check  func(t *testing.T, result []int)
    }{
        {
            name:  "preserves order",
            input: []int{3, 1, 2},
            check: func(t *testing.T, result []int) {
                if !slices.Equal(result, []int{1, 2, 3}) {
                    t.Errorf("got %v, want sorted", result)
                }
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Process(tt.input)
            tt.check(t, result)
        })
    }
}
```

## Parallel Testing

### 1. Top-Level Parallel

```go
func TestFoo(t *testing.T) {
    t.Parallel()  // this test runs in parallel with others

    // test code
}
```

### 2. Subtests Parallel

```go
func TestAll(t *testing.T) {
    tests := []struct{...}

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()  // subtests run in parallel
            // test code using tt
        })
    }
}
```

### 3. Avoiding Race Conditions

```go
// Before Go 1.22, capture loop variable
for _, tt := range tests {
    tt := tt  // capture!
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()
        // use tt safely
    })
}

// Go 1.22+: not needed, loop variable is per-iteration
```

## Error Assertions

### 1. Using errors.Is

```go
func TestGetUser_NotFound(t *testing.T) {
    _, err := GetUser(999)

    if !errors.Is(err, ErrNotFound) {
        t.Errorf("got %v, want ErrNotFound", err)
    }
}
```

### 2. Using errors.As

```go
func TestValidate(t *testing.T) {
    err := Validate(invalidInput)

    var validErr *ValidationError
    if !errors.As(err, &validErr) {
        t.Fatalf("expected ValidationError, got %T", err)
    }

    if validErr.Field != "email" {
        t.Errorf("field = %s, want email", validErr.Field)
    }
}
```

## Benchmarks and Fuzzing

### Benchmark File Organization

Benchmarks can live in the same `*_test.go` file as unit tests, or in a dedicated `*_bench_test.go` file for large suites:

```text
package/
├── parser.go
├── parser_test.go         # unit tests
├── parser_bench_test.go   # benchmarks (optional, for large suites)
└── testdata/
    └── corpus/            # fuzz seed corpus
```

### Benchmark Naming

```go
// Function benchmark
func BenchmarkFunctionName(b *testing.B) {}

// Method benchmark
func BenchmarkTypeName_Method(b *testing.B) {}
```

### Sub-Benchmarks for Input Sizes

```go
func BenchmarkProcess(b *testing.B) {
    sizes := []int{10, 100, 1000, 10000}

    for _, size := range sizes {
        b.Run(fmt.Sprintf("size=%d", size), func(b *testing.B) {
            data := generateTestData(size)
            b.ResetTimer()

            for i := 0; i < b.N; i++ {
                Process(data)
            }
        })
    }
}
```

### Fuzz Test Seed Corpus

Place seed corpus files in `testdata/fuzz/<FuzzTestName>/`:

```text
package/
└── testdata/
    └── fuzz/
        └── FuzzParseInput/
            ├── seed1       # each file contains one corpus entry
            └── seed2
```

Go will also auto-generate corpus entries in `$GOCACHE/fuzz/` during fuzzing runs.

### Running Benchmarks in CI

```bash
# Run all benchmarks with memory stats
go test -bench=. -benchmem ./...

# Compare benchmarks across commits (using benchstat)
go test -bench=. -benchmem -count=5 ./... > old.txt
# make changes
go test -bench=. -benchmem -count=5 ./... > new.txt
benchstat old.txt new.txt
```

## Golden Files

### testdata Directory for Golden Files

Store expected outputs as golden files in the `testdata/` directory:

```text
package/
├── render.go
├── render_test.go
└── testdata/
    ├── TestRender/simple.golden
    ├── TestRender/complex.golden
    └── TestRender/empty.golden
```

### The `-update` Flag Pattern

```go
var update = flag.Bool("update", false, "update golden files")

func TestRender(t *testing.T) {
    got := Render(input)
    golden := filepath.Join("testdata", t.Name()+".golden")

    if *update {
        if err := os.MkdirAll(filepath.Dir(golden), 0755); err != nil {
            t.Fatalf("creating golden dir: %v", err)
        }
        if err := os.WriteFile(golden, got, 0644); err != nil {
            t.Fatalf("writing golden file: %v", err)
        }
    }

    want, err := os.ReadFile(golden)
    if err != nil {
        t.Fatalf("reading golden file: %v (run with -update to create)", err)
    }
    if !bytes.Equal(got, want) {
        t.Errorf("output mismatch:\ngot:\n%s\nwant:\n%s", got, want)
    }
}
```

Run `go test -update ./...` to regenerate golden files after intentional changes.

### When to Use Golden Files

- **Complex output**: Rendered templates, formatted text, serialized data
- **Serialization formats**: JSON, YAML, protobuf text format
- **Code generation**: Generated source files, SQL migrations
- **Snapshot testing**: CLI output, error messages, log formatting

Golden files are preferable to inline expected values when output is large, multi-line, or changes infrequently.

## Review Questions

1. Are test files colocated with source files?
2. Do test names describe the scenario?
3. Are helper functions marked with t.Helper()?
4. Are parallel tests properly isolated?
5. Are fixtures in testdata directory?
