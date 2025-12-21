# Go Backend Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.go$'
```

## Step 2: Detect Technologies

```bash
# Detect BubbleTea TUI
grep -r "charmbracelet/bubbletea\|tea\.Model\|tea\.Cmd" --include="*.go" -l | head -3

# Detect Wish SSH
grep -r "charmbracelet/wish\|ssh\.Session\|wish\.Middleware" --include="*.go" -l | head -3

# Detect Prometheus
grep -r "prometheus/client_golang\|promauto\|prometheus\.Counter" --include="*.go" -l | head -3

# Detect ZeroLog
grep -r "rs/zerolog\|zerolog\.Logger" --include="*.go" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '_test\.go$'
```

## Step 3: Review

**Sequential (default):**
1. Review Go quality issues first (error handling, concurrency, interfaces)
2. Review detected technology areas
3. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one subagent per technology area with `Task` tool
3. Each agent loads its skill and reviews its domain
4. Wait for all agents
5. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, race condition, resource leak, security)
   - Fix: Specific recommended fix

### Major (Should Fix)

2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)

N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
Rationale: [1-2 sentences]
```

## Post-Fix Verification

After fixes are applied, run:

```bash
go build ./...
go vet ./...
golangci-lint run
go test -v -race ./...
```

All checks must pass before approval.

## Rules

- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Check for race conditions with `-race` flag
- Run verification after fixes

---

# Technology Knowledge Base

## Go Code Review

### Review Checklist

- [ ] All errors are checked (no `_ = err`)
- [ ] Errors wrapped with context (`fmt.Errorf("...: %w", err)`)
- [ ] Resources closed with `defer` immediately after creation
- [ ] No goroutine leaks (channels closed, contexts canceled)
- [ ] Interfaces defined by consumers, not producers
- [ ] Interface names end in `-er` (Reader, Writer, Handler)
- [ ] Exported names have doc comments
- [ ] No naked returns in functions > 5 lines
- [ ] Context passed as first parameter
- [ ] Mutexes protect shared state, not methods

### Review Questions

1. Are all error returns checked and wrapped?
2. Are goroutines properly managed with context cancellation?
3. Are resources (files, connections) closed with defer?
4. Are interfaces minimal and defined where used?

### Error Handling

#### Critical Anti-Patterns

**1. Ignoring Errors**

Problem: Silent failures are impossible to debug.

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

**2. Unwrapped Errors**

Problem: Loses context for debugging.

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

**3. String Errors Instead of Wrapping**

Problem: Breaks error inspection with `errors.Is/As`.

```go
// BAD
return fmt.Errorf("failed: %s", err.Error())

// GOOD - preserves error chain
return fmt.Errorf("failed: %w", err)
```

**4. Panic for Recoverable Errors**

Problem: Crashes the program unexpectedly.

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

**5. Checking Error String Instead of Type**

Problem: Brittle, breaks with error message changes.

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

**6. Returning Error and Valid Value**

Problem: Confuses callers about error semantics.

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

#### Sentinel Errors Pattern

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

### Concurrency

#### Critical Anti-Patterns

**1. Goroutine Leak**

Problem: Goroutines block forever, consuming memory.

```go
// BAD - no way to stop the goroutine
func startWorker() {
    go func() {
        for {
            doWork()
        }
    }()
}

// GOOD - context cancellation
func startWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            default:
                doWork()
            }
        }
    }()
}
```

**2. Unbounded Channel Send**

Problem: Sender blocks forever if receiver dies.

```go
// BAD - blocks if nobody reads
ch <- result

// GOOD - respect context
select {
case ch <- result:
case <-ctx.Done():
    return ctx.Err()
}
```

**3. Closing Channel Multiple Times**

Problem: Panic at runtime.

```go
// BAD - potential double close
close(ch)
close(ch)  // panic!

// GOOD - only sender closes, once
func produce(ch chan<- int) {
    defer close(ch)  // close happens exactly once
    for i := 0; i < 10; i++ {
        ch <- i
    }
}
```

