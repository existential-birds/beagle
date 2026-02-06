# TypeScript Patterns

## Contents

- [Curried Create Syntax](#curried-create-syntax)
- [Separate State and Actions](#separate-state-and-actions)
- [Extract Store Type](#extract-store-type)
- [Async Actions](#async-actions)
- [Typed Slices with StateCreator](#typed-slices-with-statecreator)
- [Middleware Type Parameters](#middleware-type-parameters)
- [Typed Selectors](#typed-selectors)
- [Custom Equality Functions](#custom-equality-functions)
- [Vanilla Store with Types](#vanilla-store-with-types)

---

## Curried Create Syntax

```typescript
// Required for TypeScript - note the double parentheses
const useStore = create<State>()((set) => ({
  // implementation
}))

// Wrong - type inference fails with middleware
create<State>((set) => ({ ... }))

// Correct
create<State>()((set) => ({ ... }))
```

## Separate State and Actions

```typescript
interface State {
  bears: number
  fish: number
}

interface Actions {
  increase: () => void
  reset: () => void
}

const useStore = create<State & Actions>()((set, get, store) => ({
  bears: 0,
  fish: 0,
  increase: () => set((state) => ({ bears: state.bears + 1 })),
  reset: () => set(store.getInitialState()),
}))
```

## Extract Store Type

```typescript
import { type ExtractState } from 'zustand'

const useBearStore = create((set) => ({
  bears: 3,
  increase: (by: number) => set((s) => ({ bears: s.bears + by })),
}))

// Extract type for reuse
export type BearState = ExtractState<typeof useBearStore>
```

## Async Actions

```typescript
interface State {
  data: Data | null
  loading: boolean
}

interface Actions {
  fetchData: () => Promise<void>
}

const useStore = create<State & Actions>((set) => ({
  data: null,
  loading: false,

  fetchData: async () => {
    set({ loading: true })
    try {
      const response = await fetch('/api/data')
      const data = await response.json()
      set({ data, loading: false })
    } catch (error) {
      set({ loading: false })
    }
  },
}))
```

## Typed Slices with StateCreator

```typescript
import { StateCreator } from 'zustand'

interface BearSlice {
  bears: number
  addBear: () => void
}

interface FishSlice {
  fish: number
  addFish: () => void
}

type BoundStore = BearSlice & FishSlice

const createBearSlice: StateCreator<
  BoundStore,  // Full store type
  [],          // Middleware applied before
  [],          // Middleware applied after
  BearSlice    // This slice's type
> = (set) => ({
  bears: 0,
  addBear: () => set((state) => ({ bears: state.bears + 1 })),
})

const createFishSlice: StateCreator<
  BoundStore,
  [],
  [],
  FishSlice
> = (set) => ({
  fish: 0,
  addFish: () => set((state) => ({ fish: state.fish + 1 })),
})

const useBoundStore = create<BoundStore>()((...a) => ({
  ...createBearSlice(...a),
  ...createFishSlice(...a),
}))
```

## Middleware Type Parameters

```typescript
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'

interface State {
  count: number
  increment: () => void
}

const useStore = create<State>()(
  devtools(
    persist(
      (set) => ({
        count: 0,
        increment: () => set((state) => ({ count: state.count + 1 })),
      }),
      { name: 'count-storage' }
    ),
    { name: 'CountStore' }
  )
)
```

## Typed Selectors

```typescript
interface BearState {
  bears: number
  increase: (by: number) => void
}

const useBearStore = create<BearState>()((set) => ({
  bears: 0,
  increase: (by) => set((state) => ({ bears: state.bears + by })),
}))

// Selector is automatically typed
const bears = useBearStore((state) => state.bears)        // number
const increase = useBearStore((state) => state.increase)  // (by: number) => void
```

## Custom Equality Functions

```typescript
import { createWithEqualityFn } from 'zustand/traditional'
import { shallow } from 'zustand/shallow'

const useStore = createWithEqualityFn<State>()(
  (set) => ({
    // store implementation
  }),
  shallow  // Use shallow comparison by default
)

// Note: For most cases, use useShallow instead
// useShallow is imported from 'zustand/react/shallow' or 'zustand/shallow'
// The former is React-specific, the latter includes both shallow and useShallow
```

## Vanilla Store with Types

```typescript
import { createStore } from 'zustand/vanilla'

interface CounterState {
  count: number
  increment: () => void
  decrement: () => void
}

const counterStore = createStore<CounterState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
}))

// Typed access
const count: number = counterStore.getState().count
```
