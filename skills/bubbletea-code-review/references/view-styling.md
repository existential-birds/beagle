# View & Styling

## View Function

### 1. View Must Be Pure

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

### 2. Handle Loading/Error States

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

### 3. Compose Views Cleanly

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

## Lipgloss Styling

### 1. Define Styles at Package Level

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

### 2. Use Color Palette

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

### 3. Adaptive Colors for Themes

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

### 4. Responsive Width

```go
func (m Model) View() string {
    // Adjust style based on window width
    doc := lipgloss.NewStyle().
        Width(m.width).
        MaxWidth(m.width)

    return doc.Render(m.content)
}
```

### 5. Layout with Place and Join

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

### 6. Borders and Padding

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

## Common Patterns

### Selected Item Highlighting

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

### Help Footer

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

### Status Bar

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

## Anti-Patterns

### 1. ANSI Codes Instead of Lipgloss

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

### 2. Hardcoded Dimensions

```go
// BAD - ignores terminal size
var boxStyle = lipgloss.NewStyle().Width(80)

// GOOD - responsive
func (m Model) renderBox() string {
    return boxStyle.Width(m.width - 4).Render(m.content)
}
```

## Review Questions

1. Is View a pure function with no side effects?
2. Are styles defined once, not in View?
3. Are colors using AdaptiveColor for light/dark themes?
4. Is layout responsive to WindowSizeMsg?
5. Are lipgloss.Join/Place used for layout composition?
