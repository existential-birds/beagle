# Mocking

## Interface-Based Mocking

### 1. Define Interface in Consumer

```go
// service.go
type UserStore interface {
    Get(id int) (*User, error)
}

type UserService struct {
    store UserStore
}

func (s *UserService) GetUser(id int) (*User, error) {
    return s.store.Get(id)
}
```

### 2. Create Mock in Test File

```go
// service_test.go
type mockUserStore struct {
    users map[int]*User
    err   error
}

func (m *mockUserStore) Get(id int) (*User, error) {
    if m.err != nil {
        return nil, m.err
    }
    user, ok := m.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return user, nil
}

func TestGetUser(t *testing.T) {
    mock := &mockUserStore{
        users: map[int]*User{
            1: {ID: 1, Name: "Alice"},
        },
    }

    svc := &UserService{store: mock}
    user, err := svc.GetUser(1)

    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Name != "Alice" {
        t.Errorf("name = %s, want Alice", user.Name)
    }
}
```

### 3. Functional Mock Pattern

```go
// More flexible for varying behavior per test
type mockUserStore struct {
    getFn func(id int) (*User, error)
}

func (m *mockUserStore) Get(id int) (*User, error) {
    return m.getFn(id)
}

func TestGetUser_Error(t *testing.T) {
    mock := &mockUserStore{
        getFn: func(id int) (*User, error) {
            return nil, errors.New("db error")
        },
    }

    svc := &UserService{store: mock}
    _, err := svc.GetUser(1)

    if err == nil {
        t.Error("expected error, got nil")
    }
}
```

## Testing HTTP Clients

### 1. httptest Server

```go
func TestFetchUser(t *testing.T) {
    // Create test server
    ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path != "/users/1" {
            t.Errorf("unexpected path: %s", r.URL.Path)
        }
        w.Header().Set("Content-Type", "application/json")
        w.Write([]byte(`{"id": 1, "name": "Alice"}`))
    }))
    defer ts.Close()

    // Use test server URL
    client := NewClient(ts.URL)
    user, err := client.FetchUser(1)

    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Name != "Alice" {
        t.Errorf("name = %s, want Alice", user.Name)
    }
}
```

### 2. RoundTripper Mock

```go
type mockTransport struct {
    response *http.Response
    err      error
}

func (m *mockTransport) RoundTrip(*http.Request) (*http.Response, error) {
    return m.response, m.err
}

func TestClient_Error(t *testing.T) {
    client := &http.Client{
        Transport: &mockTransport{
            err: errors.New("network error"),
        },
    }

    _, err := FetchData(client, "http://example.com")
    if err == nil {
        t.Error("expected error")
    }
}
```

## Testing Time

### 1. Inject Time Function

```go
// Code
type Service struct {
    now func() time.Time
}

func (s *Service) IsExpired(expiry time.Time) bool {
    return s.now().After(expiry)
}

// Test
func TestIsExpired(t *testing.T) {
    fixedTime := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)
    svc := &Service{
        now: func() time.Time { return fixedTime },
    }

    tests := []struct {
        name   string
        expiry time.Time
        want   bool
    }{
        {"past", fixedTime.Add(-time.Hour), true},
        {"future", fixedTime.Add(time.Hour), false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := svc.IsExpired(tt.expiry)
            if got != tt.want {
                t.Errorf("IsExpired() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

## Testing Filesystem

### 1. fstest.MapFS

```go
import "testing/fstest"

func TestReadConfig(t *testing.T) {
    fs := fstest.MapFS{
        "config.json": &fstest.MapFile{
            Data: []byte(`{"key": "value"}`),
        },
    }

    cfg, err := ReadConfig(fs, "config.json")
    if err != nil {
        t.Fatal(err)
    }
    if cfg.Key != "value" {
        t.Errorf("key = %s, want value", cfg.Key)
    }
}
```

### 2. T.TempDir

```go
func TestWriteFile(t *testing.T) {
    dir := t.TempDir()  // automatically cleaned up
    path := filepath.Join(dir, "test.txt")

    err := WriteFile(path, "content")
    if err != nil {
        t.Fatal(err)
    }

    data, _ := os.ReadFile(path)
    if string(data) != "content" {
        t.Errorf("got %q, want content", data)
    }
}
```

## Verifying Calls

### 1. Call Recording

```go
type mockStore struct {
    getCalls []int
}

func (m *mockStore) Get(id int) (*User, error) {
    m.getCalls = append(m.getCalls, id)
    return &User{ID: id}, nil
}

func TestBatchGet(t *testing.T) {
    mock := &mockStore{}
    svc := &Service{store: mock}

    svc.BatchGet([]int{1, 2, 3})

    if len(mock.getCalls) != 3 {
        t.Errorf("Get called %d times, want 3", len(mock.getCalls))
    }
    if !slices.Equal(mock.getCalls, []int{1, 2, 3}) {
        t.Errorf("Get called with %v, want [1,2,3]", mock.getCalls)
    }
}
```

## Anti-Patterns

### 1. Over-Mocking

```go
// BAD - mocking everything
func TestAdd(t *testing.T) {
    mockCalc := &mockCalculator{}
    // just test the actual function!
}

// GOOD - only mock external dependencies
func TestService(t *testing.T) {
    mockDB := &mockDB{}  // external dependency
    svc := NewService(mockDB)
    // test service logic
}
```

### 2. Mocking Concrete Types

```go
// BAD - can't inject mock
type Service struct {
    store *PostgresStore
}

// GOOD - interface allows mocking
type Service struct {
    store Store  // interface
}
```

## Review Questions

1. Are interfaces defined by consumers, not producers?
2. Are mocks minimal (only implement what's tested)?
3. Are test servers used for HTTP testing?
4. Is time injected for time-dependent tests?
5. Are call recordings used to verify interactions?
