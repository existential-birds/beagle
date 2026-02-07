# Go Project Structure

## Flat Structure

Best for small applications, CLIs, microservices with fewer than ~10 handlers, and projects where a single developer or small team owns the entire codebase.

```
myapp/
├── main.go
├── server.go
├── handlers.go
├── middleware.go
├── models.go
├── store.go
├── server_test.go
├── handlers_test.go
└── go.mod
```

### When to Use

- CLI tools and small utilities
- Single-purpose microservices (one bounded context)
- Prototypes and proofs of concept
- Fewer than ~10 HTTP handlers
- One or two developers working on the codebase

### Benefits

- Zero cognitive overhead for navigation -- everything is in one place
- No circular dependency issues (single package)
- Easy to refactor -- just move functions between files
- `go test ./...` covers everything in one pass
- New contributors can understand the layout immediately

### File Responsibilities

| File | Contains |
|------|----------|
| `main.go` | `func main()`, wiring, configuration loading, `run()` function |
| `server.go` | `Server` struct, `NewServer()`, `routes()`, `ServeHTTP()` |
| `handlers.go` | All HTTP handler methods on `Server` |
| `middleware.go` | Middleware functions (`requestLogger`, `authenticate`, etc.) |
| `models.go` | Domain types, request/response structs |
| `store.go` | Database access layer (queries, store struct) |

For very small apps, `server.go` and `handlers.go` can be the same file.

### Example: Flat Server

```go
// main.go
package main

import (
    "context"
    "database/sql"
    "log/slog"
    "os"
)

func main() {
    if err := run(context.Background()); err != nil {
        slog.Error("application error", "err", err)
        os.Exit(1)
    }
}

func run(ctx context.Context) error {
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close()

    srv := NewServer(db, slog.Default())
    // ... start and graceful shutdown ...
    return nil
}
```

```go
// server.go
package main

type Server struct {
    db     *sql.DB
    logger *slog.Logger
    router *http.ServeMux
}

func NewServer(db *sql.DB, logger *slog.Logger) *Server {
    s := &Server{db: db, logger: logger, router: http.NewServeMux()}
    s.routes()
    return s
}

func (s *Server) routes() {
    s.router.HandleFunc("GET /api/items", s.handleListItems)
    s.router.HandleFunc("GET /api/items/{id}", s.handleGetItem)
    s.router.HandleFunc("POST /api/items", s.handleCreateItem)
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    s.router.ServeHTTP(w, r)
}
```

---

## Modular / Domain-Driven Structure

For larger applications with multiple bounded contexts, multiple teams, or significant growth expected.

```
myapp/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── user/
│   │   ├── handler.go
│   │   ├── service.go
│   │   ├── store.go
│   │   ├── model.go
│   │   └── handler_test.go
│   ├── order/
│   │   ├── handler.go
│   │   ├── service.go
│   │   ├── store.go
│   │   ├── model.go
│   │   └── handler_test.go
│   └── platform/
│       ├── middleware/
│       │   ├── auth.go
│       │   └── logging.go
│       ├── database/
│       │   └── postgres.go
│       └── config/
│           └── config.go
├── migrations/
│   ├── 001_create_users.up.sql
│   └── 001_create_users.down.sql
├── go.mod
└── go.sum
```

### Directory Conventions

#### `cmd/`

Entry points for the application. Each subdirectory produces one binary.

```
cmd/
├── server/
│   └── main.go       # HTTP server
├── worker/
│   └── main.go       # Background job processor
└── migrate/
    └── main.go       # Database migration tool
```

Each `main.go` is the composition root: it reads config, creates dependencies, wires them together, and starts the program. Keep `main.go` small -- delegate to a `run()` function that returns an error.

#### `internal/`

The `internal/` directory is enforced by the Go toolchain. Code inside `internal/` cannot be imported by external modules. Use it for all application-specific code.

```go
// This import is only allowed from within the same module:
import "myapp/internal/user"
```

This gives you the freedom to refactor internal packages without worrying about breaking external consumers.

#### Domain Packages (`internal/user/`, `internal/order/`)

Each domain package owns its:
- **Models** -- domain types and validation
- **Store** -- database queries, implements a store interface
- **Service** -- business logic, orchestrates store calls
- **Handler** -- HTTP handlers, request parsing, response writing

