# Patterns & Best Practices

## Contents

- [Slices Pattern (Store Composition)](#slices-pattern-store-composition)
- [TypeScript Slices](#typescript-slices)
- [Testing](#testing)
  - [Mock Store Setup (Vitest)](#mock-store-setup-vitest)
  - [Component Tests](#component-tests)
- [Reset Store](#reset-store)
- [Computed Values (Derived State)](#computed-values-derived-state)
- [Transient Updates (No Rerender)](#transient-updates-no-rerender)
- [Best Practices](#best-practices)
  - [Single Store Per Domain](#single-store-per-domain)
  - [Colocate Actions](#colocate-actions)
  - [Selector Stability](#selector-stability)
- [Pitfalls to Avoid](#pitfalls-to-avoid)
  - [Don't Mutate State](#dont-mutate-state)
  - [Avoid Fetching Entire Store](#avoid-fetching-entire-store)
  - [React Context (Dependency Injection)](#react-context-dependency-injection)

---

## Slices Pattern (Store Composition)

```typescript
// fishSlice.ts
const createFishSlice = (set) => ({
  fish: 0,
  addFish: () => set((state) => ({ fish: state.fish + 1 })),
})

// bearSlice.ts
const createBearSlice = (set) => ({
  bears: 0,
  addBear: () => set((state) => ({ bears: state.bears + 1 })),
})

// Combined store
import { create } from 'zustand'

const useBoundStore = create((...a) => ({
  ...createBearSlice(...a),
  ...createFishSlice(...a),
}))
```

## TypeScript Slices

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

const createBearSlice: StateCreator<
  BearSlice & FishSlice,
  [],
  [],
  BearSlice
> = (set) => ({
  bears: 0,
  addBear: () => set((state) => ({ bears: state.bears + 1 })),
})

const useBoundStore = create<BearSlice & FishSlice>()((...a) => ({
  ...createBearSlice(...a),
  ...createFishSlice(...a),
}))
```

## Testing

### Mock Store Setup (Vitest)

```typescript
// __mocks__/zustand.ts
import { act } from '@testing-library/react'
import type * as ZustandExportedTypes from 'zustand'

export * from 'zustand'

const { create: actualCreate } =
  await vi.importActual<typeof ZustandExportedTypes>('zustand')

export const storeResetFns = new Set<() => void>()

export const create = (<T>(stateCreator) => {
  const store = actualCreate(stateCreator)
  const initialState = store.getInitialState()
  storeResetFns.add(() => store.setState(initialState, true))
  return store
}) as typeof actualCreate

afterEach(() => {
  act(() => storeResetFns.forEach((fn) => fn()))
})
```

### Component Tests

```typescript
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

test('increments count', async () => {
  const user = userEvent.setup()
  render(<Counter />)

  expect(await screen.findByText('0')).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: /increment/i }))
  expect(await screen.findByText('1')).toBeInTheDocument()
})

test('reads store directly', () => {
  expect(useCountStore.getState().count).toBe(0)
})
```

## Reset Store

```typescript
const useStore = create<State & Actions>()((set, get, store) => ({
  bears: 0,
  fish: 0,
  reset: () => set(store.getInitialState()),
}))
```

## Computed Values (Derived State)

```typescript
// Don't store computed values - derive in selectors
const totalFood = useBearStore((s) => s.bears * s.foodPerBear)

// Or in the component
const totalFood = bears * foodPerBear
```

## Transient Updates (No Rerender)

```typescript
function Component() {
  const scratchRef = useRef(useScratchStore.getState().scratches)

  useEffect(() =>
    useScratchStore.subscribe(
      (state) => { scratchRef.current = state.scratches }
    ), []
  )

  // Use scratchRef.current without causing rerenders
}
```

## Best Practices

### Single Store Per Domain
Use one store for each domain (user, cart, ui). Split large stores with slices.

### Colocate Actions
```typescript
// Good - actions in store
const useStore = create((set) => ({
  count: 0,
  increment: () => set((s) => ({ count: s.count + 1 })),
}))

// Avoid - external actions
const increment = () => useStore.setState((s) => ({ count: s.count + 1 }))
```

### Selector Stability
```typescript
// Bad - creates new function every render
const action = useBearStore((state) => () => state.increase(1))

// Good - select function directly
const increase = useBearStore((state) => state.increase)
```

## Pitfalls to Avoid

### Don't Mutate State
```typescript
// Wrong
set((state) => {
  state.count += 1  // Mutation!
  return state
})

// Correct (without immer)
set((state) => ({ count: state.count + 1 }))
```

### Avoid Fetching Entire Store
```typescript
// Bad - rerenders on any change
const { bears, fish, cats } = useBearStore()

// Good - subscribe only to needed values
const bears = useBearStore((state) => state.bears)
```

### React Context (Dependency Injection)

```typescript
import { createContext, useContext, useRef } from 'react'
import { createStore, useStore } from 'zustand'

const StoreContext = createContext(null)

const StoreProvider = ({ children }) => {
  const storeRef = useRef()
  if (!storeRef.current) {
    storeRef.current = createStore((set) => ({
      bears: 0,
      increase: () => set((s) => ({ bears: s.bears + 1 })),
    }))
  }
  return (
    <StoreContext.Provider value={storeRef.current}>
      {children}
    </StoreContext.Provider>
  )
}

const useBearStore = (selector) => {
  const store = useContext(StoreContext)
  return useStore(store, selector)
}
```