**4. Race Condition on Shared State**

Problem: Data corruption, undefined behavior.

```go
// BAD - concurrent map access
var cache = make(map[string]int)
func Get(key string) int {
    return cache[key]  // race!
}
func Set(key string, val int) {
    cache[key] = val  // race!
}

// GOOD - mutex protection
var (
    cache   = make(map[string]int)
    cacheMu sync.RWMutex
)
func Get(key string) int {
    cacheMu.RLock()
    defer cacheMu.RUnlock()
    return cache[key]
}
func Set(key string, val int) {
    cacheMu.Lock()
    defer cacheMu.Unlock()
    cache[key] = val
}

// BETTER - sync.Map for simple cases
var cache sync.Map
func Get(key string) (int, bool) {
    v, ok := cache.Load(key)
    if !ok {
        return 0, false
    }
    return v.(int), true
}
```

**5. Missing WaitGroup**

Problem: Program exits before goroutines complete.

```go
// BAD - may exit before done
for _, item := range items {
    go process(item)
}
return  // goroutines may not finish

// GOOD
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()
```

**6. Loop Variable Capture**

Problem: All goroutines see the same variable value.

```go
// BAD (pre-Go 1.22)
for _, item := range items {
    go func() {
        process(item)  // all see last item!
    }()
}

// GOOD - capture in closure
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}

// Note: Go 1.22+ fixes this by default
```

**7. Context Not Propagated**

Problem: Can't cancel downstream operations.

```go
// BAD
func Handler(ctx context.Context) error {
    result := doWork()  // ignores ctx
    return nil
}

// GOOD
func Handler(ctx context.Context) error {
    result, err := doWork(ctx)  // passes ctx
    if err != nil {
        return err
    }
    return nil
}
```

#### Worker Pool Pattern

```go
func processItems(ctx context.Context, items []Item) error {
    const workers = 5

    jobs := make(chan Item)
    errs := make(chan error, 1)

    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range jobs {
                if err := process(ctx, item); err != nil {
                    select {
                    case errs <- err:
                    default:
                    }
                    return
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(errs)
    }()

    for _, item := range items {
        select {
        case jobs <- item:
        case err := <-errs:
            return err
        case <-ctx.Done():
            return ctx.Err()
        }
    }
    close(jobs)

    return <-errs
}
```

### Interfaces

#### Critical Anti-Patterns

**1. Premature Interface Definition**

Problem: Interfaces defined before needed, creating abstraction overhead.

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

**2. Interface Pollution (Too Many Methods)**

Problem: Hard to implement, hard to mock, violates ISP.

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

**3. Wrong Interface Names**

Problem: Doesn't follow Go conventions, less readable.

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

**4. Returning Interface Instead of Concrete Type**

Problem: Hides implementation details unnecessarily.

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

**5. Empty Interface Overuse**

Problem: Loses type safety, requires type assertions.

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

**6. Interface for Single Implementation**

Problem: Unnecessary abstraction with no benefit.

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

#### Accept Interfaces, Return Structs

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

### Common Mistakes

#### Resource Leaks

**1. Missing defer for Close**

Problem: Resources leaked on early return.

```go
// BAD
func readFile(path string) ([]byte, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    data, err := io.ReadAll(f)
    if err != nil {
        return nil, err  // file never closed!
    }
    f.Close()
    return data, nil
}

// GOOD - defer immediately
func readFile(path string) ([]byte, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer f.Close()
    return io.ReadAll(f)
}
```

**2. Defer in Loop**

Problem: Resources accumulate until function returns.

```go
// BAD - files stay open until loop ends
for _, path := range paths {
    f, _ := os.Open(path)
    defer f.Close()  // deferred until function returns
    process(f)
}

// GOOD - close in each iteration or use closure
for _, path := range paths {
    func() {
        f, _ := os.Open(path)
        defer f.Close()
        process(f)
    }()
}
```

