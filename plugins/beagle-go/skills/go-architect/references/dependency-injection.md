# Dependency Injection in Go

Go does not need a DI framework. The language's interfaces, structs, and constructor functions provide everything necessary for clean dependency injection.

## Server Struct as Dependency Container

The Server struct holds all shared dependencies and exposes HTTP handlers as methods. This is the simplest form of DI in Go.

```go
type Server struct {
    users  *user.Service
    orders *order.Service
    logger *slog.Logger
    router *http.ServeMux
}

func NewServer(users *user.Service, orders *order.Service, logger *slog.Logger) *Server {
    s := &Server{
        users:  users,
        orders: orders,
        logger: logger,
        router: http.NewServeMux(),
    }
    s.routes()
    return s
}
```

Dependencies are explicit: you can see exactly what the server needs by looking at its struct fields and constructor signature.

## Constructor Functions

Every component provides a `New*` constructor that accepts its dependencies and returns a ready-to-use instance.

```go
// user/store.go
func NewPostgresStore(db *sql.DB) *PostgresStore {
    return &PostgresStore{db: db}
}

// user/service.go
func NewService(store Store) *Service {
    return &Service{store: store}
}
```

Constructors should:
- Accept only what the component actually uses
- Return a concrete type (not an interface)
- Not perform I/O (no database pings, no HTTP calls)
- Panic only if the dependency is nil and the component cannot function without it

```go
func NewService(store Store) *Service {
    if store == nil {
        panic("user: store is required")
    }
    return &Service{store: store}
}
```

## Layered Dependency Injection

`main.go` (or the `run()` function) is the composition root. It creates all dependencies in order and wires them together. No other part of the application creates its own dependencies.

```go
// cmd/server/main.go
func run(ctx context.Context) error {
    cfg, err := config.Load()
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }

    // Layer 1: Infrastructure
    db, err := sql.Open("postgres", cfg.DatabaseURL)
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close()

    // Layer 2: Stores (depend on infrastructure)
    userStore := user.NewPostgresStore(db)
    orderStore := order.NewPostgresStore(db)

    // Layer 3: Services (depend on stores)
    userService := user.NewService(userStore)
    orderService := order.NewService(orderStore, userService)

    // Layer 4: HTTP server (depends on services)
    srv := NewServer(userService, orderService, slog.Default())

    // ... start server ...
    return nil
}
```

The dependency graph is a tree built from bottom (infrastructure) to top (HTTP layer). Each layer only knows about the layer directly below it.

## Interface-Based Dependencies for Testability

Define interfaces at the consumer, not the producer. Keep them small.

```go
// user/service.go
package user

// Store is defined where it is used, not where it is implemented
type Store interface {
    GetByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, u *User) error
    List(ctx context.Context, limit, offset int) ([]User, error)
}

type Service struct {
    store Store
}

func NewService(store Store) *Service {
    return &Service{store: store}
}
```

The concrete implementation lives in a separate file or package:

```go
// user/postgres_store.go
package user

type PostgresStore struct {
    db *sql.DB
}

func NewPostgresStore(db *sql.DB) *PostgresStore {
    return &PostgresStore{db: db}
}

func (s *PostgresStore) GetByID(ctx context.Context, id string) (*User, error) {
    row := s.db.QueryRowContext(ctx, "SELECT id, name, email FROM users WHERE id = $1", id)
    var u User
    if err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return &u, nil
}

// ... other Store methods ...
```

### Testing with Mock Implementations

```go
// user/service_test.go
package user

type mockStore struct {
    users map[string]*User
}

func (m *mockStore) GetByID(ctx context.Context, id string) (*User, error) {
    u, ok := m.users[id]
    if !ok {
        return nil, fmt.Errorf("user not found: %s", id)
    }
    return u, nil
}

func (m *mockStore) Create(ctx context.Context, u *User) error {
    m.users[u.ID] = u
    return nil
}

func (m *mockStore) List(ctx context.Context, limit, offset int) ([]User, error) {
    var result []User
    for _, u := range m.users {
        result = append(result, *u)
    }
    return result, nil
}

func TestGetUser(t *testing.T) {
    store := &mockStore{
        users: map[string]*User{
            "1": {ID: "1", Name: "Alice", Email: "alice@example.com"},
        },
    }
    svc := NewService(store)

    u, err := svc.GetUser(context.Background(), "1")
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if u.Name != "Alice" {
        t.Errorf("got name %q, want %q", u.Name, "Alice")
    }
}
```

No mocking library needed. Go interfaces make manual test doubles straightforward.

## Configuration as a Dependency

Business logic should never read environment variables or config files directly. Configuration is loaded once in `main.go` and passed as explicit values to constructors.

