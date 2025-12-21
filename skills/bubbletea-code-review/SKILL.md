---
name: bubbletea-code-review
description: Reviews BubbleTea TUI code for proper Elm architecture, model/update/view patterns, and Lipgloss styling. Use when reviewing terminal UI code using charmbracelet/bubbletea.
---

# BubbleTea Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Model state, message handling | [references/model-update.md](references/model-update.md) |
| View rendering, Lipgloss styling | [references/view-styling.md](references/view-styling.md) |
| Component composition, bubbles | [references/composition.md](references/composition.md) |

## Review Checklist

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

## Critical Patterns

### Model Must Be Immutable

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

### Commands for Async/IO

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

### Styles Defined Once

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

## When to Load References

- Reviewing Update function logic → model-update.md
- Reviewing View function, styling → view-styling.md
- Reviewing component hierarchy → composition.md

## Review Questions

1. Is the model immutable in Update?
2. Are I/O operations done via commands?
3. Are Lipgloss styles defined once, not in View?
4. Is WindowSizeMsg handled for resizing?
5. Are key bindings documented with help.KeyMap?
