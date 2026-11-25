---
name: liveview-code-review
description: Reviews Phoenix LiveView code for lifecycle patterns, assigns/streams usage, components, and security. Use when reviewing LiveView modules, .heex templates, or LiveComponents.
---

# LiveView Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| mount, handle_params, handle_event, handle_async | [references/lifecycle.md](references/lifecycle.md) |
| When to use assigns vs streams, AsyncResult | [references/assigns-streams.md](references/assigns-streams.md) |
| Function vs LiveComponent, slots, attrs | [references/components.md](references/components.md) |
| `live_session`, `on_mount`, event auth, `phx-value` trust | [references/security.md](references/security.md) |

## Review Checklist

### Critical Issues
- [ ] No socket copying into async functions (`start_async/3`, `assign_async/3`, `stream_async/4`, or `Task`) — extract primitives first
- [ ] WebSocket auth enforced via `live_session` + `on_mount` hooks (HTTP plugs do not re-run on `push_navigate`)
- [ ] Every `handle_event/3` validates authorization / `current_scope`
- [ ] No sensitive data in assigns (visible in DOM payloads, crash reports, logs)
- [ ] `phx-value-*` data is validated (user-modifiable in DevTools)

### Lifecycle
- [ ] Subscriptions wrapped in `connected?(socket)`
- [ ] `handle_params/3` used for URL-based state
- [ ] `start_async/3` + `handle_async/3` (or `assign_async`/`stream_async`) preferred over raw `Task.async`
- [ ] Async UI handles `:loading`, `:failed` (`{:error, _}` and `{:exit, _}`), and ok states

### Data Management
- [ ] Streams (`stream/4`, `stream_async/4` in LiveView 1.1+) used for large or unbounded collections (superseding `temporary_assigns` for lists)
- [ ] Forms use `to_form(changeset)` + `<.form for={@form}>`, not raw `@changeset`
- [ ] `AsyncResult` patterns for loading states

### Components
- [ ] Function components preferred over LiveComponents
- [ ] LiveComponents preserve `:inner_block` in `update/2`
- [ ] Slots use proper `attr`/`slot` declarations
- [ ] `phx-debounce` on text inputs that trigger server events

## Valid Patterns (Do NOT Flag)

- **Empty `mount/3` returning `{:ok, socket}`** - Valid for simple LiveViews
- **LiveView 1.0+ `{...}` curly-brace HEEx interpolation** - `{@user.name}` in text/attribute positions is standard alongside `<%= ... %>`
- **Using assigns for small lists** - Streams are mainly needed for 100+ items or unbounded feeds
- **LiveComponent without `update/2`** - Default `update/2` assigns all
- **`phx-click` without `phx-value`** - Event may not need data
- **Inline function in HEEx** - Valid for simple transforms

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|-------|--------------|
| Missing debounce | Input is text/textarea AND triggers server event |
| Use streams | Collection has 100+ items OR is unbounded/paginated |
| Missing auth check | Route/event is not public AND no `live_session`/`on_mount` auth AND no event auth check |

## Critical Anti-Patterns

### Socket Copying (MOST IMPORTANT)

Prefer `start_async/3` + `handle_async/3` (or `assign_async/3` / `stream_async/4`) over raw `Task.async/1`, and extract only required primitive values before spawning so the entire `socket` struct is never copied across processes:

```elixir
# BAD - entire socket copied into async closure
def handle_event("load", _, socket) do
  {:noreply,
   start_async(socket, :load, fn ->
     user = socket.assigns.current_user  # Entire socket copied!
     fetch_data(user.id)
   end)}
end

# GOOD - extract primitives first, handle via start_async/handle_async
def handle_event("load", _, socket) do
  user_id = socket.assigns.current_user.id

  {:noreply,
   start_async(socket, :load, fn ->
     fetch_data(user_id)  # Only primitive copied
   end)}
end
```

### Missing Authorization

```elixir
# BAD - trusts phx-value without auth
def handle_event("delete", %{"id" => id}, socket) do
  Posts.delete_post!(id)  # Anyone can delete any post!
  {:noreply, socket}
end

# GOOD - scope/authorize inside event and context
def handle_event("delete", %{"id" => id}, socket) do
  post = Posts.get_post!(id)

  if post.user_id == socket.assigns.current_user.id do
    {:ok, _} = Posts.delete_post(post)
    {:noreply, stream_delete(socket, :posts, post)}
  else
    {:noreply, put_flash(socket, :error, "Unauthorized")}
  end
end
```

## Hard gates (sequence)

Advance only when each **pass condition** is objectively true (prevents reporting without evidence):

| Gate | Pass condition |
|------|----------------|
| **G1 — Files in evidence** | You have an explicit list of paths under review (e.g. `*.ex`, `*.heex`, or the paths the user named). **Every** finding names a file from that list. |
| **G2 — Verification protocol** | You loaded the `review-verification-protocol` skill ([review-verification-protocol](../review-verification-protocol/SKILL.md)) and applied its Pre-Report Verification (and issue-type sections where relevant) **before** treating something as a finding. |
| **G3 — Line anchors** | Each finding uses `[FILE:LINE]` where that line exists in the current file (confirmed by read/grep output, not inferred). |
| **G4 — Valid-pattern screen** | You checked the finding against **Valid Patterns (Do NOT Flag)** and **Context-Sensitive Rules**; if it matches a “do not flag” case or fails a “Flag ONLY IF,” you **do not** report it. |

## Issue format

Use `[FILE:LINE] ISSUE_TITLE` for each finding.
