# Sessions & Security

## Session Handling

### 1. Access Session Info

```go
func handler(s ssh.Session) {
    // User info
    user := s.User()
    remoteAddr := s.RemoteAddr()

    // Public key (if key auth)
    key := s.PublicKey()

    // Environment variables
    env := s.Environ()

    // Command (if not interactive)
    cmd := s.Command()

    // PTY info (if allocated)
    pty, winCh, isPty := s.Pty()
    if isPty {
        width := pty.Window.Width
        height := pty.Window.Height
        _ = winCh
    }
}
```

### 2. Handle Window Resize

```go
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, hasPty := s.Pty()
    width, height := 80, 24
    if hasPty {
        width, height = pty.Window.Width, pty.Window.Height
    }

    model := NewModel(width, height)

    // Window change channel is handled automatically by bubbletea.Middleware
    // In Wish v2 / Bubble Tea v2, configure AltScreen declaratively on tea.View instead of tea.WithAltScreen()
    return model, []tea.ProgramOption{tea.WithAltScreen()}
}
```

### 3. Session State Store

```go
// Store per-session state keyed by session ID and clean up on disconnect
type SessionData struct {
    User      string
    ConnectAt time.Time
    PageViews int
}

var sessionStore sync.Map // map[string]*SessionData

func sessionMiddleware() wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            id := s.Context().SessionID()
            data := &SessionData{
                User:      s.User(),
                ConnectAt: time.Now(),
            }
            sessionStore.Store(id, data)
            defer sessionStore.Delete(id)

            next(s)
        }
    }
}
```

## Security

### 1. Authentication

```go
// Public key authentication
wish.WithPublicKeyAuth(func(ctx ssh.Context, key ssh.PublicKey) bool {
    // Check against authorized keys
    authorized := loadAuthorizedKeys()
    for _, authKey := range authorized {
        if ssh.KeysEqual(key, authKey) {
            return true
        }
    }
    return false
}),

// Password authentication (not recommended for production)
wish.WithPasswordAuth(func(ctx ssh.Context, password string) bool {
    // Never do this - use public key auth
    return password == os.Getenv("SSH_PASSWORD")
}),
```

### 2. Authorization

```go
func authorizationMiddleware(allowedUsers map[string]bool) wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            if !allowedUsers[s.User()] {
                io.WriteString(s, "Access denied\n")
                s.Exit(1)
                return
            }
            next(s)
        }
    }
}
```

### 3. Secure Defaults

```go
s, err := wish.NewServer(
    wish.WithAddress(":22"),
    wish.WithHostKeyPath("./host_key"),

    // Timeouts prevent hung connections
    wish.WithIdleTimeout(10*time.Minute),
    wish.WithMaxTimeout(60*time.Minute),

    // Require public key auth
    wish.WithPublicKeyAuth(authHandler),

    wish.WithMiddleware(
        logging.Middleware(),  // audit trail
        activeterm.Middleware(),
        bubbletea.Middleware(teaHandler),
    ),
)
```

## BubbleTea Integration (Wish v1 vs Wish v2)

Check `go.mod` for `github.com/charmbracelet/wish` (v1) vs `charm.land/wish/v2` (v2):

- **Wish v1 (`charmbracelet/wish`)**: Call `bubbletea.MakeRenderer(s)` and build per-session styles with `renderer.NewStyle()`.
- **Wish v2 (`charm.land/wish/v2`)**: `bubbletea.MakeRenderer(s)` was **removed**. Return `bubbletea.MakeOptions(s)...` in `[]tea.ProgramOption` so client environment/color profile (`tea.EnvMsg`) is forwarded automatically to Bubble Tea v2.

### 1. Basic Handler

```go
// Wish v1 (github.com/charmbracelet/wish/bubbletea)
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, hasPty := s.Pty()
    width, height := 80, 24
    if hasPty {
        width, height = pty.Window.Width, pty.Window.Height
    }

    renderer := bubbletea.MakeRenderer(s)
    model := NewModel(renderer, width, height)

    return model, []tea.ProgramOption{
        tea.WithAltScreen(),
    }
}

// Wish v2 (charm.land/wish/v2/bubbletea)
func teaHandlerV2(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, hasPty := s.Pty()
    width, height := 80, 24
    if hasPty {
        width, height = pty.Window.Width, pty.Window.Height
    }

    model := NewModel(width, height) // handles tea.BackgroundColorMsg for dark/light theme
    return model, bubbletea.MakeOptions(s)
}
```

### 2. Passing Session Info to Model

```go
// Wish v1
type Model struct {
    renderer *lipgloss.Renderer
    user     string
    width    int
    height   int
}

func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, hasPty := s.Pty()
    width, height := 80, 24
    if hasPty {
        width, height = pty.Window.Width, pty.Window.Height
    }

    renderer := bubbletea.MakeRenderer(s)

    model := Model{
        renderer: renderer,
        user:     s.User(),
        width:    width,
        height:   height,
    }

    return model, []tea.ProgramOption{tea.WithAltScreen()}
}
```

### 3. Per-Session Styles (Wish v1)

```go
// In Wish v1, each session needs its own renderer for correct color detection
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    renderer := bubbletea.MakeRenderer(s)

    // Create styles with session's renderer
    styles := NewStyles(renderer)

    model := Model{
        styles: styles,
    }

    return model, nil
}

type Styles struct {
    Title lipgloss.Style
    Item  lipgloss.Style
}

func NewStyles(r *lipgloss.Renderer) Styles {
    return Styles{
        Title: r.NewStyle().Bold(true).Foreground(lipgloss.Color("205")),
        Item:  r.NewStyle().PaddingLeft(2),
    }
}
```

In Wish v2, `bubbletea.MakeOptions(s)` replaces `MakeRenderer` and Bubble Tea v2 automatically detects the remote terminal's color profile and background (`tea.RequestBackgroundColor` / `tea.BackgroundColorMsg`).

## Anti-Patterns

### 1. Ignoring PTY

```go
// BAD - assumes PTY always exists
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, _ := s.Pty()  // may be empty/zero!
    model := NewModel(pty.Window.Width, pty.Window.Height)
}

// GOOD - handle non-PTY connections
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, hasPty := s.Pty()

    width, height := 80, 24  // sensible defaults
    if hasPty {
        width = pty.Window.Width
        height = pty.Window.Height
    }

    model := NewModel(width, height)
    return model, nil
}
```

### 2. Global Lipgloss Styles Without Session Context (Wish v1) / Missing `MakeOptions` (Wish v2)

```go
// BAD (Wish v1) - global styles don't detect terminal capabilities per-session
var titleStyle = lipgloss.NewStyle().Bold(true)

// GOOD (Wish v1) - per-session renderer
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    renderer := bubbletea.MakeRenderer(s)
    titleStyle := renderer.NewStyle().Bold(true)
    // ...
}

// GOOD (Wish v2) - forward SSH session env/options via bubbletea.MakeOptions(s)
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    return NewModel(), bubbletea.MakeOptions(s)
}
```

## Review Questions

1. Is PTY presence (`hasPty`) checked before accessing window size?
2. Is per-session rendering configured (`MakeRenderer` in Wish v1, `MakeOptions` in Wish v2)?
3. Is authentication configured (public key preferred)?
4. Are session timeouts set?
5. Is logging middleware capturing connection info?
