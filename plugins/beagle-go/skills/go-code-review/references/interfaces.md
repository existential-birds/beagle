# Interfaces

## Critical Anti-Patterns

### 1. Premature Interface Definition

**Problem**: Interfaces defined before needed, creating abstraction overhead.

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

**Problem**: Hard to implement, hard to mock, violates ISP.

```go
// BAD - fat interface
type UserStore interface {
    Get(id int) (*User, error)
    GetAll() ([]*User, error)
    Save(user *User) error
    Delete(id int) error
    Search(query string) ([]*User, error)
    Count() (int, error)
    // ... 10 more methods
}

// GOOD - focused interfaces
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

**Problem**: Doesn't follow Go conventions, less readable.

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

**Problem**: Hides implementation details unnecessarily.

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

### 5. Empty Interface Overuse

**Problem**: Loses type safety, requires type assertions.

```go
// BAD
func Process(data interface{}) interface{} {
    switch v := data.(type) {
    case string:
        return strings.ToUpper(v)
    case int:
        return v * 2
    }
    return nil
}

// GOOD - use generics (Go 1.18+)
func Process[T string | int](data T) T {
    // type-safe processing
}

// Or use specific types
func ProcessString(data string) string
func ProcessInt(data int) int
```

### 6. Interface for Single Implementation

**Problem**: Unnecessary abstraction with no benefit.

```go
// BAD - interface with only one implementation
type ConfigLoader interface {
    Load() (*Config, error)
}

type fileConfigLoader struct { ... }

// GOOD - just use the concrete type
type ConfigLoader struct { ... }

func (c *ConfigLoader) Load() (*Config, error) { ... }
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

```go
// io.Reader - anything that can be read from
type Reader interface {
    Read(p []byte) (n int, err error)
}

// io.Writer - anything that can be written to
type Writer interface {
    Write(p []byte) (n int, err error)
}

// io.Closer - anything that can be closed
type Closer interface {
    Close() error
}

// fmt.Stringer - custom string representation
type Stringer interface {
    String() string
}

// error - the error interface
type error interface {
    Error() string
}
```

## Review Questions

1. Are interfaces defined where they're used (consumer side)?
2. Are interfaces minimal (1-3 methods)?
3. Do interface names end in `-er`?
4. Are concrete types returned from constructors?
5. Is `interface{}` avoided in favor of generics or specific types?