```go
// internal/user/service.go
package user

type Service struct {
    store Store
}

type Store interface {
    GetByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, u *User) error
    List(ctx context.Context, limit, offset int) ([]User, error)
}

func NewService(store Store) *Service {
    return &Service{store: store}
}

func (s *Service) GetUser(ctx context.Context, id string) (*User, error) {
    if id == "" {
        return nil, fmt.Errorf("user id is required")
    }
    return s.store.GetByID(ctx, id)
}
```

#### `internal/platform/`

Shared infrastructure code that is not domain-specific:
- `middleware/` -- HTTP middleware (logging, auth, CORS)
- `database/` -- connection helpers, migration runners
- `config/` -- configuration loading and validation

Platform packages are imported by domain packages and `cmd/`, but never import domain packages.

### Package Design Principles

**Dependencies flow inward.** Domain packages should not import other domain packages. If `order` needs user data, it defines its own interface:

```go
// internal/order/service.go
package order

type UserLookup interface {
    GetByID(ctx context.Context, id string) (*User, error)
}

type Service struct {
    store      Store
    userLookup UserLookup
}
```

The `cmd/server/main.go` wires the `user.Service` (which satisfies `order.UserLookup`) into the order service.

**Avoid circular dependencies.** If package A imports package B, package B cannot import package A. This is a compile error in Go. Solutions:
1. Extract shared types into a separate package (e.g., `internal/domain`)
2. Use interfaces at the consumer side
3. Merge the packages if they are tightly coupled

**Keep packages focused.** A package named `utils` or `helpers` is a code smell. If a function doesn't belong to a domain, it belongs in `platform/` with a descriptive package name.

**Export only what is needed.** Start with unexported types and functions. Export them only when another package needs access.

### Wiring in main.go

```go
// cmd/server/main.go
package main

import (
    "myapp/internal/order"
    "myapp/internal/platform/config"
    "myapp/internal/platform/database"
    "myapp/internal/user"
)

func run(ctx context.Context) error {
    cfg, err := config.Load()
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }

    db, err := database.Open(cfg.DatabaseURL)
    if err != nil {
        return fmt.Errorf("opening db: %w", err)
    }
    defer db.Close()

    // Build dependency graph
    userStore := user.NewPostgresStore(db)
    userService := user.NewService(userStore)

    orderStore := order.NewPostgresStore(db)
    orderService := order.NewService(orderStore, userService)

    // Build server
    mux := http.NewServeMux()
    user.RegisterRoutes(mux, userService)
    order.RegisterRoutes(mux, orderService)

    // ... start HTTP server with graceful shutdown ...
    return nil
}
```

### Route Registration in Domain Packages

Each domain package provides a `RegisterRoutes` function:

```go
// internal/user/handler.go
package user

func RegisterRoutes(mux *http.ServeMux, svc *Service) {
    h := &handler{svc: svc}
    mux.HandleFunc("GET /api/users", h.list)
    mux.HandleFunc("GET /api/users/{id}", h.get)
    mux.HandleFunc("POST /api/users", h.create)
}

type handler struct {
    svc *Service
}

func (h *handler) get(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    u, err := h.svc.GetUser(r.Context(), id)
    // ...
}
```

---

## Migration Signals: Flat to Modular

Move from flat to modular when you notice:

1. **File length** -- `handlers.go` exceeds ~500 lines or contains unrelated handlers
2. **Naming collisions** -- You prefix functions like `userGetHandler`, `orderGetHandler` to avoid confusion
3. **Multiple developers** -- Merge conflicts in shared files become frequent
4. **Distinct domains** -- The application clearly has separate bounded contexts (users, orders, billing)
5. **Separate deployment needs** -- You want a CLI tool and an HTTP server from the same codebase (`cmd/server/`, `cmd/cli/`)
6. **Test isolation** -- You want to test one domain without loading all the others

### How to Migrate

1. Create `cmd/server/main.go` and move wiring code there
2. Create `internal/` and make one domain package for the most independent domain
3. Move its models, handlers, store, and tests into the new package
4. Update imports in `main.go`
5. Repeat for each domain
6. Extract shared infrastructure into `internal/platform/`

Migrate incrementally. Do not restructure everything in one commit.
