# Model & Update

> **v1 vs v2 note:** In `charmbracelet/bubbletea` (v1), `View()` returns `string`, keys arrive as `tea.KeyMsg` (spacebar is `" "`), and alt screen uses `tea.EnterAltScreen` / `tea.WithAltScreen()`. In `charm.land/bubbletea/v2` (v2), `View()` returns `tea.View` (with declarative `v.AltScreen = true`), key presses arrive as `tea.KeyPressMsg` (spacebar is `"space"`), and `viewport.Model` uses `SetWidth`/`SetHeight`.

## Model Design

### 1. Model Must Implement tea.Model

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

### 2. Init Returns Initial Command

```go
// BAD - blocking operation
func (m Model) Init() tea.Cmd {
    data := loadData()  // blocks!
    return nil
}

// GOOD (v1) - async via command + EnterAltScreen
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        loadDataCmd(),
        tea.EnterAltScreen,
    )
}

// GOOD (v2) - Init loads data (and optionally tea.RequestBackgroundColor);
// AltScreen is set declaratively in View() tea.View.
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        loadDataCmd(),
        tea.RequestBackgroundColor,
    )
}
```

## Update Patterns

### 1. Switch on Message Type

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyPressMsg: // v1: use tea.KeyMsg
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

### 2. Always Handle WindowSizeMsg

```go
// BAD - ignores window size
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // no WindowSizeMsg handling
}

// GOOD (v1)
case tea.WindowSizeMsg:
    m.width = msg.Width
    m.height = msg.Height
    m.viewport.Width = msg.Width
    m.viewport.Height = msg.Height - 4 // reserve for header/footer
    return m, nil

// GOOD (v2) - viewport uses SetWidth / SetHeight methods
case tea.WindowSizeMsg:
    m.width = msg.Width
    m.height = msg.Height
    m.viewport.SetWidth(msg.Width)
    m.viewport.SetHeight(msg.Height - 4)
    return m, nil
```

### 3. Key Handling with key.Matches

```go
// BAD - raw string comparison (also note: spacebar is " " in v1 vs "space" in v2)
case tea.KeyPressMsg: // v1: tea.KeyMsg
    if msg.String() == "q" {
        return m, tea.Quit
    }

// GOOD - use key bindings
type keyMap struct {
    Quit   key.Binding
    Up     key.Binding
    Select key.Binding
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
    Select: key.NewBinding(
        key.WithKeys("space", "enter"), // v1: use " " instead of "space"
        key.WithHelp("space", "select"),
    ),
}

case tea.KeyPressMsg: // v1: tea.KeyMsg
    switch {
    case key.Matches(msg, keys.Quit):
        return m, tea.Quit
    case key.Matches(msg, keys.Up):
        m.cursor--
    }
```

### 4. Sub-Component Updates

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd

    // Update sub-components
    var cmd tea.Cmd
    m.list, cmd = m.list.Update(msg)
    cmds = append(cmds, cmd)

    m.viewport, cmd = m.viewport.Update(msg)
    cmds = append(cmds, cmd)

    // Handle our own messages
    switch msg := msg.(type) {
    case tea.KeyPressMsg: // v1: tea.KeyMsg
        // ...
    }

    return m, tea.Batch(cmds...)
}
```

## Commands

### 1. Commands Return Messages

```go
// Command that performs I/O
func fetchItemsCmd(url string) tea.Cmd {
    return func() tea.Msg {
        resp, err := http.Get(url)
        if err != nil {
            return errMsg{err}
        }
        defer resp.Body.Close()

        var items []Item
        json.NewDecoder(resp.Body).Decode(&items)
        return itemsFetchedMsg{items}
    }
}
```

### 2. Tick Commands for Animation

```go
type tickMsg time.Time

func tickCmd() tea.Cmd {
    return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
        return tickMsg(t)
    })
}

case tickMsg:
    m.frame++
    return m, tickCmd()  // schedule next tick
```

### 3. Batch Multiple Commands

```go
// BAD - returns only last command
func (m Model) Init() tea.Cmd {
    loadConfig()
    return loadData()  // loadConfig result lost!
}

// GOOD - batch them
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        loadConfigCmd(),
        loadDataCmd(),
        startSpinnerCmd(),
    )
}
```

## Anti-Patterns

### 1. Side Effects in View

```go
// BAD (shown with v1 string return; same applies to v2 View() tea.View)
func (m Model) View() string {
    log.Printf("rendering")  // side effect!
    m.renderCount++          // mutation!
    return "..."
}

// GOOD (v1) - View is pure
func (m Model) View() string {
    return "..."
}

// GOOD (v2) - View is pure and returns tea.View
func (m Model) View() tea.View {
    v := tea.NewView("...")
    v.AltScreen = true
    return v
}
```

### 2. Blocking in Update

```go
// BAD
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    time.Sleep(2 * time.Second)  // freezes UI!
    return m, nil
}

// GOOD - use commands for delays
return m, tea.Tick(2*time.Second, func(t time.Time) tea.Msg {
    return delayCompleteMsg{}
})
```

## Review Questions

1. Does Init return a command for initial I/O?
2. Does Update handle all relevant message types (`tea.KeyMsg` in v1; `tea.KeyPressMsg` in v2)?
3. Is WindowSizeMsg handled for responsive layout (using `SetWidth`/`SetHeight` in v2)?
4. Are key bindings using `key.Matches`?
5. Are sub-component updates propagated correctly?
6. Are commands used for all async/I/O operations?
