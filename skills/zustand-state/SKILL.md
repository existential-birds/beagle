---
name: zustand-state
description: Zustand v5 state management for React and vanilla TypeScript. Use when creating stores with curried create<T>()(...), preventing infinite selector re-renders with useShallow, persisting state with partialize, configuring devtools/immer, or injecting stores via React Context.
---

# Zustand State Management (v5)

Minimal state management — named exports only (v5 removed default exports), React 18/19 compatible, and no global providers required.

## Quick Reference

```typescript
import { create } from 'zustand'

interface BearState {
  bears: number
  increase: (by: number) => void
}

const useBearStore = create<BearState>()((set) => ({
  bears: 0,
  increase: (by) => set((state) => ({ bears: state.bears + by })),
}))

// In component - select only what you need
const bears = useBearStore((state) => state.bears)
const increase = useBearStore((state) => state.increase)
```

## State Updates

```typescript
// Flat updates (auto-merged at one level)
set({ bears: 5 })
set((state) => ({ bears: state.bears + 1 }))

// Nested objects (manual spread required without immer)
set((state) => ({
  nested: { ...state.nested, count: state.nested.count + 1 }
}))

// Replace entire state (no merge)
set({ bears: 0 }, true)
```

## Selectors & Performance (v5 `useShallow`)

In Zustand v5, base `create` no longer accepts a custom equality function as a 2nd argument. Returning a fresh object or array literal from a selector without `useShallow` causes infinite re-renders (`Maximum update depth exceeded`):

```typescript
import { useShallow } from 'zustand/react/shallow'

// Good - subscribes only to bears
const bears = useBearStore((state) => state.bears)

// Bad - rerenders on any state change
const state = useBearStore()

// Bad in v5 - new object every render triggers infinite loop!
// const { bears, fish } = useBearStore((s) => ({ bears: s.bears, fish: s.fish }))

// Good - multiple values with useShallow
const { bears, fish } = useBearStore(
  useShallow((state) => ({ bears: state.bears, fish: state.fish }))
)

// Array destructuring with useShallow
const [bearsVal, fishVal] = useBearStore(
  useShallow((state) => [state.bears, state.fish])
)
```

If you need `createWithEqualityFn`, import it from `'zustand/traditional'` (requires `use-sync-external-store` as a peer dependency in v5).

## Access Outside Components

```typescript
const state = useBearStore.getState()
useBearStore.setState({ bears: 5 })

const unsub = useBearStore.subscribe((state) => console.log(state))
unsub()
```

## Vanilla Store (No React)

```typescript
import { createStore } from 'zustand/vanilla'

const store = createStore<BearState>()((set) => ({
  bears: 0,
  increase: (by) => set((state) => ({ bears: state.bears + by })),
}))

store.getState().bears
store.setState({ bears: 10 })
```

## Additional Documentation

- **Middleware**: See [references/middleware.md](references/middleware.md) for `persist`, `devtools`, `immer`, `subscribeWithSelector`, and SSR hydration
- **Patterns**: See [references/patterns.md](references/patterns.md) for slices, Vitest reset, transient updates, and React 19 Context DI
- **TypeScript**: See [references/typescript.md](references/typescript.md) for curried `create<T>()(...)`, `StateCreator`, `ExtractState`, and `zustand/traditional`

## Key Patterns

| Pattern | When to Use |
|---|---|
| Single selector | One primitive/function slice needed |
| `useShallow` (`zustand/react/shallow`) | Selecting multiple fields as object or tuple |
| `getState()` / `setState()` | Outside React or inside non-hook event handlers |
| `subscribe()` | External systems, transient refs |
| `createStore` (`zustand/vanilla`) | Framework-agnostic or React Context DI stores |

## Gates (persist and devtools)

Before merging code that uses these middlewares (see [references/middleware.md](references/middleware.md) for setup):

1. **`persist`** — **Pass when** persisted keys are explicit (`partialize` or a reviewed full-state snapshot) and the JSON written to storage cannot include auth tokens, API keys, or other secrets.
2. **`devtools` in shipped bundles** — **Pass when** DevTools runs only in development (`enabled: import.meta.env.DEV` or env gate), or you leave a one-line note in the PR explaining why it stays enabled in production.
