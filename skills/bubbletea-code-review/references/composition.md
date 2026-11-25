# Component Composition

> **v1 vs v2 note:** In `charm.land/bubbles/v2` and `charm.land/bubbletea/v2`, imports move from `github.com/charmbracelet/*` to `charm.land/*/v2`, `viewport` uses `SetWidth`/`SetHeight`, key presses use `tea.KeyPressMsg` (spacebar `"space"`), top-level `View()` returns `tea.View`, and `charm.land/huh/v2` themes use `ThemeFunc`.

## Bubbles Integration

### 1. Using Standard Bubbles

```go
import (
    // v1: "github.com/charmbracelet/bubbles/..."
    // v2: "charm.land/bubbles/v2/..."
    "charm.land/bubbles/v2/list"
    "charm.land/bubbles/v2/spinner"
    "charm.land/bubbles/v2/textinput"
    "charm.land/bubbles/v2/viewport"
)

type Model struct {
    list     list.Model
    input    textinput.Model
    viewport viewport.Model
    spinner  spinner.Model
}
```

### 2. Initialize Sub-Components

```go
func NewModel() Model {
    // List
    items := []list.Item{...}
    l := list.New(items, list.NewDefaultDelegate(), 0, 0)
    l.Title = "My List"

    // Text input
    ti := textinput.New()
    ti.Placeholder = "Type here..."
    ti.Focus()

    // Spinner
    s := spinner.New()
    s.Spinner = spinner.Dot

    return Model{
        list:    l,
        input:   ti,
        spinner: s,
    }
}
```

### 3. Update Sub-Components

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd
    var cmd tea.Cmd

    // Always update active sub-components
    switch m.state {
    case stateList:
        m.list, cmd = m.list.Update(msg)
        cmds = append(cmds, cmd)
    case stateInput:
        m.input, cmd = m.input.Update(msg)
        cmds = append(cmds, cmd)
    }

    // Handle window size for all components
    if msg, ok := msg.(tea.WindowSizeMsg); ok {
        m.list.SetSize(msg.Width, msg.Height-4)
        // v2: SetWidth / SetHeight (v1: m.viewport.Width = msg.Width; m.viewport.Height = msg.Height - 4)
        m.viewport.SetWidth(msg.Width)
        m.viewport.SetHeight(msg.Height - 4)
    }

    return m, tea.Batch(cmds...)
}
```

## Custom Components

### 1. Component Interface Pattern

```go
// Component interface for consistent sub-components (sub-components typically return string even in v2,
// while the root tea.Model wraps the rendered string in tea.NewView(...) in View() tea.View)
type Component interface {
    Init() tea.Cmd
    Update(tea.Msg) (Component, tea.Cmd)
    View() string
    SetSize(width, height int)
}
```

### 2. Self-Contained Component

```go
// menu/menu.go
package menu

type Model struct {
    items  []Item
    cursor int
    width  int
    height int
}

func New(items []Item) Model {
    return Model{items: items}
}

func (m Model) Init() tea.Cmd {
    return nil
}

func (m Model) Update(msg tea.Msg) (Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyPressMsg: // v1: tea.KeyMsg
        switch msg.String() {
        case "up", "k":
            if m.cursor > 0 {
                m.cursor--
            }
        case "down", "j":
            if m.cursor < len(m.items)-1 {
                m.cursor++
            }
        }
    }
    return m, nil
}

func (m Model) View() string {
    var b strings.Builder
    for i, item := range m.items {
        cursor := "  "
        if i == m.cursor {
            cursor = "> "
        }
        b.WriteString(cursor + item.Title + "\n")
    }
    return b.String()
}

func (m *Model) SetSize(w, h int) {
    m.width = w
    m.height = h
}

func (m Model) Selected() Item {
    return m.items[m.cursor]
}
```

### 3. Using Custom Component

```go
import "myapp/menu"

type Model struct {
    menu menu.Model
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.menu, cmd = m.menu.Update(msg)

    // React to menu selection
    if key, ok := msg.(tea.KeyPressMsg); ok && key.String() == "enter" { // v1: tea.KeyMsg
        selected := m.menu.Selected()
        // handle selection
    }

    return m, cmd
}
```

## State Machine Pattern

### 1. View States

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
```

### 2. State Transitions

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // Global key handling
    if key, ok := msg.(tea.KeyPressMsg); ok { // v1: tea.KeyMsg
        switch key.String() {
        case "esc":
            // Go back based on current state
            switch m.state {
            case viewDetail:
                m.state = viewList
                return m, nil
            case viewEdit:
                m.state = viewDetail
                return m, nil
            }
        }
    }

    // Delegate to current state's component
    var cmd tea.Cmd
    switch m.state {
    case viewList:
        m.list, cmd = m.list.Update(msg)
        // Check for selection
        if key, ok := msg.(tea.KeyPressMsg); ok && key.String() == "enter" { // v1: tea.KeyMsg
            m.state = viewDetail
            m.detail = newDetailModel(m.list.SelectedItem())
        }
    case viewDetail:
        m.detail, cmd = m.detail.Update(msg)
    case viewEdit:
        m.edit, cmd = m.edit.Update(msg)
    }

    return m, cmd
}
```

### 3. View Routing

```go
// v1: return string directly; v2: return tea.NewView(content) from View() tea.View
func (m Model) View() tea.View {
    var content string
    switch m.state {
    case viewLoading:
        content = m.spinner.View() + " Loading..."
    case viewList:
        content = m.list.View()
    case viewDetail:
        content = m.detail.View()
    case viewEdit:
        content = m.edit.View()
    default:
        content = "Unknown state"
    }
    return tea.NewView(content)
}
```

## Focus Management

### 1. Track Focus

```go
type focusState int