**3. HTTP Response Body Not Closed**

Problem: Connection pool exhaustion.

```go
// BAD
resp, err := http.Get(url)
if err != nil {
    return err
}
// body never closed!
data, _ := io.ReadAll(resp.Body)

// GOOD
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
data, _ := io.ReadAll(resp.Body)
```

#### Naming and Style

**4. Stuttering Names**

Problem: Redundant when used with package name.

```go
// BAD
package user
type UserService struct { ... }  // user.UserService

// GOOD
package user
type Service struct { ... }  // user.Service
```

**5. Missing Doc Comments on Exports**

Problem: godoc can't generate documentation.

```go
// BAD
func NewServer(addr string) *Server { ... }

// GOOD
// NewServer creates a new HTTP server listening on addr.
func NewServer(addr string) *Server { ... }
```

**6. Naked Returns in Long Functions**

Problem: Hard to track what's being returned.

```go
// BAD
func process(data []byte) (result string, err error) {
    // 50 lines of code...

    return  // what's being returned?
}

// GOOD - explicit returns
func process(data []byte) (string, error) {
    // 50 lines of code...

    return processedString, nil
}
```

#### Initialization

**7. Init Function Overuse**

Problem: Hidden side effects, hard to test.

```go
// BAD - global state via init
var db *sql.DB

func init() {
    var err error
    db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal(err)
    }
}

// GOOD - explicit initialization
type App struct {
    db *sql.DB
}

func NewApp(dbURL string) (*App, error) {
    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        return nil, fmt.Errorf("opening db: %w", err)
    }
    return &App{db: db}, nil
}
```

**8. Global Mutable State**

Problem: Race conditions, hard to test.

```go
// BAD
var config Config

func GetConfig() Config {
    return config
}

// GOOD - dependency injection
type Server struct {
    config Config
}

func NewServer(cfg Config) *Server {
    return &Server{config: cfg}
}
```

#### Performance

**9. String Concatenation in Loop**

Problem: O(n²) allocation overhead.

```go
// BAD
var result string
for _, s := range items {
    result += s + ", "
}

// GOOD
var b strings.Builder
for _, s := range items {
    b.WriteString(s)
    b.WriteString(", ")
}
result := b.String()
```

**10. Slice Preallocation**

Problem: Repeated reallocations.

```go
// BAD - grows dynamically
var results []Result
for _, item := range items {
    results = append(results, process(item))
}

// GOOD - preallocate known size
results := make([]Result, 0, len(items))
for _, item := range items {
    results = append(results, process(item))
}
```

---

## Go Testing Code Review

### Review Checklist

- [ ] Tests are table-driven with clear case names
- [ ] Subtests use t.Run for parallel execution
- [ ] Test names describe behavior, not implementation
- [ ] Errors include got/want with descriptive message
- [ ] Cleanup registered with t.Cleanup
- [ ] Parallel tests don't share mutable state
- [ ] Mocks use interfaces defined in test file
- [ ] Coverage includes edge cases and error paths

### Critical Patterns

#### Table-Driven Tests

```go
// BAD - repetitive
func TestAdd(t *testing.T) {
    if Add(1, 2) != 3 {
        t.Error("wrong")
    }
    if Add(0, 0) != 0 {
        t.Error("wrong")
    }
}

// GOOD
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        want     int
    }{
        {"positive numbers", 1, 2, 3},
        {"zeros", 0, 0, 0},
        {"negative", -1, 1, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

#### Error Messages

```go
// BAD
if got != want {
    t.Error("wrong result")
}

// GOOD
if got != want {
    t.Errorf("GetUser(%d) = %v, want %v", id, got, want)
}

