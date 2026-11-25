# Interfaces and Types

## Critical Anti-Patterns

### 1. Premature Interface Definition

Interfaces should be defined where they're consumed, not where the implementation lives. Defining them in the producer package couples the abstraction to a specific implementation.

```go
// BAD - interface in producer package
package storage

type UserRepository interface {
    Get(id int) (*User, error)
    Save(user *User) error
}

type PostgresUserRepository struct { ... }

// GOOD - interface in consumer package
package service

type UserGetter interface {
    Get(id int) (*User, error)
}

func NewUserService(users UserGetter) *UserService {
    return &UserService{users: users}
}
```

### 2. Interface Pollution (Too Many Methods)

Fat interfaces are hard to implement, hard to mock, and force consumers to depend on methods they don't use.

```go
// BAD - fat interface
type UserStore interface {
    Get(id int) (*User, error)
    GetAll() ([]*User, error)
    Save(user *User) error
    Delete(id int) error
    Search(query string) ([]*User, error)
    Count() (int, error)
}

// GOOD - focused interfaces composed as needed
type UserGetter interface {
    Get(id int) (*User, error)
}

type UserSaver interface {
    Save(user *User) error
}

type UserStore interface {
    UserGetter
    UserSaver
}
```

### 3. Wrong Interface Names

Go convention: single-method interfaces are named after the method with an `-er` suffix.

```go
// BAD
type IUserService interface { ... }  // Java-style prefix
type UserServiceInterface { ... }    // redundant suffix
type UserManager interface { ... }   // vague noun

// GOOD - verb forms ending in -er
type UserReader interface {
    ReadUser(id int) (*User, error)
}

type UserWriter interface {
    WriteUser(user *User) error
}
```

### 4. Returning Interface Instead of Concrete Type

Returning interfaces from constructors hides information from callers and prevents them from accessing implementation-specific methods. Accept interfaces, return structs.

```go
// BAD - returns interface
func NewServer(addr string) Server {
    return &httpServer{addr: addr}
}

// GOOD - returns concrete type
func NewServer(addr string) *HTTPServer {
    return &HTTPServer{addr: addr}
}
```

### 5. Interface for Single Implementation

An interface with only one implementation adds indirection without benefit. Introduce interfaces when you actually need them (testing, multiple implementations, package boundary decoupling).

```go
// BAD - interface with only one implementation and no tests mocking it
type ConfigLoader interface {
    Load() (*Config, error)
}

type fileConfigLoader struct { ... }

// GOOD - just use the concrete type until you need the abstraction
type ConfigLoader struct { ... }

func (c *ConfigLoader) Load() (*Config, error) { ... }
```

## Generics (Go 1.18+)

### Prefer `any` over `interface{}`

The `any` keyword is an alias for `interface{}` introduced in Go 1.18. It's clearer and more idiomatic in modern Go code.

```go
// OLD
func Process(data interface{}) interface{} { ... }

// MODERN
func Process(data any) any { ... }
```

### Use Type Constraints Instead of `any`

When you know the set of types you need, use constraints to preserve type safety. `any` in a generic function means you've given up type checking.

```go
// BAD - any constraint means no useful operations
func Max[T any](a, b T) T {
    // Can't compare a and b!
}

// GOOD - constrained to comparable and ordered types
func Max[T cmp.Ordered](a, b T) T {
    if a > b {
        return a
    }
    return b
}
```

### Common Generic Anti-Patterns

```go
// BAD - generic function that only works with one type
func ParseUserID[T ~string](s T) (int, error) {
    return strconv.Atoi(string(s))
}
// Just use string directly

// BAD - over-genericized struct
type Cache[K comparable, V any] struct { ... }
// Only used as Cache[string, *User] throughout the codebase
// Generics add value when there are multiple instantiations

// GOOD - generics for truly reusable code
func Map[T, U any](slice []T, fn func(T) U) []U {
    result := make([]U, len(slice))
    for i, v := range slice {
        result[i] = fn(v)
    }
    return result
}
```

### Type Constraints with `~` (Underlying Types)

The `~` prefix matches types with the same underlying type, which is important for custom types:

```go
type UserID int64

// Without ~: only accepts int64, not UserID
func Format[T int64](id T) string { ... }

// With ~: accepts int64 AND UserID
func Format[T ~int64](id T) string { ... }
```

## Accept Interfaces, Return Structs

```go
// Function accepts interface (flexible)
func WriteData(w io.Writer, data []byte) error {
    _, err := w.Write(data)
    return err
}

// Function returns concrete type (explicit)
func NewBuffer() *bytes.Buffer {
    return &bytes.Buffer{}
}

// Usage
buf := NewBuffer()
WriteData(buf, []byte("hello"))  // Buffer implements io.Writer
```

## Standard Library Interfaces to Use

Prefer these over custom interfaces when your use case matches:

| Interface | Package | Use When |
|-----------|---------|----------|
| `io.Reader` | io | Anything that provides bytes |
| `io.Writer` | io | Anything that accepts bytes |
| `io.Closer` | io | Anything that releases resources |
| `fmt.Stringer` | fmt | Custom string representation |
| `error` | builtin | Any error condition |
| `sort.Interface` | sort | Custom sort ordering (pre-generics; prefer `slices.SortFunc` in Go 1.21+) |
| `encoding.TextMarshaler` | encoding | Custom text serialization |
| `slog.LogValuer` | log/slog | Custom structured log values (Go 1.21+) |

## Review Questions

1. Are interfaces defined where they're used (consumer side)?
2. Are interfaces minimal (1-3 methods)?
3. Do interface names end in `-er`?
4. Are concrete types returned from constructors?
5. Is `any` used instead of `interface{}` (Go 1.18+)?
6. Are generics used where they add real value (multiple instantiations)?
7. Are type constraints specific enough (not just `any`)?
