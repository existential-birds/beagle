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
    }
}
```

### 2. Handle Window Resize

```go
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, winCh, _ := s.Pty()

    model := NewModel(pty.Window.Width, pty.Window.Height)

    // Window change channel is passed via activeterm middleware
    // BubbleTea handles this automatically when using bubbletea.Middleware

    return model, []tea.ProgramOption{tea.WithAltScreen()}
}
```

### 3. Session Context for State

```go
// Store per-session state using context
type contextKey string

const sessionDataKey contextKey = "sessionData"

type SessionData struct {
    User      string
    ConnectAt time.Time
    PageViews int
}

func sessionMiddleware() wish.Middleware {
    return func(next ssh.Handler) ssh.Handler {
        return func(s ssh.Session) {
            data := &SessionData{
                User:      s.User(),
                ConnectAt: time.Now(),
            }
            ctx := context.WithValue(s.Context(), sessionDataKey, data)
            // Note: wish.Session doesn't expose SetContext
            // Store in sync.Map keyed by session ID instead
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

## BubbleTea Integration

### 1. Basic Handler

```go
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, _ := s.Pty()

    renderer := bubbletea.MakeRenderer(s)
    model := NewModel(renderer, pty.Window.Width, pty.Window.Height)

    return model, []tea.ProgramOption{
        tea.WithAltScreen(),
    }
}
```

### 2. Passing Session to Model

```go
type Model struct {
    renderer *lipgloss.Renderer
    user     string
    width    int
    height   int
}

func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, _ := s.Pty()
    renderer := bubbletea.MakeRenderer(s)

    model := Model{
        renderer: renderer,
        user:     s.User(),
        width:    pty.Window.Width,
        height:   pty.Window.Height,
    }

    return model, []tea.ProgramOption{tea.WithAltScreen()}
}
```

### 3. Per-Session Styles

```go
// Each session needs its own renderer for correct color detection
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

## Anti-Patterns

### 1. Ignoring PTY

```go
// BAD - assumes PTY always exists
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    pty, _, _ := s.Pty()  // may be nil!
    model := NewModel(pty.Window.Width, pty.Window.Height)  // panic!
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

### 2. Global Lipgloss Styles

```go
// BAD - global styles don't detect terminal capabilities per-session
var titleStyle = lipgloss.NewStyle().Bold(true)

// GOOD - per-session renderer
func teaHandler(s ssh.Session) (tea.Model, []tea.ProgramOption) {
    renderer := bubbletea.MakeRenderer(s)
    titleStyle := renderer.NewStyle().Bold(true)
    // ...
}
```

## Review Questions

1. Is PTY presence checked before accessing window size?
2. Are per-session renderers used for Lipgloss?
3. Is authentication configured (public key preferred)?
4. Are session timeouts set?
5. Is logging middleware capturing connection info?
