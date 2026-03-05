# Error Handling

## Critical Anti-Patterns

### 1. Ignoring Errors

Silent failures are impossible to debug.

```go
// BAD
file, _ := os.Open("config.json")
data, _ := io.ReadAll(file)

// GOOD
file, err := os.Open("config.json")
if err != nil {
    return fmt.Errorf("opening config: %w", err)
}
defer file.Close()
```

### 2. Unwrapped Errors

Loses context for debugging. When an error bubbles up through multiple layers, each layer should add context about what it was trying to do.

```go
// BAD - raw error
if err != nil {
    return err
}

// GOOD - wrapped with context
if err != nil {
    return fmt.Errorf("loading user %d: %w", userID, err)
}
```

### 3. String Errors Instead of Wrapping

Using `%s` or `.Error()` breaks the error chain — callers can no longer use `errors.Is` or `errors.As` to inspect the underlying cause.

```go
// BAD - breaks error inspection
return fmt.Errorf("failed: %s", err.Error())
return fmt.Errorf("failed: %v", err)

// GOOD - preserves error chain
return fmt.Errorf("failed: %w", err)
```

### 4. Panic for Recoverable Errors

Panics crash the program and bypass normal error handling. Reserve them for truly unrecoverable situations (programmer bugs, violated invariants), not for expected failures like I/O errors.

```go
// BAD
func GetConfig(path string) Config {
    data, err := os.ReadFile(path)
    if err != nil {
        panic(err)
    }
    ...
}

// GOOD
func GetConfig(path string) (Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return Config{}, fmt.Errorf("reading config: %w", err)
    }
    ...
}
```

### 5. Checking Error String Instead of Type

Error messages can change between releases. Type-based checking is stable.

```go
// BAD
if err.Error() == "file not found" {
    ...
}

// GOOD
if errors.Is(err, os.ErrNotExist) {
    ...
}

// For custom errors
var ErrNotFound = errors.New("not found")
if errors.Is(err, ErrNotFound) {
    ...
}
```

### 6. Returning Error and Valid Value

Callers expect zero values when errors are returned. Returning a meaningful value alongside an error creates ambiguity about whether the value is usable.

```go
// BAD - -1 is a valid integer, confuses callers
func Parse(s string) (int, error) {
    if s == "" {
        return -1, errors.New("empty string")
    }
    ...
}

// GOOD - zero value on error
func Parse(s string) (int, error) {
    if s == "" {
        return 0, errors.New("empty string")
    }
    ...
}
```

## Multi-Error Aggregation (Go 1.20+)

When a function encounters multiple independent errors (cleanup, batch processing, parallel operations), combine them with `errors.Join` instead of dropping all but one.

```go
// BAD - loses the first error
func cleanup(db *sql.DB, f *os.File) error {
    err := db.Close()
    err = f.Close()  // overwrites db error
    return err
}

// GOOD - preserves both errors
func cleanup(db *sql.DB, f *os.File) error {
    return errors.Join(db.Close(), f.Close())
}
```

`errors.Join` returns `nil` when all errors are `nil`, and the joined error supports `errors.Is`/`errors.As` for each constituent error:

```go
err := errors.Join(ErrNotFound, ErrTimeout)
errors.Is(err, ErrNotFound) // true
errors.Is(err, ErrTimeout)  // true
```

This is especially useful in defer chains:

```go
func processFile(path string) (retErr error) {
    f, err := os.Open(path)
    if err != nil {
        return fmt.Errorf("opening %s: %w", path, err)
    }
    defer func() {
        retErr = errors.Join(retErr, f.Close())
    }()
    // ... process file
}
```

## Sentinel Errors Pattern

```go
// Define at package level
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
)

// Usage
func GetUser(id int) (*User, error) {
    user := db.Find(id)
    if user == nil {
        return nil, ErrNotFound
    }
    return user, nil
}

// Caller checks
if errors.Is(err, ErrNotFound) {
    http.Error(w, "User not found", 404)
}
```

## Custom Error Types

When you need to carry structured data with an error, implement the `error` interface:

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on %s: %s", e.Field, e.Message)
}

// Caller extracts structured data
var ve *ValidationError
if errors.As(err, &ve) {
    log.Printf("field %s: %s", ve.Field, ve.Message)
}
```

## Review Questions

1. Are all error returns checked (no `_`)?
2. Are errors wrapped with context using `%w`?
3. Are sentinel errors used for expected error conditions?
4. Does the code use `errors.Is/As` instead of string matching?
5. Does it return zero values alongside errors?
6. Are multiple independent errors aggregated with `errors.Join`?
