# Error Handling

## Critical Anti-Patterns

### 1. Ignoring Errors

**Problem**: Silent failures are impossible to debug.

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

**Problem**: Loses context for debugging.

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

**Problem**: Breaks error inspection with `errors.Is/As`.

```go
// BAD
return fmt.Errorf("failed: %s", err.Error())

// GOOD - preserves error chain
return fmt.Errorf("failed: %w", err)
```

### 4. Panic for Recoverable Errors

**Problem**: Crashes the program unexpectedly.

```go
// BAD
func GetConfig(path string) Config {
    data, err := os.ReadFile(path)
    if err != nil {
        panic(err)  // Never panic for expected errors
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

**Problem**: Brittle, breaks with error message changes.

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

**Problem**: Confuses callers about error semantics.

```go
// BAD - what does partial result mean?
func Parse(s string) (int, error) {
    if s == "" {
        return -1, errors.New("empty string")  // -1 is valid integer
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

## Review Questions

1. Are all error returns checked (no `_`)?
2. Are errors wrapped with context using `%w`?
3. Are sentinel errors used for expected error conditions?
4. Does the code use `errors.Is/As` instead of string matching?
5. Does it return zero values alongside errors?