```go
// config/config.go
package config

type Config struct {
    DatabaseURL    string        `env:"DATABASE_URL,required"`
    Addr           string        `env:"ADDR" default:":8080"`
    ShutdownTimeout time.Duration `env:"SHUTDOWN_TIMEOUT" default:"10s"`
    SendGrid       SendGridConfig
}

type SendGridConfig struct {
    APIKey  string `env:"SENDGRID_API_KEY,required"`
    FromAddr string `env:"SENDGRID_FROM" default:"noreply@example.com"`
}
```

Pass only what each component needs, not the entire config:

```go
// GOOD -- emailer gets only its own config
emailer := email.NewSendGridEmailer(cfg.SendGrid.APIKey, cfg.SendGrid.FromAddr)

// BAD -- emailer receives entire application config
emailer := email.NewSendGridEmailer(cfg)
```

This keeps components decoupled from the config structure and makes their requirements visible.

## Functional Options for Optional Dependencies

When a constructor has many optional parameters, use the functional options pattern:

```go
type Server struct {
    db      *sql.DB
    logger  *slog.Logger
    cache   Cache
    metrics MetricsRecorder
}

type Option func(*Server)

func WithCache(c Cache) Option {
    return func(s *Server) {
        s.cache = c
    }
}

func WithMetrics(m MetricsRecorder) Option {
    return func(s *Server) {
        s.metrics = m
    }
}

func NewServer(db *sql.DB, logger *slog.Logger, opts ...Option) *Server {
    s := &Server{
        db:      db,
        logger:  logger,
        cache:   noopCache{},    // sensible default
        metrics: noopMetrics{},  // sensible default
    }
    for _, opt := range opts {
        opt(s)
    }
    s.routes()
    return s
}
```

Usage:

```go
// Minimal -- uses defaults for cache and metrics
srv := NewServer(db, logger)

// With optional dependencies
srv := NewServer(db, logger,
    WithCache(redisCache),
    WithMetrics(promMetrics),
)
```

Use functional options when:
- There are more than 3-4 optional parameters
- You want sensible defaults that can be overridden
- The constructor signature is growing unwieldy

Do not use functional options for required dependencies. Those belong as regular constructor parameters.

## Cross-Domain Dependencies

When one domain needs data from another, define an interface in the consuming package:

```go
// internal/order/service.go
package order

// UserLookup is what the order domain needs from the user domain
type UserLookup interface {
    GetByID(ctx context.Context, id string) (*UserInfo, error)
}

// UserInfo contains only what orders need -- not the full user model
type UserInfo struct {
    ID    string
    Name  string
    Email string
}

type Service struct {
    store      Store
    userLookup UserLookup
}

func NewService(store Store, userLookup UserLookup) *Service {
    return &Service{store: store, userLookup: userLookup}
}
```

The user service satisfies this interface without knowing about it:

```go
// cmd/server/main.go
orderService := order.NewService(orderStore, userService) // userService satisfies order.UserLookup
```

This keeps domains decoupled. The order package never imports the user package.

## Anti-Patterns

### Global Database Variable

```go
// BAD
package db

var DB *sql.DB

func init() {
    var err error
    DB, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal(err)
    }
}
```

Problems:
- Impossible to test with a different database
- Hidden dependency -- callers don't declare they need a DB
- `init()` runs at import time, before `main()`, making startup order unpredictable
- `log.Fatal` in `init()` prevents graceful error handling

Fix: Pass `*sql.DB` through constructors.

### Reading Environment Variables in Handlers

```go
// BAD
func (s *Server) handleSendEmail(w http.ResponseWriter, r *http.Request) {
    apiKey := os.Getenv("SENDGRID_API_KEY")
    client := sendgrid.NewClient(apiKey)
    // ...
}
```

Problems:
- Creates a new client on every request
- Cannot test without setting env vars
- Handler does infrastructure work

Fix: Inject a pre-configured email client through the Server struct.

```go
// GOOD
type Server struct {
    emailer EmailSender
}

func (s *Server) handleSendEmail(w http.ResponseWriter, r *http.Request) {
    err := s.emailer.Send(r.Context(), to, subject, body)
    // ...
}
```

### Passing Entire Config Struct

```go
// BAD -- emailer knows about database config, server port, etc.
func NewEmailer(cfg *config.Config) *Emailer {
    return &Emailer{apiKey: cfg.SendGrid.APIKey}
}
```

Problems:
- Component knows about the entire configuration shape
- Cannot tell what the emailer actually needs without reading its code
- Refactoring config structure breaks unrelated components

Fix: Pass individual values or a small, focused config struct.

```go
// GOOD
func NewEmailer(apiKey string, fromAddr string) *Emailer {
    return &Emailer{apiKey: apiKey, fromAddr: fromAddr}
}
```

### Using init() for Dependency Setup

```go
// BAD
var userService *UserService

func init() {
    db := connectDB()
    store := NewPostgresStore(db)
    userService = NewService(store)
}
```

Problems:
- Runs before `main()`, no error handling
- Global state, untestable
- Invisible side effects at import time
- Order of `init()` across packages is hard to reason about

Fix: Build the dependency graph explicitly in `main.go` or `run()`.
