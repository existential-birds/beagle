# TUI Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.go$'
```

## Step 2: Detect Technologies

```bash
# Detect BubbleTea (required for TUI review)
grep -r "charmbracelet/bubbletea" --include="*.go" -l | head -3

# Detect Lipgloss styling
grep -r "charmbracelet/lipgloss\|lipgloss\.Style" --include="*.go" -l | head -3

# Detect Bubbles components
grep -r "charmbracelet/bubbles\|list\.Model\|textinput\.Model\|viewport\.Model" --include="*.go" -l | head -3

# Detect Wish SSH server
grep -r "charmbracelet/wish\|ssh\.Session" --include="*.go" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '_test\.go$'
```

## Step 3: Load Skills

**Always load:**
- `go-code-review`

**Conditionally load based on detection:**

| Condition | Skill |
|-----------|-------|
| Test files changed | `go-testing-code-review` |
| Wish SSH detected | `wish-ssh-code-review` |

## Step 4: BubbleTea Review Guidelines

### Model/Update/View (Elm Architecture)

- [ ] Model is immutable (Update returns new model)
- [ ] Init returns proper initial command
- [ ] Update handles all message types
- [ ] View is pure function (no side effects)
- [ ] tea.Quit used correctly for exit

### Lipgloss Styling

- [ ] Styles defined once at package level
- [ ] Styles not created in View function
- [ ] Colors use AdaptiveColor for light/dark themes
- [ ] Layout responds to WindowSizeMsg

### Component Composition

- [ ] Sub-component updates propagated
- [ ] WindowSizeMsg passed to resizable components
- [ ] Focus management for multiple components
- [ ] Clear state machine for view transitions

### SSH Server (if applicable)

- [ ] Host keys persisted
- [ ] Graceful shutdown implemented
- [ ] PTY window size passed to TUI
- [ ] Per-session Lipgloss renderer

---

## BubbleTea Code Review Knowledge Base

### Critical Patterns

#### 1. Model Must Be Immutable

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

#### 2. Commands for Async/IO

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

#### 3. Styles Defined Once

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

### Model & Update Patterns

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

#### Init Returns Initial Command

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

#### Update Pattern: Switch on Message Type

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

#### Always Handle WindowSizeMsg

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

#### Sub-Component Updates

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

#### Commands Return Messages

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

#### Tick Commands for Animation

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

#### Batch Multiple Commands

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

### View & Styling Patterns

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

#### Handle Loading/Error States

```go
func (m Model) View() string {
    if m.err != nil {
        return errorStyle.Render(fmt.Sprintf("Error: %v", m.err))
    }
    if m.loading {
        return m.spinner.View() + " Loading..."
    }
    return m.renderContent()
}
```

#### Compose Views Cleanly

```go
func (m Model) View() string {
    var b strings.Builder

    b.WriteString(m.renderHeader())
    b.WriteString("\n")
    b.WriteString(m.renderContent())
    b.WriteString("\n")
    b.WriteString(m.renderFooter())

    return b.String()
}
```

#### Define Styles at Package Level

```go
// BAD - created every render
func (m Model) View() string {
    style := lipgloss.NewStyle().Bold(true)
    return style.Render("Hello")
}

// GOOD - defined once
var (
    titleStyle = lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("205"))

    itemStyle = lipgloss.NewStyle().
        PaddingLeft(2)
)

func (m Model) View() string {
    return titleStyle.Render("Hello")
}
```

#### Use Color Palette

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

#### Responsive Width

```go
func (m Model) View() string {
    // Adjust style based on window width
    doc := lipgloss.NewStyle().
        Width(m.width).
        MaxWidth(m.width)

    return doc.Render(m.content)
}
```

#### Layout with Place and Join

```go
func (m Model) View() string {
    // Horizontal join
    row := lipgloss.JoinHorizontal(
        lipgloss.Top,
        leftPanel.Render(m.menu),
        rightPanel.Render(m.content),
    )

    // Vertical join
    return lipgloss.JoinVertical(
        lipgloss.Left,
        m.header(),
        row,
        m.footer(),
    )
}

// Center content
func (m Model) View() string {
    return lipgloss.Place(
        m.width, m.height,
        lipgloss.Center, lipgloss.Center,
        m.content,
    )
}
```

#### Borders and Padding

```go
var boxStyle = lipgloss.NewStyle().
    Border(lipgloss.RoundedBorder()).
    BorderForeground(lipgloss.Color("63")).
    Padding(1, 2).
    Margin(1)

var selectedStyle = lipgloss.NewStyle().
    Border(lipgloss.DoubleBorder()).
    BorderForeground(lipgloss.Color("205"))
```

#### Selected Item Highlighting

```go
func (m Model) renderItems() string {
    var b strings.Builder
    for i, item := range m.items {
        cursor := "  "
        if i == m.cursor {
            cursor = "▸ "
        }

        style := itemStyle
        if i == m.cursor {
            style = selectedStyle
        }

        b.WriteString(style.Render(cursor + item.Title))
        b.WriteString("\n")
    }
    return b.String()
}
```

#### Help Footer

```go
func (m Model) helpView() string {
    return helpStyle.Render("↑/↓: navigate • enter: select • q: quit")
}

// Or use the help bubble
import "github.com/charmbracelet/bubbles/help"

func (m Model) View() string {
    return m.content + "\n" + m.help.View(m.keys)
}
```

#### Status Bar

```go
var statusStyle = lipgloss.NewStyle().
    Background(lipgloss.Color("235")).
    Foreground(lipgloss.Color("255")).
    Padding(0, 1)

func (m Model) statusBar() string {
    status := fmt.Sprintf("Items: %d | Selected: %d", len(m.items), len(m.selected))
    return statusStyle.Width(m.width).Render(status)
}
```

### Component Composition Patterns

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

#### Initialize Sub-Components

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

#### Update Sub-Components

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

#### Component Interface Pattern

```go
// Component interface for consistent sub-components
type Component interface {
    Init() tea.Cmd
    Update(tea.Msg) (Component, tea.Cmd)
    View() string
    SetSize(width, height int)
}
```

#### Self-Contained Component

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
```

#### State Transitions

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

#### View Routing

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

#### Focus Management

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

#### Tab Navigation

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

### Anti-Patterns to Avoid

#### 1. Side Effects in View

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

#### 2. Blocking in Update

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

#### 3. ANSI Codes Instead of Lipgloss

```go
// BAD - raw ANSI
func (m Model) View() string {
    return "\033[1;31mError\033[0m"
}

// GOOD - Lipgloss
var errorStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("196"))
func (m Model) View() string {
    return errorStyle.Render("Error")
}
```

#### 4. Hardcoded Dimensions

```go
// BAD - ignores terminal size
var boxStyle = lipgloss.NewStyle().Width(80)

// GOOD - responsive
func (m Model) renderBox() string {
    return boxStyle.Width(m.width - 4).Render(m.content)
}
```

#### 5. Not Propagating Updates

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

#### 6. Nested Component Access

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

---

## Step 5: Review

**Sequential (default):**
1. Load applicable skills
2. Review Go code quality
3. Review BubbleTea patterns (Model/Update/View)
4. Review Lipgloss styling
5. Review component composition
6. Review SSH server (if applicable)
7. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn subagents for: Go quality, BubbleTea, SSH
3. Wait for all agents
4. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (UI freeze, crash, resource leak)
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

- Load skills BEFORE reviewing (not after)
- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Pay special attention to:
  - Blocking operations in Update (freezes UI)
  - Style creation in View (performance)
  - Missing WindowSizeMsg handling (broken resize)
- Run verification after fixes
