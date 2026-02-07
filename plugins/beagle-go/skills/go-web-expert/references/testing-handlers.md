# Testing Go HTTP Handlers

## httptest Fundamentals

Every handler test follows the same three-step pattern: build a request, record the response, assert on the result.

### Basic Pattern

```go
func TestServer_handleHealth(t *testing.T) {
    srv := NewServer(nil, slog.Default())

    req := httptest.NewRequest("GET", "/healthz", nil)
    w := httptest.NewRecorder()

    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
    }
}
```

### httptest.NewRequest vs http.NewRequest

```go
// httptest.NewRequest -- panics on error, never returns one.
// Use in tests where a bad URL is a programming error.
req := httptest.NewRequest("GET", "/api/users/123", nil)

// http.NewRequest -- returns an error. Use when constructing
// from dynamic test data that could be invalid.
req, err := http.NewRequest("POST", "/api/users", body)
if err != nil {
    t.Fatal(err)
}
```

### httptest.NewRecorder

`httptest.NewRecorder` returns a `*httptest.ResponseRecorder` that implements `http.ResponseWriter` and captures everything the handler writes.

```go
w := httptest.NewRecorder()
srv.ServeHTTP(w, req)

w.Code                    // status code (int)
w.Body.String()           // response body as string
w.Body.Bytes()            // response body as []byte
w.Header().Get("Content-Type") // response headers
w.Result()                // *http.Response for more detailed inspection
```

---

## Testing with Real JSON Payloads

### POST with JSON Body

```go
func TestServer_handleCreateUser(t *testing.T) {
    mockStore := &MockUserStore{
        CreateFunc: func(ctx context.Context, u *User) error {
            u.ID = "generated-id"
            return nil
        },
    }
    srv := NewServer(mockStore, slog.Default())

    body := strings.NewReader(`{"name":"Alice","email":"alice@example.com"}`)
    req := httptest.NewRequest("POST", "/api/users", body)
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    srv.ServeHTTP(w, req)

    if w.Code != http.StatusCreated {
        t.Fatalf("status = %d, want %d; body = %s", w.Code, http.StatusCreated, w.Body.String())
    }

    var resp User
    if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
        t.Fatalf("decoding response: %v", err)
    }
    if resp.ID == "" {
        t.Error("expected non-empty user ID")
    }
    if resp.Name != "Alice" {
        t.Errorf("name = %q, want %q", resp.Name, "Alice")
    }
}
```

### Testing Validation Errors

