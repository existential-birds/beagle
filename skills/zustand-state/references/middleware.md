# Middleware

## Contents

- [Persist (localStorage)](#persist-localstorage)
- [DevTools](#devtools)
- [Immer (Mutable Updates)](#immer-mutable-updates)
- [Combine Middleware](#combine-middleware)
- [SubscribeWithSelector](#subscribewithselector)
- [Next.js / SSR Hydration](#nextjs--ssr-hydration)
- [Async Persistence](#async-persistence)

---

## Persist (localStorage)

Always prefer explicit `partialize` so transient UI flags or sensitive tokens are never serialized to `localStorage`:

```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface BearState {
  bears: number
  fish: number
  increase: () => void
}

const useBearStore = create<BearState>()(
  persist(
    (set) => ({
      bears: 0,
      fish: 0,
      increase: () => set((s) => ({ bears: s.bears + 1 })),
    }),
    {
      name: 'bear-storage',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({ bears: state.bears }), // Only persist explicit keys
    }
  )
)
```

## DevTools

Gate DevTools to development environments unless production debugging is explicitly intended:

```typescript
import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

const useBearStore = create<BearState>()(
  devtools(
    (set) => ({
      bears: 0,
      fish: 0,
      increase: () =>
        set(
          (s) => ({ bears: s.bears + 1 }),
          undefined,
          'bear/increase' // Action name for DevTools
        ),
    }),
    { name: 'BearStore', enabled: import.meta.env.DEV }
  )
)
```

## Immer (Mutable Updates)

```typescript
import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

interface NestedState {
  nested: { count: number }
  increment: () => void
}

const useNestedStore = create<NestedState>()(
  immer((set) => ({
    nested: { count: 0 },
    increment: () =>
      set((state) => {
        state.nested.count += 1 // Safe direct mutation via Immer
      }),
  }))
)
```

## Combine Middleware

Apply `devtools` outside `persist` and `immer` inside:

```typescript
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import { immer } from 'zustand/middleware/immer'

const useStore = create<NestedState>()(
  devtools(
    persist(
      immer((set) => ({
        nested: { count: 0 },
        increment: () =>
          set((state) => {
            state.nested.count += 1
          }),
      })),
      { name: 'storage', partialize: (s) => ({ nested: s.nested }) }
    ),
    { name: 'AppStore', enabled: import.meta.env.DEV }
  )
)
```

## SubscribeWithSelector

```typescript
import { create } from 'zustand'
import { subscribeWithSelector } from 'zustand/middleware'

interface CountState {
  bears: number
  fish: number
}

const useCountStore = create<CountState>()(
  subscribeWithSelector(() => ({ bears: 0, fish: 0 }))
)

// Subscribe to specific field changes outside React
const unsub = useCountStore.subscribe(
  (state) => state.bears,
  (bears, prevBears) => console.log(bears, prevBears),
  { fireImmediately: true }
)
```

## Next.js / SSR Hydration

Wait for client storage rehydration before rendering persisted values that would otherwise mismatch SSR markup:

```typescript
import { useEffect, useState } from 'react'

const useHydration = () => {
  const [hydrated, setHydrated] = useState(false)

  useEffect(() => {
    setHydrated(useBearStore.persist.hasHydrated())
    return useBearStore.persist.onFinishHydration(() => setHydrated(true))
  }, [])

  return hydrated
}

function Component() {
  const hydrated = useHydration()
  const bears = useBearStore((state) => state.bears)

  if (!hydrated) return <div>Loading...</div>
  return <div>{bears} bears</div>
}
```

## Async Persistence

```typescript
interface AsyncDataState {
  data: string | null
}

const useAsyncStore = create<AsyncDataState>()(
  persist(
    () => ({ data: null }),
    {
      name: 'async-storage',
      storage: createJSONStorage(() => ({
        getItem: async (name) => asyncStorage.getItem(name),
        setItem: async (name, value) => asyncStorage.setItem(name, value),
        removeItem: async (name) => asyncStorage.removeItem(name),
      })),
    }
  )
)
```
