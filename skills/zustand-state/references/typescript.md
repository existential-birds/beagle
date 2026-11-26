# TypeScript Patterns (Zustand v5)

## Contents

- [Curried Create Syntax](#curried-create-syntax)
- [Separate State and Actions](#separate-state-and-actions)
- [Extract Store Type](#extract-store-type)
- [Async Actions](#async-actions)
- [Typed Slices with StateCreator](#typed-slices-with-statecreator)
- [Middleware Type Parameters](#middleware-type-parameters)
- [Typed Selectors & `useShallow`](#typed-selectors--useshallow)
- [Legacy Custom Equality (`zustand/traditional`)](#legacy-custom-equality-zustandtraditional)
- [Vanilla Store with Types](#vanilla-store-with-types)

---

## Curried Create Syntax

Always use the curried double-parentheses form `create<State>()(...)` so middleware mutators (`devtools`, `persist`, `immer`) infer types properly:

```typescript
import { create } from 'zustand'

interface CounterState {
  count: number
  inc: () => void
}

// Correct - curried double parentheses
const useStore = create<CounterState>()((set) => ({
  count: 0,
  inc: () => set((s) => ({ count: s.count + 1 })),
}))
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

const useStore = create<State & Actions>()((set, _get, store) => ({
  bears: 0,
  fish: 0,
  increase: () => set((state) => ({ bears: state.bears + 1 })),
  reset: () => set(store.getInitialState()),
}))
```

## Extract Store Type

```typescript
import { create, type ExtractState } from 'zustand'
import { combine } from 'zustand/middleware'

const useBearStore = create(
  combine({ bears: 3 }, (set) => ({
    increase: (by: number) => set((s) => ({ bears: s.bears + by })),
  }))
)

export type BearState = ExtractState<typeof useBearStore>
```

## Async Actions

```typescript
interface Data {
  id: string
}

interface State {
  data: Data | null
  loading: boolean
}

interface Actions {
  fetchData: () => Promise<void>
}

const useStore = create<State & Actions>()((set) => ({
  data: null,
  loading: false,

  fetchData: async () => {
    set({ loading: true })
    try {
      const response = await fetch('/api/data')
      const data = (await response.json()) as Data
      set({ data, loading: false })
    } catch {
      set({ loading: false })
    }
  },
}))
```

## Typed Slices with `StateCreator`

```typescript
import { create, type StateCreator } from 'zustand'

interface BearSlice {
  bears: number
  addBear: () => void
}

interface FishSlice {
  fish: number
  addFish: () => void
}

type BoundStore = BearSlice & FishSlice

const createBearSlice: StateCreator<BoundStore, [], [], BearSlice> = (set) => ({
  bears: 0,
  addBear: () => set((state) => ({ bears: state.bears + 1 })),
})

const createFishSlice: StateCreator<BoundStore, [], [], FishSlice> = (set) => ({
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
      { name: 'count-storage', partialize: (s) => ({ count: s.count }) }
    ),
    { name: 'CountStore' }
  )
)
```

## Typed Selectors & `useShallow`

```typescript
import { useShallow } from 'zustand/react/shallow'

const bears = useBearStore((state) => state.bears) // number

// Object/array selectors in Zustand v5 MUST wrap with useShallow
const { bears: count, increase } = useBearStore(
  useShallow((state) => ({ bears: state.bears, increase: state.increase }))
)
```

## Legacy Custom Equality (`zustand/traditional`)

In Zustand v5, `create` no longer accepts an equality function as a second argument. If migrating a codebase that relies on a store-wide custom equality function (like `shallow`), use `createWithEqualityFn` from `zustand/traditional` and ensure `use-sync-external-store` is installed (required peer dependency in v5):

```typescript
import { createWithEqualityFn } from 'zustand/traditional'
import { shallow } from 'zustand/shallow'

const useStore = createWithEqualityFn<State>()(
  (set) => ({
    // store implementation
  }),
  shallow
)
```

For new code, prefer `create<State>()(...)` paired with `useShallow` from `'zustand/react/shallow'`.

## Vanilla Store with Types

```typescript
import { createStore } from 'zustand/vanilla'

interface CounterState {
  count: number
  increment: () => void
  decrement: () => void
}

const counterStore = createStore<CounterState>()((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
}))

const count: number = counterStore.getState().count
```