```go
func TestServer_handleCreateUser_validation(t *testing.T) {
    srv := NewServer(&MockUserStore{}, slog.Default())

    tests := []struct {
        name       string
        body       string
        wantStatus int
        wantErr    string
    }{
        {
            name:       "missing name",
            body:       `{"email":"alice@example.com"}`,
            wantStatus: 422,
            wantErr:    "name",
        },
        {
            name:       "invalid email",
            body:       `{"name":"Alice","email":"not-an-email"}`,
            wantStatus: 422,
            wantErr:    "email",
        },
        {
            name:       "malformed JSON",
            body:       `{bad json`,
            wantStatus: 400,
            wantErr:    "invalid JSON",
        },
        {
            name:       "empty body",
            body:       ``,
            wantStatus: 400,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := httptest.NewRequest("POST", "/api/users", strings.NewReader(tt.body))
            req.Header.Set("Content-Type", "application/json")
            w := httptest.NewRecorder()

            srv.ServeHTTP(w, req)

            if w.Code != tt.wantStatus {
                t.Errorf("status = %d, want %d; body = %s", w.Code, tt.wantStatus, w.Body.String())
            }
            if tt.wantErr != "" && !strings.Contains(w.Body.String(), tt.wantErr) {
                t.Errorf("body = %q, want to contain %q", w.Body.String(), tt.wantErr)
            }
        })
    }
}
```

### Decoding JSON Responses with a Helper

```go
func decodeJSON[T any](t *testing.T, w *httptest.ResponseRecorder) T {
    t.Helper()
    var result T
    if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
        t.Fatalf("decoding response body: %v", err)
    }
    return result
}

// Usage
resp := decodeJSON[User](t, w)
if resp.Name != "Alice" {
    t.Errorf("name = %q, want %q", resp.Name, "Alice")
}
```

---

## Testing Middleware Chains

### Testing a Single Middleware

Test middleware in isolation by wrapping a known inner handler:

```go
func TestRequestIDMiddleware(t *testing.T) {
    // Inner handler that captures the request ID from context
    var gotID string
    inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        gotID = RequestIDFromContext(r.Context())
        w.WriteHeader(http.StatusOK)
    })

    handler := RequestID(inner)

    t.Run("generates ID when missing", func(t *testing.T) {
        req := httptest.NewRequest("GET", "/", nil)
        w := httptest.NewRecorder()

        handler.ServeHTTP(w, req)

        if gotID == "" {
            t.Error("expected non-empty request ID in context")
        }
        if w.Header().Get("X-Request-ID") == "" {
            t.Error("expected X-Request-ID response header")
        }
    })

    t.Run("preserves existing ID", func(t *testing.T) {
        req := httptest.NewRequest("GET", "/", nil)
        req.Header.Set("X-Request-ID", "test-id-123")
        w := httptest.NewRecorder()

        handler.ServeHTTP(w, req)

        if gotID != "test-id-123" {
            t.Errorf("request ID = %q, want %q", gotID, "test-id-123")
        }
    })
}
```

### Testing the Full Middleware Stack

Test through the complete stack to verify middleware ordering and interaction:

```go
func TestMiddlewareChain(t *testing.T) {
    mockStore := &MockUserStore{
        GetUserFunc: func(ctx context.Context, id string) (*User, error) {
            return &User{ID: id, Name: "Alice"}, nil
        },
    }
    srv := NewServer(mockStore, slog.Default())

    // Apply the same middleware stack as production
    handler := Chain(srv, Recovery, RequestID, Logger(slog.Default()))

    req := httptest.NewRequest("GET", "/api/users/123", nil)
    w := httptest.NewRecorder()

    handler.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
    }
    if w.Header().Get("X-Request-ID") == "" {
        t.Error("middleware chain did not set X-Request-ID")
    }
}
```

### Testing Recovery Middleware

```go
func TestRecoveryMiddleware(t *testing.T) {
    panicking := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        panic("something went wrong")
    })

    handler := Recovery(panicking)

    req := httptest.NewRequest("GET", "/", nil)
    w := httptest.NewRecorder()

    // Should not panic
    handler.ServeHTTP(w, req)

    if w.Code != http.StatusInternalServerError {
        t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
    }
}
```

---

## Testing Authentication and Authorization

### Testing Auth Middleware

```go
func TestAuthMiddleware(t *testing.T) {
    inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        user, ok := UserFromContext(r.Context())
        if !ok {
            t.Fatal("expected user in context")
        }
        fmt.Fprintf(w, "hello %s", user.Name)
    })

    tokenValidator := &MockTokenValidator{
        ValidateFunc: func(token string) (*User, error) {
            if token == "Bearer valid-token" {
                return &User{ID: "1", Name: "Alice", Roles: []string{"admin"}}, nil
            }
            return nil, errors.New("invalid token")
        },
    }

    handler := AuthMiddleware(tokenValidator)(inner)

    tests := []struct {
        name       string
        authHeader string
        wantStatus int
        wantBody   string
    }{
        {
            name:       "valid token",
            authHeader: "Bearer valid-token",
            wantStatus: http.StatusOK,
            wantBody:   "hello Alice",
        },
        {
            name:       "invalid token",
            authHeader: "Bearer bad-token",
            wantStatus: http.StatusUnauthorized,
        },
        {
            name:       "missing header",
            authHeader: "",
            wantStatus: http.StatusUnauthorized,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := httptest.NewRequest("GET", "/", nil)
            if tt.authHeader != "" {
                req.Header.Set("Authorization", tt.authHeader)
            }
            w := httptest.NewRecorder()

            handler.ServeHTTP(w, req)

            if w.Code != tt.wantStatus {
                t.Errorf("status = %d, want %d", w.Code, tt.wantStatus)
            }
            if tt.wantBody != "" && !strings.Contains(w.Body.String(), tt.wantBody) {
                t.Errorf("body = %q, want to contain %q", w.Body.String(), tt.wantBody)
            }
        })
    }
}
```

### Testing Role-Based Authorization

```go
func TestRequireRole(t *testing.T) {
    inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    })

    handler := RequireRole("admin")(inner)

    tests := []struct {
        name       string
        user       *User
        wantStatus int
    }{
        {
            name:       "admin user",
            user:       &User{Roles: []string{"admin"}},
            wantStatus: http.StatusOK,
        },
        {
            name:       "regular user",
            user:       &User{Roles: []string{"user"}},
            wantStatus: http.StatusForbidden,
        },
        {
            name:       "no user in context",
            user:       nil,
            wantStatus: http.StatusUnauthorized,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := httptest.NewRequest("GET", "/admin", nil)
            if tt.user != nil {
                ctx := context.WithValue(req.Context(), userKey, tt.user)
                req = req.WithContext(ctx)
            }
            w := httptest.NewRecorder()

            handler.ServeHTTP(w, req)

            if w.Code != tt.wantStatus {
                t.Errorf("status = %d, want %d", w.Code, tt.wantStatus)
            }
        })
    }
}
```

---

## Integration Tests with Real Database

### Pattern: Test Database with t.Cleanup

```go
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()

    dsn := os.Getenv("TEST_DATABASE_URL")
    if dsn == "" {
        t.Skip("TEST_DATABASE_URL not set")
    }

    db, err := sql.Open("postgres", dsn)
    if err != nil {
        t.Fatalf("opening test database: %v", err)
    }

    t.Cleanup(func() {
        db.Close()
    })

    return db
}
```

### Transaction Rollback for Test Isolation

Each test runs in a transaction that is rolled back, leaving the database unchanged:

```go
func setupTestTx(t *testing.T, db *sql.DB) *sql.Tx {
    t.Helper()

    tx, err := db.Begin()
    if err != nil {
        t.Fatalf("beginning transaction: %v", err)
    }

    t.Cleanup(func() {
        tx.Rollback() // always rollback -- test data never persists
    })

    return tx
}
```

### Full Integration Test

```go
func TestUserStore_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    db := setupTestDB(t)
    tx := setupTestTx(t, db)
    store := NewUserStore(tx)

    t.Run("create and retrieve", func(t *testing.T) {
        user := &User{Name: "Alice", Email: "alice@example.com"}
        err := store.Create(context.Background(), user)
        if err != nil {
            t.Fatalf("creating user: %v", err)
        }
        if user.ID == "" {
            t.Fatal("expected non-empty ID after create")
        }

        got, err := store.GetByID(context.Background(), user.ID)
        if err != nil {
            t.Fatalf("getting user: %v", err)
        }
        if got.Name != "Alice" {
            t.Errorf("name = %q, want %q", got.Name, "Alice")
        }
    })

    t.Run("duplicate email", func(t *testing.T) {
        user1 := &User{Name: "Bob", Email: "bob@example.com"}
        if err := store.Create(context.Background(), user1); err != nil {
            t.Fatalf("creating first user: %v", err)
        }

        user2 := &User{Name: "Bob2", Email: "bob@example.com"}
        err := store.Create(context.Background(), user2)
        if !errors.Is(err, ErrDuplicateEmail) {
            t.Errorf("err = %v, want ErrDuplicateEmail", err)
        }
    })
}
```

### HTTP Integration Test

Test the full HTTP stack against a real database:

```go
func TestServer_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    db := setupTestDB(t)
    tx := setupTestTx(t, db)
    store := NewUserStore(tx)
    srv := NewServer(store, slog.Default())

    // Create
    body := strings.NewReader(`{"name":"Alice","email":"alice@test.com"}`)
    req := httptest.NewRequest("POST", "/api/users", body)
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusCreated {
        t.Fatalf("create: status = %d, want %d; body = %s", w.Code, http.StatusCreated, w.Body.String())
    }

    var created User
    json.NewDecoder(w.Body).Decode(&created)

    // Retrieve
    req = httptest.NewRequest("GET", "/api/users/"+created.ID, nil)
    w = httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("get: status = %d, want %d", w.Code, http.StatusOK)
    }

    var fetched User
    json.NewDecoder(w.Body).Decode(&fetched)
    if fetched.Name != "Alice" {
        t.Errorf("name = %q, want %q", fetched.Name, "Alice")
    }
}
```

---

## Testing File Uploads

### Multipart Form Data

```go
func TestServer_handleUpload(t *testing.T) {
    srv := NewServer(&MockFileStore{}, slog.Default())

    // Build multipart body
    var buf bytes.Buffer
    writer := multipart.NewWriter(&buf)

    part, err := writer.CreateFormFile("file", "test.txt")
    if err != nil {
        t.Fatal(err)
    }
    part.Write([]byte("hello world"))

    // Add a form field alongside the file
    writer.WriteField("description", "test file upload")
    writer.Close()

    req := httptest.NewRequest("POST", "/api/upload", &buf)
    req.Header.Set("Content-Type", writer.FormDataContentType())
    w := httptest.NewRecorder()

    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want %d; body = %s", w.Code, http.StatusOK, w.Body.String())
    }
}
```

### Testing File Size Limits

```go
func TestServer_handleUpload_tooLarge(t *testing.T) {
    srv := NewServer(&MockFileStore{}, slog.Default())

    // Create a file that exceeds the size limit
    var buf bytes.Buffer
    writer := multipart.NewWriter(&buf)
    part, _ := writer.CreateFormFile("file", "large.bin")
    part.Write(make([]byte, 11<<20)) // 11MB, exceeding a 10MB limit
    writer.Close()

    req := httptest.NewRequest("POST", "/api/upload", &buf)
    req.Header.Set("Content-Type", writer.FormDataContentType())
    w := httptest.NewRecorder()

    srv.ServeHTTP(w, req)

    if w.Code != http.StatusRequestEntityTooLarge {
        t.Errorf("status = %d, want %d", w.Code, http.StatusRequestEntityTooLarge)
    }
}
```

---

## Testing Streaming Responses

### Server-Sent Events

```go
func TestServer_handleSSE(t *testing.T) {
    events := make(chan string, 3)
    events <- "event 1"
    events <- "event 2"
    events <- "event 3"
    close(events)

    srv := NewServer(&MockEventSource{Events: events}, slog.Default())

    req := httptest.NewRequest("GET", "/api/events", nil)
    w := httptest.NewRecorder()

    srv.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("status = %d, want %d", w.Code, http.StatusOK)
    }

    contentType := w.Header().Get("Content-Type")
    if contentType != "text/event-stream" {
        t.Errorf("Content-Type = %q, want %q", contentType, "text/event-stream")
    }

    body := w.Body.String()
    for _, want := range []string{"event 1", "event 2", "event 3"} {
        if !strings.Contains(body, want) {
            t.Errorf("body missing %q", want)
        }
    }
}
```

### Testing with httptest.Server for Long-Lived Connections

For testing streaming with actual HTTP connections (e.g., when `httptest.NewRecorder` is insufficient because the handler flushes):

```go
func TestServer_handleSSE_live(t *testing.T) {
    events := make(chan string, 3)
    events <- "event 1"
    events <- "event 2"
    events <- "event 3"
    close(events)

    srv := NewServer(&MockEventSource{Events: events}, slog.Default())
    ts := httptest.NewServer(srv)
    defer ts.Close()

    resp, err := http.Get(ts.URL + "/api/events")
    if err != nil {
        t.Fatalf("GET /api/events: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
    }

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        t.Fatalf("reading body: %v", err)
    }

    for _, want := range []string{"event 1", "event 2", "event 3"} {
        if !strings.Contains(string(body), want) {
            t.Errorf("body missing %q", want)
        }
    }
}
```

---

## Test Fixtures in testdata/

Go's testing toolchain ignores directories named `testdata`. Use it to store JSON fixtures, SQL seed files, and golden files.

### Directory Structure

```
mypackage/
  handler.go
  handler_test.go
  testdata/
    create_user_valid.json
    create_user_invalid.json
    golden/
      user_response.json
    sql/
      seed_users.sql
```

### Loading Fixtures

```go
func loadFixture(t *testing.T, path string) []byte {
    t.Helper()
    data, err := os.ReadFile(filepath.Join("testdata", path))
    if err != nil {
        t.Fatalf("loading fixture %s: %v", path, err)
    }
    return data
}

func TestServer_handleCreateUser_fromFixture(t *testing.T) {
    srv := NewServer(&MockUserStore{
        CreateFunc: func(ctx context.Context, u *User) error {
            u.ID = "test-id"
            return nil
        },
    }, slog.Default())

    body := loadFixture(t, "create_user_valid.json")
    req := httptest.NewRequest("POST", "/api/users", bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    srv.ServeHTTP(w, req)

    if w.Code != http.StatusCreated {
        t.Fatalf("status = %d, want %d; body = %s", w.Code, http.StatusCreated, w.Body.String())
    }
}
```

### Golden File Testing

Compare handler output against a stored golden file. Update golden files with `-update` flag.

```go
var update = flag.Bool("update", false, "update golden files")

func TestServer_handleGetUser_golden(t *testing.T) {
    srv := NewServer(&MockUserStore{
        GetUserFunc: func(ctx context.Context, id string) (*User, error) {
            return &User{ID: "123", Name: "Alice", Email: "alice@example.com"}, nil
        },
    }, slog.Default())

    req := httptest.NewRequest("GET", "/api/users/123", nil)
    w := httptest.NewRecorder()
    srv.ServeHTTP(w, req)

    goldenPath := filepath.Join("testdata", "golden", "user_response.json")

    if *update {
        // Pretty-print for readable golden files
        var pretty bytes.Buffer
        json.Indent(&pretty, w.Body.Bytes(), "", "  ")
        if err := os.WriteFile(goldenPath, pretty.Bytes(), 0644); err != nil {
            t.Fatalf("writing golden file: %v", err)
        }
        return
    }

    want, err := os.ReadFile(goldenPath)
    if err != nil {
        t.Fatalf("reading golden file: %v (run with -update to create)", err)
    }

    // Normalize both for comparison
    var gotPretty, wantPretty bytes.Buffer
    json.Indent(&gotPretty, w.Body.Bytes(), "", "  ")
    json.Indent(&wantPretty, want, "", "  ")

    if gotPretty.String() != wantPretty.String() {
        t.Errorf("response does not match golden file.\ngot:\n%s\nwant:\n%s",
            gotPretty.String(), wantPretty.String())
    }
}
```

---

## Interface-Based Mocking Pattern

Define narrow interfaces at the consumer and create mock implementations for tests.

### Define the Interface

```go
// In the handler/server package -- not in the store package
type UserStore interface {
    GetUser(ctx context.Context, id string) (*User, error)
    CreateUser(ctx context.Context, u *User) error
    ListUsers(ctx context.Context, limit, offset int) ([]*User, error)
}
```

### Create the Mock

```go
type MockUserStore struct {
    GetUserFunc    func(ctx context.Context, id string) (*User, error)
    CreateUserFunc func(ctx context.Context, u *User) error
    ListUsersFunc  func(ctx context.Context, limit, offset int) ([]*User, error)
}

func (m *MockUserStore) GetUser(ctx context.Context, id string) (*User, error) {
    return m.GetUserFunc(ctx, id)
}

func (m *MockUserStore) CreateUser(ctx context.Context, u *User) error {
    return m.CreateUserFunc(ctx, u)
}

func (m *MockUserStore) ListUsers(ctx context.Context, limit, offset int) ([]*User, error) {
    return m.ListUsersFunc(ctx, limit, offset)
}
```

### Use in Tests

```go
store := &MockUserStore{
    GetUserFunc: func(ctx context.Context, id string) (*User, error) {
        if id == "123" {
            return &User{ID: "123", Name: "Alice"}, nil
        }
        return nil, ErrNotFound
    },
    // CreateUserFunc and ListUsersFunc will panic if called --
    // this is intentional. If a test triggers an unexpected call,
    // you want to know.
}

srv := NewServer(store, slog.Default())
```

---

## Testing Anti-Patterns

### Calling handler methods directly

```go
// BAD: bypasses routing, middleware, and ServeHTTP
srv.handleGetUser(w, req)

// GOOD: test through the full HTTP stack
srv.ServeHTTP(w, req)
```

### Shared mutable test state

```go
// BAD: tests interfere with each other
var testDB *sql.DB

func TestA(t *testing.T) { /* uses testDB */ }
func TestB(t *testing.T) { /* uses testDB, fails if TestA runs first */ }

// GOOD: each test creates its own dependencies
func TestA(t *testing.T) {
    store := &MockUserStore{...}
    srv := NewServer(store, slog.Default())
    // ...
}
```

### Not testing error responses

```go
// BAD: only tests the happy path
func TestCreateUser(t *testing.T) {
    // ... only tests 201 Created
}

// GOOD: tests all outcomes
func TestCreateUser(t *testing.T) {
    tests := []struct{...}{
        {"valid", ..., 201, ""},
        {"missing name", ..., 422, "name"},
        {"duplicate email", ..., 409, "email already exists"},
        {"store error", ..., 500, "internal server error"},
    }
}
```

### Asserting on exact JSON strings

```go
// BAD: brittle -- breaks if field order changes or whitespace differs
if w.Body.String() != `{"id":"123","name":"Alice"}` {

// GOOD: decode and compare structs or check individual fields
var resp User
json.NewDecoder(w.Body).Decode(&resp)
if resp.Name != "Alice" {
```