// For complex types
if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("GetUser() mismatch (-want +got):\n%s", diff)
}
```

#### Parallel Tests

```go
func TestFoo(t *testing.T) {
    tests := []struct{...}

    for _, tt := range tests {
        tt := tt  // capture (not needed Go 1.22+)
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // test code
        })
    }
}
```

#### Cleanup

```go
// BAD - manual cleanup, skipped on failure
func TestWithTempFile(t *testing.T) {
    f, _ := os.CreateTemp("", "test")
    defer os.Remove(f.Name())  // skipped if test panics
}

// GOOD
func TestWithTempFile(t *testing.T) {
    f, _ := os.CreateTemp("", "test")
    t.Cleanup(func() {
        os.Remove(f.Name())
    })
}
```

### Anti-Patterns

**1. Testing Internal Implementation**

```go
// BAD - tests private state
func TestUser(t *testing.T) {
    u := NewUser("alice")
    if u.id != 1 {  // testing internal field
        t.Error("wrong id")
    }
}

// GOOD - tests behavior
func TestUser(t *testing.T) {
    u := NewUser("alice")
    if u.ID() != 1 {
        t.Error("wrong ID")
    }
}
```

**2. Shared Mutable State**

```go
// BAD - tests interfere with each other
var testDB = setupDB()

func TestA(t *testing.T) {
    t.Parallel()
    testDB.Insert(...)  // race!
}

// GOOD - isolated per test
func TestA(t *testing.T) {
    db := setupTestDB(t)
    t.Cleanup(func() { db.Close() })
    db.Insert(...)
}
```

**3. Assertions Without Context**

```go
// BAD
assert.Equal(t, want, got)  // "expected X got Y" - which test?

// GOOD
assert.Equal(t, want, got, "user name after update")
```

### Test Structure

#### File Organization

```
package/
├── user.go
├── user_test.go       # same package tests
├── user_internal_test.go  # internal tests if needed
└── testdata/          # test fixtures
    └── users.json
```

#### Helper Functions

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

### Mocking

#### Interface-Based Mocking

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

#### Testing HTTP Clients

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

---

## BubbleTea TUI Code Review

### Review Checklist

- [ ] Model is immutable (Update returns new model, not mutates)
- [ ] Init returns proper initial command (or nil)
- [ ] Update handles all expected message types
- [ ] View is a pure function (no side effects)
- [ ] tea.Quit used correctly for exit
- [ ] Key bindings use key.Matches with help.KeyMap
- [ ] Lipgloss styles are defined once, not in View
- [ ] Commands are used for I/O, not direct calls
- [ ] WindowSizeMsg handled for responsive layout
- [ ] tea.Batch used for multiple commands

### Critical Patterns

#### Model Must Be Immutable

```go
// BAD - mutates model
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.items = append(m.items, newItem)  // mutation!
    return m, nil
}

// GOOD - returns new model
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    newItems := make([]Item, len(m.items)+1)
    copy(newItems, m.items)
    newItems[len(m.items)] = newItem
    m.items = newItems
    return m, nil
}
```

#### Commands for Async/IO

```go
// BAD - blocking in Update
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    data, _ := os.ReadFile("config.json")  // blocks UI!
    m.config = parse(data)
    return m, nil
}

// GOOD - use commands
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    return m, loadConfigCmd()
}

func loadConfigCmd() tea.Cmd {
    return func() tea.Msg {
        data, err := os.ReadFile("config.json")
        if err != nil {
            return errMsg{err}
        }
        return configLoadedMsg{parse(data)}
    }
}
```

#### Styles Defined Once

```go
// BAD - creates new style each render
func (m Model) View() string {
    style := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("205"))
    return style.Render("Hello")
}

// GOOD - define styles at package level or in model
var titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("205"))

func (m Model) View() string {
    return titleStyle.Render("Hello")
}
```

### Model & Update

#### Model Design

```go
type Model struct {
    // State
    items    []Item
    cursor   int
    selected map[int]struct{}

    // Dimensions (for responsive layout)
    width  int
    height int

    // Sub-components
    list     list.Model
    viewport viewport.Model

    // Error state
    err error
}

