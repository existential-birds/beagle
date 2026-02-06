# Model & Update

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

// GOOD - async via command
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        loadDataCmd(),
        tea.EnterAltScreen,
    )
}
```

## Update Patterns

### 1. Switch on Message Type

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

### 2. Always Handle WindowSizeMsg

```go
// BAD - ignores window size
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // no WindowSizeMsg handling
}

// GOOD
case tea.WindowSizeMsg:
    m.width = msg.Width
    m.height = msg.Height
    // Update sub-components
    m.viewport.Width = msg.Width
    m.viewport.Height = msg.Height - 4  // reserve for header/footer
    return m, nil
```

### 3. Key Handling with key.Matches

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
    case tea.KeyMsg:
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
// BAD
func (m Model) View() string {
    log.Printf("rendering")  // side effect!
    m.renderCount++          // mutation!
    return "..."
}

// GOOD - View is pure
func (m Model) View() string {
    return "..."
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
2. Does Update handle all relevant message types?
3. Is WindowSizeMsg handled for responsive layout?
4. Are key bindings using key.Matches?
5. Are sub-component updates propagated correctly?
6. Are commands used for all async/I/O operations?
