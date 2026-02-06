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

## Review Questions

1. Are test files colocated with source files?
2. Do test names describe the scenario?
3. Are helper functions marked with t.Helper()?
4. Are parallel tests properly isolated?
5. Are fixtures in testdata directory?