// Verify interface implementation
var _ tea.Model = (*Model)(nil)
```

#### Update Patterns

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        return m.handleKey(msg)
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
        return m, nil
    case dataLoadedMsg:
        m.items = msg.items
        return m, nil
    case errMsg:
        m.err = msg.err
        return m, nil
    }
    return m, nil
}
```

#### Key Handling with key.Matches

```go
// BAD - string comparison
case tea.KeyMsg:
    if msg.String() == "q" {
        return m, tea.Quit
    }

// GOOD - use key bindings
type keyMap struct {
    Quit key.Binding
    Up   key.Binding
    Down key.Binding
}

var keys = keyMap{
    Quit: key.NewBinding(
        key.WithKeys("q", "ctrl+c"),
        key.WithHelp("q", "quit"),
    ),
    Up: key.NewBinding(
        key.WithKeys("up", "k"),
        key.WithHelp("↑/k", "up"),
    ),
}

case tea.KeyMsg:
    switch {
    case key.Matches(msg, keys.Quit):
        return m, tea.Quit
    case key.Matches(msg, keys.Up):
        m.cursor--
    }
```

### View & Styling

#### View Must Be Pure

```go
// BAD - side effects
func (m Model) View() string {
    m.lastRender = time.Now()  // mutation!
    log.Println("rendering")    // I/O!
    return "..."
}

// GOOD - pure function
func (m Model) View() string {
    if m.loading {
        return m.spinner.View() + " Loading..."
    }
    return m.renderContent()
}
```

#### Lipgloss Color Palette

```go
// Define a consistent color palette
var (
    colorPrimary   = lipgloss.Color("205")  // magenta
    colorSecondary = lipgloss.Color("241")  // gray
    colorSuccess   = lipgloss.Color("78")   // green
    colorError     = lipgloss.Color("196")  // red
)

var (
    titleStyle = lipgloss.NewStyle().Foreground(colorPrimary)
    errorStyle = lipgloss.NewStyle().Foreground(colorError)
)
```

#### Adaptive Colors for Themes

```go
var (
    // Adaptive colors work with light and dark terminals
    subtle    = lipgloss.AdaptiveColor{Light: "#D9DCCF", Dark: "#383838"}
    highlight = lipgloss.AdaptiveColor{Light: "#874BFD", Dark: "#7D56F4"}
)

var titleStyle = lipgloss.NewStyle().
    Foreground(highlight).
    Background(subtle)
```

### Component Composition

#### Using Standard Bubbles

```go
import (
    "github.com/charmbracelet/bubbles/list"
    "github.com/charmbracelet/bubbles/textinput"
    "github.com/charmbracelet/bubbles/viewport"
    "github.com/charmbracelet/bubbles/spinner"
)

type Model struct {
    list      list.Model
    input     textinput.Model
    viewport  viewport.Model
    spinner   spinner.Model
}
```

#### State Machine Pattern

```go
type viewState int

const (
    viewLoading viewState = iota
    viewList
    viewDetail
    viewEdit
)

type Model struct {
    state viewState
    // sub-components for each state
    list   list.Model
    detail detailModel
    edit   editModel
}

func (m Model) View() string {
    switch m.state {
    case viewLoading:
        return m.spinner.View() + " Loading..."
    case viewList:
        return m.list.View()
    case viewDetail:
        return m.detail.View()
    case viewEdit:
        return m.edit.View()
    default:
        return "Unknown state"
    }
}
```

---

## Wish SSH Server Code Review

### Review Checklist

- [ ] Host keys are loaded from file or generated securely
- [ ] Middleware order is correct (logging first, auth early)
- [ ] Session context is used for per-connection state
- [ ] Graceful shutdown handles active sessions
- [ ] PTY requests are handled for terminal apps
- [ ] Connection limits prevent resource exhaustion
- [ ] Timeout middleware prevents hung connections
- [ ] BubbleTea middleware correctly configured

