# Patterns & Best Practices

## Contents

- [Slices Pattern (Store Composition)](#slices-pattern-store-composition)
- [Testing & Vitest Store Reset](#testing--vitest-store-reset)
- [Reset Store](#reset-store)
- [Computed Values & Transient Updates](#computed-values--transient-updates)
- [Best Practices & Pitfalls](#best-practices--pitfalls)
- [React Context Dependency Injection (React 19)](#react-context-dependency-injection-react-19)

---

## Slices Pattern (Store Composition)

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

## Testing & Vitest Store Reset

Reset stores between Vitest tests using `store.getInitialState()` so test suites never leak state:

```typescript
// __mocks__/zustand.ts
import { act } from '@testing-library/react'
import { afterEach, vi } from 'vitest'
import type * as ZustandExportedTypes from 'zustand'

export * from 'zustand'

const { create: actualCreate } =
  await vi.importActual<typeof ZustandExportedTypes>('zustand')

export const storeResetFns = new Set<() => void>()

const createUncurried = <T>(
  stateCreator: ZustandExportedTypes.StateCreator<T>
) => {
  const store = actualCreate(stateCreator)
  const initialState = store.getInitialState()
  storeResetFns.add(() => store.setState(initialState, true))
  return store
}

export const create = (<T>(
  stateCreator: ZustandExportedTypes.StateCreator<T>
) => {
  return typeof stateCreator === 'function'
    ? createUncurried(stateCreator)
    : createUncurried
}) as typeof actualCreate

afterEach(() => {
  act(() => {
    storeResetFns.forEach((reset) => reset())
  })
})
```

## Reset Store

```typescript
const useStore = create<State & Actions>()((set, _get, store) => ({
  bears: 0,
  fish: 0,
  reset: () => set(store.getInitialState()),
}))
```

## Computed Values & Transient Updates

Derive computed values inside selectors (using `useShallow` if returning objects/arrays) instead of storing redundant derived fields:

```typescript
const totalFood = useBearStore((s) => s.bears * s.foodPerBear)
```

For high-frequency updates (e.g., scroll/animation coordinates) without triggering React re-renders, subscribe to a ref:

```typescript
function Component() {
  const scratchRef = useRef(useScratchStore.getState().scratches)

  useEffect(
    () =>
      useScratchStore.subscribe((state) => {
        scratchRef.current = state.scratches
      }),
    []
  )
}
```

## Best Practices & Pitfalls

- **Single store per domain** (or split large domains with slices).
- **Colocate actions** inside the store creator rather than scattering external `setState` helpers.
- **Keep selectors stable**: Never return a new arrow function or un-memoized object literal from a selector without `useShallow` (`zustand/react/shallow`).
- **Never mutate state** directly without `immer` middleware (`set((s) => ({ count: s.count + 1 }))`).

## React Context Dependency Injection (React 19)

When scoping a Zustand store per component subtree (e.g., SSR requests or reusable widgets), use `createStore` with typed `createContext<StoreApi | null>(null)`, an explicit `useRef<StoreApi | null>(null)` initial value (required by React 19 `@types/react`), a missing-provider guard, and `useStore`:

```tsx
import { createContext, useContext, useRef, type ReactNode } from 'react'
import { createStore, useStore, type StoreApi } from 'zustand'
import { useShallow } from 'zustand/react/shallow'

interface BearState {
  bears: number
  fish: number
  increase: () => void
}

type BearStoreApi = StoreApi<BearState>

const BearStoreContext = createContext<BearStoreApi | null>(null)

export function BearStoreProvider({
  initialBears = 0,
  children,
}: {
  initialBears?: number
  children: ReactNode
}) {
  const storeRef = useRef<BearStoreApi | null>(null)
  if (!storeRef.current) {
    storeRef.current = createStore<BearState>()((set) => ({
      bears: initialBears,
      fish: 0,
      increase: () => set((s) => ({ bears: s.bears + 1 })),
    }))
  }

  return (
    <BearStoreContext.Provider value={storeRef.current}>
      {children}
    </BearStoreContext.Provider>
  )
}

export function useBearStore<T>(selector: (state: BearState) => T): T {
  const store = useContext(BearStoreContext)
  if (!store) {
    throw new Error('useBearStore must be used within BearStoreProvider')
  }
  return useStore(store, selector)
}

// Multi-field consumer usage with useShallow
export function BearStats() {
  const { bears, fish } = useBearStore(
    useShallow((s) => ({ bears: s.bears, fish: s.fish }))
  )
  return <span>{bears} / {fish}</span>
}
```
