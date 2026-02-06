# Component Composition

## Bubbles Integration

### 1. Using Standard Bubbles

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
        m.viewport.Width = msg.Width
        m.viewport.Height = msg.Height - 4
    }

    return m, tea.Batch(cmds...)
}
```

## Custom Components

### 1. Component Interface Pattern

```go
// Component interface for consistent sub-components
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
    items   []Item
    cursor  int
    width   int
    height  int
}

func New(items []Item) Model {
    return Model{items: items}
}

func (m Model) Init() tea.Cmd {
    return nil
}

func (m Model) Update(msg tea.Msg) (Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
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
    if key, ok := msg.(tea.KeyMsg); ok && key.String() == "enter" {
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
    if key, ok := msg.(tea.KeyMsg); ok {
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
        if key, ok := msg.(tea.KeyMsg); ok && key.String() == "enter" {
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
case tea.KeyMsg:
    switch key.String() {
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
    case tea.KeyMsg:
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
func (m Model) View() string {
    return m.list.items[m.list.cursor].Title  // breaks encapsulation
}

// GOOD - use component methods
func (m Model) View() string {
    return m.list.SelectedItem().(Item).Title
}
```

## Huh Forms Integration

[Huh](https://github.com/charmbracelet/huh) is a form library built on BubbleTea.

### Basic Form

```go
import "github.com/charmbracelet/huh"

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

// Run standalone (blocking)
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
    form := huh.NewForm(
        huh.NewGroup(
            huh.NewInput().Key("name").Title("Name"),
        ),
    ).WithTheme(huh.ThemeDracula())

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

func (m Model) View() string {
    if m.done {
        return fmt.Sprintf("Hello, %s!", m.form.GetString("name"))
    }
    return m.form.View()
}
```

### Field Types

```go
// Text input
huh.NewInput().Key("name").Title("Name").Placeholder("Enter name")

// Multi-line text
huh.NewText().Key("bio").Title("Bio").Lines(5)

// Single select
huh.NewSelect[string]().Key("color").Title("Color").
    Options(
        huh.NewOption("Red", "red"),
        huh.NewOption("Blue", "blue"),
    )

// Multi select
huh.NewMultiSelect[string]().Key("tags").Title("Tags").
    Options(
        huh.NewOption("Go", "go"),
        huh.NewOption("Rust", "rust"),
    )

// Confirmation
huh.NewConfirm().Key("agree").Title("Agree?")

// File picker
huh.NewFilePicker().Key("file").Title("Select file")
```

### Theming

```go
form := huh.NewForm(...).
    WithTheme(huh.ThemeDracula()).      // Built-in themes
    WithWidth(60).
    WithShowHelp(true).
    WithShowErrors(true)

// Built-in themes
huh.ThemeBase()
huh.ThemeCharm()
huh.ThemeDracula()
huh.ThemeCatppuccin()
huh.ThemeBase16()
```

### Multi-Page Forms

```go
form := huh.NewForm(
    // Page 1
    huh.NewGroup(
        huh.NewInput().Key("name").Title("Name"),
        huh.NewInput().Key("email").Title("Email"),
    ).Title("Personal Info"),

    // Page 2
    huh.NewGroup(
        huh.NewSelect[string]().Key("plan").Title("Plan").
            Options(
                huh.NewOption("Free", "free"),
                huh.NewOption("Pro", "pro"),
            ),
    ).Title("Subscription"),
)
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
    m.form = form.(*huh.Form)
    return m, cmd
}
```

## Review Questions

1. Are sub-components properly initialized?
2. Are sub-component updates propagated?
3. Is WindowSizeMsg passed to all components needing resize?
4. Is there a clear state machine for view transitions?
5. Is focus tracked and components blurred/focused correctly?
6. Are Huh forms embedded correctly (not using blocking Run())?