### Critical Patterns

#### Server Setup

```go
// GOOD - complete server setup
s, err := wish.NewServer(
    wish.WithAddress(fmt.Sprintf("%s:%d", host, port)),
    wish.WithHostKeyPath(".ssh/id_ed25519"),
    wish.WithMiddleware(
        logging.Middleware(),       // first: log all connections
        activeterm.Middleware(),    // handle terminal sizing
        bubbletea.Middleware(teaHandler),
    ),
)
if err != nil {
    return fmt.Errorf("creating server: %w", err)
}
```

#### Graceful Shutdown

```go
// BAD - abrupt shutdown
log.Fatal(s.ListenAndServe())

// GOOD - graceful shutdown
done := make(chan os.Signal, 1)
signal.Notify(done, os.Interrupt, syscall.SIGTERM)

go func() {
    if err := s.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
        log.Error("server error", "error", err)
    }
}()

<-done
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
if err := s.Shutdown(ctx); err != nil {
    log.Error("shutdown error", "error", err)
}
```

#### BubbleTea Handler

```go
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, _ := s.Pty()

    model := NewModel(pty.Window.Width, pty.Window.Height)

    return model, []tea.ProgramOption{
        tea.WithAltScreen(),
        tea.WithMouseCellMotion(),
    }
}
```

### Server Setup Details

#### Host Key Management

```go
// BAD - generates new key each start (fingerprint changes)
s, err := wish.NewServer(
    wish.WithAddress(":22"),
    // no host key specified - generates random
)

// GOOD - load from file
s, err := wish.NewServer(
    wish.WithAddress(":22"),
    wish.WithHostKeyPath("/data/ssh_host_ed25519_key"),
)
```

#### Middleware Configuration

```go
// Middleware executes in order - first added runs first
wish.WithMiddleware(
    // 1. Logging - see all connections
    logging.Middleware(),

    // 2. Timeout - prevent hung connections
    wish.WithIdleTimeout(10*time.Minute),
    wish.WithMaxTimeout(30*time.Minute),

    // 3. Active terminal - handle PTY/window sizing
    activeterm.Middleware(),

    // 4. Your app handler - BubbleTea or custom
    bubbletea.Middleware(teaHandler),
)
```

### Sessions & Security

#### Access Session Info

```go
func handler(s ssh.Session) {
    // User info
    user := s.User()
    remoteAddr := s.RemoteAddr()

    // Public key (if key auth)
    key := s.PublicKey()

    // Environment variables
    env := s.Environ()

    // Command (if not interactive)
    cmd := s.Command()

    // PTY info (if allocated)
    pty, winCh, isPty := s.Pty()
    if isPty {
        width := pty.Window.Width
        height := pty.Window.Height
    }
}
```

#### Authentication

```go
// Public key authentication
wish.WithPublicKeyAuth(func(ctx ssh.Context, key ssh.PublicKey) bool {
    // Check against authorized keys
    authorized := loadAuthorizedKeys()
    for _, authKey := range authorized {
        if ssh.KeysEqual(key, authKey) {
            return true
        }
    }
    return false
}),
```

#### Per-Session Styles

```go
// Each session needs its own renderer for correct color detection
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    renderer := bubbletea.MakeRenderer(s)

    // Create styles with session's renderer
    styles := NewStyles(renderer)

    model := Model{
        styles: styles,
    }

    return model, nil
}

type Styles struct {
    Title lipgloss.Style
    Item  lipgloss.Style
}

func NewStyles(r *lipgloss.Renderer) Styles {
    return Styles{
        Title: r.NewStyle().Bold(true).Foreground(lipgloss.Color("205")),
        Item:  r.NewStyle().PaddingLeft(2),
    }
}
```

### Anti-Patterns

**Ignoring PTY**

