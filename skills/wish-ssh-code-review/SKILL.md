---
name: wish-ssh-code-review
description: Reviews Wish SSH server code for proper middleware, session handling, and security patterns. Use when reviewing SSH server code using charmbracelet/wish or charm.land/wish/v2.
---

# Wish SSH Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Server setup, middleware | [references/server.md](references/server.md) |
| Session handling, security | [references/sessions.md](references/sessions.md) |

## Review gates

Run these **in order** when producing a written review. Do not claim a defect in a later step until the **Pass when** for the current step is satisfied for the code under review.

1. **Locate Wish entry points** — **Pass when:** you have at least one repo path per server surface that calls `wish.NewServer`, `wish.WithMiddleware`, registers `bubbletea.Middleware`, or defines the top-level `ssh.Handler` chain (list the paths explicitly). Check `go.mod` to confirm Wish v1 (`github.com/charmbracelet/wish`) vs Wish v2 (`charm.land/wish/v2`).
2. **Capture server-setup evidence** — **Pass when:** for each path from step 1, you have the actual `wish.WithHostKey*` / host-key configuration and the **full middleware list in source order** as written (not recalled from memory). If graceful shutdown exists, note the file(s) where `ListenAndServe` and `Shutdown` run.
3. **Capture session / TUI evidence** — **Pass when:** for each `teaHandler` (or equivalent), you have noted from source whether `s.Pty()`'s `hasPty` bool is checked before using window size, and whether per-session terminal rendering is configured (`bubbletea.MakeRenderer(s)` in Wish v1; `bubbletea.MakeOptions(s)` + automatic color profile in Wish v2).
4. **Write findings** — **Pass when:** each finding uses `[FILE:LINE] ISSUE_TITLE` (line range allowed where needed) and points to the relevant row in **Quick Reference** (or the matching section in `references/`).

## Review Checklist

Use alongside **Review gates**; for a written review, complete the gates first so each item below can be tied to cited source.

- [ ] Host keys are loaded from file or generated securely
- [ ] Middleware order is correct (logging first, auth early); `WithIdleTimeout`/`WithMaxTimeout` passed to `wish.NewServer`, not `wish.WithMiddleware`
- [ ] Session context or session-scoped store is used for per-connection state
- [ ] Graceful shutdown handles active sessions
- [ ] PTY requests (`hasPty`) are checked before reading window dimensions
- [ ] Connection limits prevent resource exhaustion
- [ ] Timeouts prevent hung connections
- [ ] BubbleTea middleware correctly configured for Wish v1 vs v2

## Critical Patterns

### Server Setup

```go
// GOOD - complete server setup
s, err := wish.NewServer(
    wish.WithAddress(fmt.Sprintf("%s:%d", host, port)),
    wish.WithHostKeyPath(".ssh/id_ed25519"),
    wish.WithIdleTimeout(10*time.Minute),
    wish.WithMaxTimeout(30*time.Minute),
    wish.WithMiddleware(
        logging.Middleware(),       // first: log all connections
        activeterm.Middleware(),    // handle terminal sizing
        bubbletea.Middleware(teaHandler),
    ),
)
if err != nil {
    return fmt.Errorf("creating server: %w", err)
}
```

### Graceful Shutdown

```go
// BAD - abrupt shutdown
log.Fatal(s.ListenAndServe())

// GOOD - graceful shutdown
done := make(chan os.Signal, 1)
signal.Notify(done, os.Interrupt, syscall.SIGTERM)

go func() {
    if err := s.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
        log.Error("server error", "error", err)
    }
}()

<-done
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
if err := s.Shutdown(ctx); err != nil {
    log.Error("shutdown error", "error", err)
}
```

### BubbleTea Handler

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
        tea.WithMouseCellMotion(),
    }
}

// Wish v2 (charm.land/wish/v2/bubbletea): MakeRenderer was removed;
// use bubbletea.MakeOptions(s) and declarative tea.View fields (AltScreen, MouseMode) in View().
```

## When to Load References

- Reviewing server initialization → server.md
- Reviewing authentication, session state → sessions.md

## Review Questions

1. Are host keys handled securely?
2. Is middleware order correct?
3. Is graceful shutdown implemented?
4. Is `hasPty` checked before reading PTY window sizes?
5. Are connection timeouts configured on `wish.NewServer`?