const (
    focusList focusState = iota
    focusInput
    focusButtons
)

type Model struct {
    focus focusState
    list  list.Model
    input textinput.Model
}

func (m *Model) nextFocus() {
    m.focus = (m.focus + 1) % 3
    m.updateFocus()
}

func (m *Model) updateFocus() {
    switch m.focus {
    case focusInput:
        m.input.Focus()
    default:
        m.input.Blur()
    }
}
```

### 2. Tab Navigation

```go
case tea.KeyPressMsg: // v1: tea.KeyMsg
    switch msg.String() {
    case "tab":
        m.nextFocus()
        return m, nil
    case "shift+tab":
        m.prevFocus()
        return m, nil
    }

    // Only handle keys for focused component
    switch m.focus {
    case focusList:
        m.list, cmd = m.list.Update(msg)
    case focusInput:
        m.input, cmd = m.input.Update(msg)
    }
```

## Anti-Patterns

### 1. Not Propagating Updates

```go
// BAD - sub-component never updates
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyPressMsg: // v1: tea.KeyMsg
        // only handles own keys, ignores sub-component
    }
    return m, nil
}

// GOOD - always update sub-components
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.list, cmd = m.list.Update(msg)  // always propagate
    return m, cmd
}
```

### 2. Nested Component Access

```go
// BAD - reaches into component internals
func (m Model) renderSelectedTitle() string {
    return m.list.items[m.list.cursor].Title  // breaks encapsulation
}

// GOOD - use component methods
func (m Model) renderSelectedTitle() string {
    return m.list.SelectedItem().(Item).Title
}
```

## Huh Forms Integration

[Huh](https://github.com/charmbracelet/huh) is a form library built on BubbleTea (`github.com/charmbracelet/huh` in v1; `charm.land/huh/v2` in v2).

### Basic Form

```go
// v1: "github.com/charmbracelet/huh"
// v2: "charm.land/huh/v2"
import "charm.land/huh/v2"

form := huh.NewForm(
    huh.NewGroup(
        huh.NewInput().
            Key("name").
            Title("What's your name?").
            Validate(func(s string) error {
                if s == "" {
                    return errors.New("name required")
                }
                return nil
            }),

        huh.NewSelect[string]().
            Key("role").
            Title("Select role").
            Options(
                huh.NewOption("Admin", "admin"),
                huh.NewOption("User", "user"),
            ),

        huh.NewConfirm().
            Key("confirm").
            Title("Continue?"),
    ),
)

// Run standalone (blocking — only outside a Bubble Tea Update loop)
err := form.Run()

// Get values
name := form.GetString("name")
role := form.GetString("role")
confirmed := form.GetBool("confirm")
```

### Embedding in BubbleTea

```go
type Model struct {
    form *huh.Form
    done bool
}

func NewModel() Model {
    // v1: .WithTheme(huh.ThemeDracula())
    // v2: .WithTheme(huh.ThemeFunc(func(isDark bool) *huh.Styles { return huh.ThemeDracula(isDark) }))
    form := huh.NewForm(
        huh.NewGroup(
            huh.NewInput().Key("name").Title("Name"),
        ),
    )

    return Model{form: form}
}

func (m Model) Init() tea.Cmd {
    return m.form.Init()
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // Check completion first
    if m.form.State == huh.StateCompleted {
        m.done = true
        return m, nil
    }

    // Update form
    form, cmd := m.form.Update(msg)
    if f, ok := form.(*huh.Form); ok {
        m.form = f
    }
    return m, cmd
}

// v1 returns string; v2 wraps string in tea.NewView(...)
func (m Model) View() tea.View {
    if m.done {
        return tea.NewView(fmt.Sprintf("Hello, %s!", m.form.GetString("name")))
    }
    return tea.NewView(m.form.View())
}
```

### Theming (v1 vs v2)

```go
// Huh v1 (github.com/charmbracelet/huh): built-in theme helpers return *huh.Theme
form := huh.NewForm(...).
    WithTheme(huh.ThemeDracula()).
    WithWidth(60).
    WithShowHelp(true).
    WithShowErrors(true)
// Built-in v1 themes: ThemeBase(), ThemeCharm(), ThemeDracula(), ThemeCatppuccin(), ThemeBase16()

// Huh v2 (charm.land/huh/v2): uses ThemeFunc = func(isDark bool) *huh.Styles
// so themes react automatically to Bubble Tea v2 dark/light background detection:
form := huh.NewForm(...).
    WithTheme(huh.ThemeFunc(func(isDark bool) *huh.Styles {
        return huh.ThemeDracula(isDark)
    })).
    WithWidth(60)
```

### Anti-Patterns

```go
// ❌ BAD - calling Run() inside BubbleTea (blocks)
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.form.Run()  // BLOCKS THE UI!
    return m, nil
}

// ✅ GOOD - use Update loop
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    form, cmd := m.form.Update(msg)
    if f, ok := form.(*huh.Form); ok {
        m.form = f
    }
    return m, cmd
}
```

## Review Questions

1. Are sub-components properly initialized?
2. Are sub-component updates propagated?
3. Is WindowSizeMsg passed to all components needing resize (using `SetWidth`/`SetHeight` in v2)?
4. Is there a clear state machine for view transitions?
5. Is focus tracked and components blurred/focused correctly?
6. Are Huh forms embedded correctly (not using blocking `Run()`, and using `ThemeFunc` in Huh v2)?