```go
// BAD - assumes PTY always exists
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, _ := s.Pty()  // may be nil!
    model := NewModel(pty.Window.Width, pty.Window.Height)  // panic!
}

// GOOD - handle non-PTY connections
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, hasPty := s.Pty()

    width, height := 80, 24  // sensible defaults
    if hasPty {
        width = pty.Window.Width
        height = pty.Window.Height
    }

    model := NewModel(width, height)
    return model, nil
}
```

---

## Prometheus Instrumentation Code Review

### Review Checklist

- [ ] Metric types match measurement semantics (Counter/Gauge/Histogram)
- [ ] Labels have low cardinality (no user IDs, timestamps, paths)
- [ ] Metric names follow conventions (snake_case, unit suffix)
- [ ] Histograms use appropriate bucket boundaries
- [ ] Metrics registered once, not per-request
- [ ] Collectors don't panic on race conditions
- [ ] /metrics endpoint exposed and accessible

### Metric Type Selection

| Measurement | Type | Example |
|-------------|------|---------|
| Requests processed | Counter | `requests_total` |
| Items in queue | Gauge | `queue_length` |
| Request duration | Histogram | `request_duration_seconds` |
| Concurrent connections | Gauge | `active_connections` |
| Errors since start | Counter | `errors_total` |
| Memory usage | Gauge | `memory_bytes` |

### Critical Anti-Patterns

**1. High Cardinality Labels**

```go
// BAD - unique per user/request
counter := promauto.NewCounterVec(
    prometheus.CounterOpts{Name: "requests_total"},
    []string{"user_id", "path"},  // millions of series!
)
counter.WithLabelValues(userID, request.URL.Path).Inc()

// GOOD - bounded label values
counter := promauto.NewCounterVec(
    prometheus.CounterOpts{Name: "requests_total"},
    []string{"method", "status_code"},  // <100 series
)
counter.WithLabelValues(r.Method, statusCode).Inc()
```

**2. Wrong Metric Type**

```go
// BAD - using gauge for monotonic value
requestCount := promauto.NewGauge(prometheus.GaugeOpts{
    Name: "http_requests",
})
requestCount.Inc()  // should be Counter!

// GOOD
requestCount := promauto.NewCounter(prometheus.CounterOpts{
    Name: "http_requests_total",
})
requestCount.Inc()
```

**3. Registering Per-Request**

```go
// BAD - new metric per request
func handler(w http.ResponseWriter, r *http.Request) {
    counter := prometheus.NewCounter(...)  // creates new each time!
    prometheus.MustRegister(counter)       // panics on duplicate!
}

// GOOD - register once
var requestCounter = promauto.NewCounter(prometheus.CounterOpts{
    Name: "http_requests_total",
})

func handler(w http.ResponseWriter, r *http.Request) {
    requestCounter.Inc()
}
```

**4. Missing Unit Suffix**

```go
// BAD
duration := promauto.NewHistogram(prometheus.HistogramOpts{
    Name: "request_duration",  // no unit!
})

// GOOD
duration := promauto.NewHistogram(prometheus.HistogramOpts{
    Name: "request_duration_seconds",  // unit in name
})
```

### Good Patterns

#### Metric Definition

```go
var (
    httpRequests = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Namespace: "myapp",
            Subsystem: "http",
            Name:      "requests_total",
            Help:      "Total HTTP requests processed",
        },
        []string{"method", "status"},
    )

    httpDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Namespace: "myapp",
            Subsystem: "http",
            Name:      "request_duration_seconds",
            Help:      "HTTP request latencies",
            Buckets:   []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
        },
        []string{"method"},
    )
)
```

#### Middleware Pattern

```go
func metricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method))
        defer timer.ObserveDuration()

        wrapped := &responseWriter{ResponseWriter: w, status: 200}
        next.ServeHTTP(wrapped, r)

        httpRequests.WithLabelValues(r.Method, strconv.Itoa(wrapped.status)).Inc()
    })
}
```

#### Exposing Metrics

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":9090", nil)
}
```
