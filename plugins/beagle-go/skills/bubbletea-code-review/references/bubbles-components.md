# Bubbles Component Reference

Complete reference for all charmbracelet/bubbles components.

## Component Overview

| Component | Package | Purpose |
|-----------|---------|---------|
| list | `bubbles/list` | Scrollable list with filtering |
| table | `bubbles/table` | Tabular data display |
| viewport | `bubbles/viewport` | Scrollable content area |
| textinput | `bubbles/textinput` | Single-line text input |
| textarea | `bubbles/textarea` | Multi-line text input |
| spinner | `bubbles/spinner` | Loading indicator |
| progress | `bubbles/progress` | Progress bar |
| paginator | `bubbles/paginator` | Page navigation |
| filepicker | `bubbles/filepicker` | File/directory selection |
| timer | `bubbles/timer` | Countdown timer |
| stopwatch | `bubbles/stopwatch` | Elapsed time counter |
| help | `bubbles/help` | Key binding help display |
| key | `bubbles/key` | Key binding definitions |
| cursor | `bubbles/cursor` | Text cursor management |

---

## List

Full-featured list with filtering, pagination, and custom delegates.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/list"

// Items must implement list.Item
type item struct {
    title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

// Create list
items := []list.Item{
    item{title: "Raspberry Pi", desc: "A small computer"},
    item{title: "Arduino", desc: "A microcontroller"},
}

l := list.New(items, list.NewDefaultDelegate(), 0, 0)
l.Title = "My List"
```

### Common Patterns

```go
// Update list size on window resize
case tea.WindowSizeMsg:
    h, v := docStyle.GetFrameSize()
    m.list.SetSize(msg.Width-h, msg.Height-v)

// Get selected item
if i, ok := m.list.SelectedItem().(item); ok {
    return i.title
}

// Set items dynamically
m.list.SetItems(newItems)

// Custom delegate for styling
delegate := list.NewDefaultDelegate()
delegate.Styles.SelectedTitle = selectedTitleStyle
delegate.Styles.SelectedDesc = selectedDescStyle
```

### Anti-Patterns

```go
// ❌ BAD - reaching into internals
selected := m.list.Items()[m.list.Index()]

// ✅ GOOD - use provided methods
selected := m.list.SelectedItem()
```

---

## Table

Tabular data with column definitions and row selection.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/table"

columns := []table.Column{
    {Title: "Name", Width: 20},
    {Title: "Email", Width: 30},
    {Title: "Role", Width: 15},
}

rows := []table.Row{
    {"Alice", "alice@example.com", "Admin"},
    {"Bob", "bob@example.com", "User"},
}

t := table.New(
    table.WithColumns(columns),
    table.WithRows(rows),
    table.WithFocused(true),
    table.WithHeight(10),
)

// Apply styles
s := table.DefaultStyles()
s.Header = s.Header.BorderStyle(lipgloss.NormalBorder())
s.Selected = s.Selected.Foreground(lipgloss.Color("229"))
t.SetStyles(s)
```

### Common Patterns

```go
// Get selected row
selectedRow := m.table.SelectedRow()

// Update rows
m.table.SetRows(newRows)

// Handle selection
case tea.KeyMsg:
    switch msg.String() {
    case "enter":
        row := m.table.SelectedRow()
        return m, selectRowCmd(row)
    }
```

---

## Viewport

Scrollable content area for large text or rendered content.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/viewport"

vp := viewport.New(80, 20)
vp.SetContent(longContent)

// In Update
case tea.WindowSizeMsg:
    vp.Width = msg.Width
    vp.Height = msg.Height - headerHeight - footerHeight
```

### Common Patterns

```go
// Track scroll position
func (m Model) footerView() string {
    return fmt.Sprintf("%3.f%%", m.viewport.ScrollPercent()*100)
}

// Programmatic scrolling
m.viewport.GotoTop()
m.viewport.GotoBottom()
m.viewport.LineDown(5)
m.viewport.LineUp(5)

// Update content
m.viewport.SetContent(newContent)
```

### Anti-Patterns

```go
// ❌ BAD - setting content in View
func (m Model) View() string {
    m.viewport.SetContent(m.renderContent())  // Side effect!
    return m.viewport.View()
}

// ✅ GOOD - set content in Update
case contentLoadedMsg:
    m.viewport.SetContent(msg.content)
    return m, nil
```

---

## TextInput

Single-line text input with placeholder and validation.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/textinput"

ti := textinput.New()
ti.Placeholder = "Enter username"
ti.CharLimit = 32
ti.Width = 20
ti.Focus()
```

### Common Patterns

```go
// Password input
ti.EchoMode = textinput.EchoPassword
ti.EchoCharacter = '*'

// Validation styling
ti.Validate = func(s string) error {
    if len(s) < 3 {
        return errors.New("too short")
    }
    return nil
}

// Get value
value := m.textinput.Value()

// Clear input
m.textinput.Reset()

// Focus management
m.textinput.Focus()
m.textinput.Blur()
```

### Multiple Inputs

```go
type Model struct {
    inputs  []textinput.Model
    focused int
}

func (m *Model) nextInput() {
    m.inputs[m.focused].Blur()
    m.focused = (m.focused + 1) % len(m.inputs)
    m.inputs[m.focused].Focus()
}
```

---

## TextArea

Multi-line text input with line wrapping.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/textarea"

ta := textarea.New()
ta.Placeholder = "Type your message..."
ta.SetWidth(60)
ta.SetHeight(10)
ta.Focus()
```

### Common Patterns

```go
// Get/set value
content := m.textarea.Value()
m.textarea.SetValue("Initial content")

// Line count
lines := m.textarea.LineCount()

// Cursor position
row, col := m.textarea.Cursor()

// Resize
case tea.WindowSizeMsg:
    m.textarea.SetWidth(msg.Width - 4)
    m.textarea.SetHeight(msg.Height - 6)
```

---

## Spinner

Loading indicator with multiple styles.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/spinner"

s := spinner.New()
s.Spinner = spinner.Dot  // or Line, MiniDot, Jump, Pulse, Points, Globe, Moon, Monkey, Meter, Hamburger

// In Init
return s.Tick

// In Update
case spinner.TickMsg:
    m.spinner, cmd = m.spinner.Update(msg)
    return m, cmd
```

### Spinner Styles

```go
// Available spinners
spinner.Line      // |/-\
spinner.Dot       // ⣾⣽⣻⢿⡿⣟⣯⣷
spinner.MiniDot   // ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏
spinner.Jump      // ⢄⢂⢁⡁⡈⡐⡠
spinner.Pulse     // █▓▒░
spinner.Points    // ∙∙∙
spinner.Globe     // 🌍🌎🌏
spinner.Moon      // 🌑🌒🌓🌔🌕🌖🌗🌘
spinner.Monkey    // 🙈🙉🙊
spinner.Meter     // ▱▰▰▰▰▰▰
spinner.Hamburger // ☰☲☴
```

---

## Progress

Progress bar with percentage and custom styling.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/progress"

p := progress.New(progress.WithDefaultGradient())
// or
p := progress.New(progress.WithScaledGradient("#FF7CCB", "#FDFF8C"))

// In View
return p.ViewAs(0.5)  // 50%

// Animated progress
return p.View()  // uses internal percentage
```

### Common Patterns

```go
// Update progress
m.progress.SetPercent(0.75)

// Width adjustment
case tea.WindowSizeMsg:
    m.progress.Width = msg.Width - padding

// Animated increment
case progressMsg:
    cmd := m.progress.SetPercent(msg.percent)
    return m, cmd
```

---

## Paginator

Page navigation for paginated content.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/paginator"

p := paginator.New()
p.Type = paginator.Dots  // or Arabic (1/10)
p.SetTotalPages(10)
p.PerPage = 5
```

### Common Patterns

```go
// Get current page items
start, end := m.paginator.GetSliceBounds(len(items))
pageItems := items[start:end]

// Navigation
if m.paginator.OnLastPage() {
    // handle end
}

// In Update - paginator handles arrow keys
m.paginator, cmd = m.paginator.Update(msg)
```

---

## FilePicker

File and directory selection.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/filepicker"

fp := filepicker.New()
fp.CurrentDirectory, _ = os.UserHomeDir()
fp.AllowedTypes = []string{".go", ".md", ".txt"}
fp.ShowHidden = false
```

### Common Patterns

```go
// Check for selection
case tea.KeyMsg:
    m.filepicker, cmd = m.filepicker.Update(msg)

    if didSelect, path := m.filepicker.DidSelectFile(msg); didSelect {
        m.selectedFile = path
        return m, fileSelectedCmd(path)
    }

    if didSelect, path := m.filepicker.DidSelectDisabledFile(msg); didSelect {
        m.err = errors.New("file type not allowed")
    }
```

---

## Timer

Countdown timer with start/stop/reset.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/timer"

t := timer.NewWithInterval(5*time.Minute, time.Second)

// In Init
return t.Init()

// In Update
case timer.TickMsg:
    m.timer, cmd = m.timer.Update(msg)
    return m, cmd

case timer.TimeoutMsg:
    // Timer finished
    return m, nil
```

### Control

```go
// Toggle
cmd := m.timer.Toggle()

// Stop
cmd := m.timer.Stop()

// Start
cmd := m.timer.Start()
```

---

## Stopwatch

Elapsed time counter.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/stopwatch"

sw := stopwatch.NewWithInterval(time.Millisecond * 100)

// In Init
return sw.Init()

// In Update
case stopwatch.TickMsg:
    m.stopwatch, cmd = m.stopwatch.Update(msg)
    return m, cmd
```

---

## Help

Display key bindings to users.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/help"
import "github.com/charmbracelet/bubbles/key"

type keyMap struct {
    Up    key.Binding
    Down  key.Binding
    Quit  key.Binding
}

func (k keyMap) ShortHelp() []key.Binding {
    return []key.Binding{k.Up, k.Down, k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
    return [][]key.Binding{
        {k.Up, k.Down},
        {k.Quit},
    }
}

var keys = keyMap{
    Up: key.NewBinding(
        key.WithKeys("up", "k"),
        key.WithHelp("↑/k", "up"),
    ),
    Down: key.NewBinding(
        key.WithKeys("down", "j"),
        key.WithHelp("↓/j", "down"),
    ),
    Quit: key.NewBinding(
        key.WithKeys("q", "ctrl+c"),
        key.WithHelp("q", "quit"),
    ),
}

h := help.New()

// In View
return h.View(keys)
```

### Expand/Collapse

```go
// Toggle full help
case tea.KeyMsg:
    if msg.String() == "?" {
        m.help.ShowAll = !m.help.ShowAll
    }
```

---

## Key

Key binding definitions for consistent input handling.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/key"

var quitKey = key.NewBinding(
    key.WithKeys("q", "ctrl+c", "esc"),
    key.WithHelp("q", "quit"),
)

// In Update
case tea.KeyMsg:
    if key.Matches(msg, quitKey) {
        return m, tea.Quit
    }
```

### Enable/Disable Bindings

```go
// Disable a binding
quitKey.SetEnabled(false)

// Check if enabled
if quitKey.Enabled() {
    // ...
}
```

---

## Cursor

Text cursor management for custom text inputs.

### Basic Setup

```go
import "github.com/charmbracelet/bubbles/cursor"

c := cursor.New()
c.SetMode(cursor.CursorBlink)

// Modes
cursor.CursorBlink
cursor.CursorStatic
cursor.CursorHide
```

---

## Integration Patterns

### Multiple Components

```go
type Model struct {
    list      list.Model
    spinner   spinner.Model
    help      help.Model
    keys      keyMap
    loading   bool
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd
    var cmd tea.Cmd

    // Always update spinner when loading
    if m.loading {
        m.spinner, cmd = m.spinner.Update(msg)
        cmds = append(cmds, cmd)
    }

    // Update list when not loading
    if !m.loading {
        m.list, cmd = m.list.Update(msg)
        cmds = append(cmds, cmd)
    }

    return m, tea.Batch(cmds...)
}
```

### Component Communication

```go
// Custom message for cross-component communication
type itemSelectedMsg struct {
    item Item
}

// Child component emits message
case tea.KeyMsg:
    if msg.String() == "enter" {
        return m, func() tea.Msg {
            return itemSelectedMsg{m.list.SelectedItem().(Item)}
        }
    }

// Parent handles message
case itemSelectedMsg:
    m.selectedItem = msg.item
    m.state = viewDetail
```

## Review Questions

1. Are components initialized with proper dimensions?
2. Are components updated on WindowSizeMsg?
3. Is focus managed correctly between components?
4. Are component methods used instead of reaching into internals?
5. Are tick messages handled for animated components (spinner, timer)?
