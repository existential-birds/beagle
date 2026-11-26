# Bubbles Component Reference

Reference for Bubbles components (`github.com/charmbracelet/bubbles/*` in v1; `charm.land/bubbles/v2/*` in v2).

> **v1 vs v2 differences:**
> - **Import paths:** `github.com/charmbracelet/bubbles/<pkg>` (v1) → `charm.land/bubbles/v2/<pkg>` (v2).
> - **Key messages:** `tea.KeyMsg` (v1) → `tea.KeyPressMsg` (v2); spacebar `" "` → `"space"`.
> - **Viewport / TextArea sizing:** `vp.Width = w; vp.Height = h` (v1) → `vp.SetWidth(w); vp.SetHeight(h)` (v2).
> - **Top-level `View()`:** `string` (v1) → `tea.View` via `tea.NewView(...)` (v2).

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

```go
// Items must implement list.Item
type item struct {
    title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

l := list.New(items, list.NewDefaultDelegate(), 0, 0)
l.Title = "My List"

// Update list size on window resize
case tea.WindowSizeMsg:
    h, v := docStyle.GetFrameSize()
    m.list.SetSize(msg.Width-h, msg.Height-v)

// Get selected item via method (do NOT reach into internal slice/index)
if i, ok := m.list.SelectedItem().(item); ok {
    return i.title
}
```

---

## Table

Tabular data with column definitions and row selection.

```go
columns := []table.Column{
    {Title: "Name", Width: 20},
    {Title: "Email", Width: 30},
    {Title: "Role", Width: 15},
}

t := table.New(
    table.WithColumns(columns),
    table.WithRows(rows),
    table.WithFocused(true),
    table.WithHeight(10),
)

s := table.DefaultStyles()
s.Header = s.Header.BorderStyle(lipgloss.NormalBorder())
s.Selected = s.Selected.Foreground(lipgloss.Color("229"))
t.SetStyles(s)

// Handle selection (v2: tea.KeyPressMsg; v1: tea.KeyMsg)
case tea.KeyPressMsg:
    switch msg.String() {
    case "enter":
        row := m.table.SelectedRow()
        return m, selectRowCmd(row)
    }
```

---

## Viewport

Scrollable content area for large text or rendered content.

```go
// v1: viewport.New(80, 20) and vp.Width / vp.Height fields
// v2: viewport.New(viewport.WithWidth(80), viewport.WithHeight(20)) and SetWidth / SetHeight methods
case tea.WindowSizeMsg:
    // v1:
    // m.viewport.Width = msg.Width
    // m.viewport.Height = msg.Height - headerHeight - footerHeight
    // v2:
    m.viewport.SetWidth(msg.Width)
    m.viewport.SetHeight(msg.Height - headerHeight - footerHeight)
```

### Anti-Pattern: Mutating Viewport in View

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

## TextInput & TextArea

```go
// TextInput (single line)
ti := textinput.New()
ti.Placeholder = "Enter username"
ti.CharLimit = 32
ti.Width = 20 // v2: SetWidth(20)
ti.Focus()

// TextArea (multi-line)
ta := textarea.New()
ta.Placeholder = "Type your message..."
ta.SetWidth(60)
ta.SetHeight(10)
ta.Focus()

// Resize on WindowSizeMsg
case tea.WindowSizeMsg:
    m.textarea.SetWidth(msg.Width - 4)
    m.textarea.SetHeight(msg.Height - 6)
```

For multiple inputs, call `Blur()` on the previously focused input before calling `Focus()` on the next input.

---

## Spinner & Progress

```go
// Spinner
s := spinner.New()
s.Spinner = spinner.Dot // Line, MiniDot, Jump, Pulse, Points, Globe, Moon, Monkey, Meter, Hamburger

// In Init: return s.Tick
// In Update:
case spinner.TickMsg:
    m.spinner, cmd = m.spinner.Update(msg)
    return m, cmd

// Progress
p := progress.New(progress.WithDefaultGradient())
// Static: p.ViewAs(0.5); Animated: m.progress.SetPercent(0.75) + handle progress.FrameMsg
```

---

## Paginator & FilePicker

```go
// Paginator
start, end := m.paginator.GetSliceBounds(len(items))
pageItems := items[start:end]
m.paginator, cmd = m.paginator.Update(msg)

// FilePicker (v2: tea.KeyPressMsg; v1: tea.KeyMsg)
case tea.KeyPressMsg:
    m.filepicker, cmd = m.filepicker.Update(msg)
    if didSelect, path := m.filepicker.DidSelectFile(msg); didSelect {
        m.selectedFile = path
        return m, fileSelectedCmd(path)
    }
    if didSelect, _ := m.filepicker.DidSelectDisabledFile(msg); didSelect {
        m.err = errors.New("file type not allowed")
    }
```

---

## Timer & Stopwatch

```go
// Timer: Init returns t.Init(); Update handles timer.TickMsg and timer.TimeoutMsg
case timer.TickMsg:
    m.timer, cmd = m.timer.Update(msg)
    return m, cmd
case timer.TimeoutMsg:
    return m, nil

// Stopwatch: Init returns sw.Init(); Update handles stopwatch.TickMsg
case stopwatch.TickMsg:
    m.stopwatch, cmd = m.stopwatch.Update(msg)
    return m, cmd
```

---

## Help & Key

```go
type keyMap struct {
    Up   key.Binding
    Down key.Binding
    Quit key.Binding
}

func (k keyMap) ShortHelp() []key.Binding  { return []key.Binding{k.Up, k.Down, k.Quit} }
func (k keyMap) FullHelp() [][]key.Binding { return [][]key.Binding{{k.Up, k.Down}, {k.Quit}} }

var keys = keyMap{
    Up:   key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
    Down: key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
    Quit: key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
}

// Toggle full help & quit (v2: tea.KeyPressMsg; v1: tea.KeyMsg)
case tea.KeyPressMsg:
    switch {
    case key.Matches(msg, keys.Quit):
        return m, tea.Quit
    case msg.String() == "?":
        m.help.ShowAll = !m.help.ShowAll
    }
```

---

## Integration Patterns

### Multiple Components

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd
    var cmd tea.Cmd

    if m.loading {
        m.spinner, cmd = m.spinner.Update(msg)
        cmds = append(cmds, cmd)
    } else {
        m.list, cmd = m.list.Update(msg)
        cmds = append(cmds, cmd)
    }

    return m, tea.Batch(cmds...)
}
```

### Component Communication

```go
type itemSelectedMsg struct {
    item Item
}

// Child component emits message (v2: tea.KeyPressMsg; v1: tea.KeyMsg)
case tea.KeyPressMsg:
    if msg.String() == "enter" {
        if selected, ok := m.list.SelectedItem().(Item); ok {
            return m, func() tea.Msg {
                return itemSelectedMsg{selected}
            }
        }
    }

// Parent handles message
case itemSelectedMsg:
    m.selectedItem = msg.item
    m.state = viewDetail
```

## Review Questions

1. Are components initialized with proper dimensions?
2. Are components updated on WindowSizeMsg (using `SetWidth`/`SetHeight` in v2)?
3. Is focus managed correctly between components?
4. Are component methods used instead of reaching into internals?
5. Are tick messages handled for animated components (spinner, timer, stopwatch)?
