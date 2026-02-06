# Understanding the Elm Architecture

## The Core Principle: Commands Are Data

The most important concept in BubbleTea (and Elm) is that **commands describe effects, they don't execute them**.

```go
// tea.Cmd is just a function signature
type Cmd func() Msg
```

When you return a `tea.Cmd` from `Update()`, you're returning a *description* of work to do. The BubbleTea runtime executes it asynchronously after `Update()` returns.

## Common False Positive: "Synchronous Execution"

**This is NOT blocking:**

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case NavigateMsg:
        return m, m.loadData()  // ← NOT synchronous execution!
    }
    return m, nil
}

func (m *Model) loadData() tea.Cmd {
    return func() tea.Msg {
        // This closure is NOT executed during Update()
        // The runtime schedules it for async execution
        data, _ := http.Get("https://api.example.com/data")
        return DataLoadedMsg{data}
    }
}
```

**Why this is correct:**
1. `m.loadData()` is called synchronously, but it only *creates* the command
2. The `http.Get` inside the closure does NOT run during `Update()`
3. `Update()` returns immediately with the command
4. BubbleTea's runtime executes the command in a separate goroutine
5. When complete, the runtime sends `DataLoadedMsg` back to `Update()`

## The Execution Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        BubbleTea Runtime                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   User Input ──┐                                                │
│                ▼                                                │
│         ┌──────────┐     returns      ┌──────────────┐         │
│   Msg → │  Update  │ ───────────────→ │ Model, Cmd   │         │
│         └──────────┘    immediately   └──────┬───────┘         │
│                                              │                  │
│              ┌───────────────────────────────┘                  │
│              ▼                                                  │
│         ┌──────────┐                                           │
│         │ Runtime  │  executes Cmd                             │
│         │ executes │  in background                            │
│         │   Cmd    │  goroutine                                │
│         └────┬─────┘                                           │
│              │                                                  │
│              ▼ sends Msg                                        │
│         ┌──────────┐                                           │
│   Msg → │  Update  │ ← cycle continues                         │
│         └──────────┘                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## NOT Issues (Avoid These False Positives)

### 1. Helper Functions Returning tea.Cmd

```go
// ✅ CORRECT - this is NOT blocking
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    return m, m.fetchItems()
}

func (m *Model) fetchItems() tea.Cmd {
    return func() tea.Msg {
        items, _ := api.GetItems()  // Runs LATER, by runtime
        return ItemsMsg{items}
    }
}
```

**Why OK:** The helper creates and returns a command descriptor. No I/O happens in Update().

### 2. Value Receivers on Update

```go
// ✅ CORRECT - standard BubbleTea pattern
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.counter++
    return m, nil
}
```

**Why OK:** BubbleTea returns the model by value. The caller receives the modified copy.

### 3. Nested Model Updates

```go
// ✅ CORRECT - normal component composition
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.child, cmd = m.child.Update(msg)  // Updates child synchronously
    return m, cmd
}
```

**Why OK:** Child's Update() is also non-blocking. Commands bubble up.

### 4. Batch Commands

```go
// ✅ CORRECT - commands execute concurrently
return m, tea.Batch(
    m.loadUser(),
    m.loadPosts(),
    m.loadSettings(),
)
```

**Why OK:** All three commands run concurrently by the runtime.

### 5. Immediate Message Return

```go
// ✅ CORRECT - synchronous state transition
func (m *Model) navigateToMenu() tea.Cmd {
    return func() tea.Msg {
        return ShowMenuMsg{}  // No I/O, just returns a message
    }
}
```

**Why OK:** Even though this returns immediately, it's still async from Update()'s perspective.

## ACTUAL Issues to Flag

### 1. Blocking I/O Directly in Update

```go
// ❌ BAD - blocks the UI
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    data, _ := os.ReadFile("config.json")  // BLOCKS!
    m.config = parse(data)
    return m, nil
}
```

**Fix:** Move to a command:
```go
return m, loadConfigCmd()
```

### 2. Sleep in Update

```go
// ❌ BAD - freezes UI for 2 seconds
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    time.Sleep(2 * time.Second)
    return m, nil
}
```

**Fix:** Use tea.Tick:
```go
return m, tea.Tick(2*time.Second, func(t time.Time) tea.Msg {
    return DelayCompleteMsg{}
})
```

### 3. HTTP Calls in Update

```go
// ❌ BAD - network I/O in Update
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    resp, _ := http.Get("https://api.example.com")
    // ...
}
```

**Fix:** Wrap in a command function.

### 4. Channel Operations That Block

```go
// ❌ BAD - may block indefinitely
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    data := <-m.dataChan  // Could block!
    return m, nil
}
```

**Fix:** Use non-blocking select or move to command.

## Quick Reference: Is It Blocking?

| Code Pattern | Blocking? | Why |
|--------------|-----------|-----|
| `return m, m.loadData()` | No | Returns cmd descriptor |
| `data := fetchData()` (in Update) | **Yes** | Direct I/O call |
| `return m, func() tea.Msg { ... }` | No | Closure runs later |
| `time.Sleep(d)` (in Update) | **Yes** | Blocks goroutine |
| `<-channel` (in Update) | **Maybe** | Blocks if empty |
| `return m, tea.Tick(d, ...)` | No | Runtime handles delay |

## Review Guidance

When reviewing BubbleTea code:

1. **Look for I/O in Update()** - file, network, database calls directly in Update are bugs
2. **Ignore cmd helper patterns** - `return m, m.someHelper()` where helper returns `tea.Cmd` is correct
3. **Check what's INSIDE commands** - the closure body is where blocking ops belong
4. **Value receivers are fine** - BubbleTea's design expects this

The rule is simple: **Update() must return quickly. Commands do the slow work.**
