---
name: elixir-performance-review
description: Reviews Elixir code for performance issues including GenServer bottlenecks, memory usage, and concurrency patterns. Use when reviewing high-throughput code or investigating performance issues.
---

# Elixir Performance Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| Mailbox overflow, blocking calls | [references/genserver-bottlenecks.md](references/genserver-bottlenecks.md) |
| When to use ETS, read/write concurrency | [references/ets-patterns.md](references/ets-patterns.md) |
| Binary handling, large messages | [references/memory.md](references/memory.md) |
| Task patterns, flow control | [references/concurrency.md](references/concurrency.md) |

## Review Checklist

### GenServer
- [ ] Not a single-process bottleneck for all requests
- [ ] No blocking operations in handle_call/cast
- [ ] Proper timeout configuration
- [ ] Consider ETS for read-heavy state

### Memory
- [ ] Large binaries not copied between processes
- [ ] Streams used for large data transformations
- [ ] No unbounded data accumulation

### Concurrency
- [ ] Task.Supervisor for dynamic tasks (not raw Task.async)
- [ ] No unbounded process spawning
- [ ] Proper backpressure for message producers

### Database
- [ ] Preloading to avoid N+1 queries
- [ ] Pagination for large result sets
- [ ] Indexes for frequent queries

## Valid Patterns (Do NOT Flag)

- **Single GenServer for low-throughput** - Not all state needs horizontal scaling
- **Synchronous calls for critical paths** - Consistency may require it
- **In-memory state without ETS** - ETS has overhead for small state
- **Enum over Stream for small collections** - Stream overhead not worth it

## Context-Sensitive Rules

| Issue | Flag ONLY IF |
|-------|--------------|
| GenServer bottleneck | Handles > 1000 req/sec OR blocking I/O in callbacks |
| Use streams | Processing > 10k items OR reading large files |
| Use ETS | Read:write ratio > 10:1 AND concurrent access |

## Gates — before reporting

Do these **in order**, once for the performance review. Budget: max **1** pass. Stop when each step has a recorded outcome for the finding list. Tie-break: ship the remainder as **suspected**, or drop them — do not re-run the gates.

1. **Protocol loaded** — Load `beagle-core:review-verification-protocol` **once**, at review entry, plus this plugin's [Elixir delta](../elixir-verification-protocol/SKILL.md). Apply its Pre-Report Verification Checklist (and its "Performance Issue" section) to the finding list as a whole. Reporting is `beagle-core:verification-budget` tier REVERSIBLE — no per-finding recitation of which subsection you satisfied.
2. **Anchored evidence** — Each finding includes a concrete locator: `path:line` (or line range), or `Module.function/arity` plus a short quoted snippet from the file.
3. **Performance claims** — For anything under [Context-Sensitive Rules](#context-sensitive-rules), or any claim of bottleneck, N+1, unbounded growth, or heavy memory/binary cost, state the **observed or measured** fact that meets “Flag ONLY IF” (e.g. rate, item count, ratio), or attach an artifact (profiler output, SQL/log excerpt, `grep`/search scope)—otherwise downgrade to **question** / **suspected** with what was not verified.

## Before Submitting Findings

Record an outcome for each of **Gates — before reporting** above, then ship.
