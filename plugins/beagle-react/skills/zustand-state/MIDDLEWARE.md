# Middleware

## Persist (localStorage)

```typescript
import { persist, createJSONStorage } from 'zustand/middleware'

const useStore = create<State>()(
  persist(
    (set) => ({
      bears: 0,
      increase: () => set((s) => ({ bears: s.bears + 1 })),
    }),
    {
      name: 'bear-storage',
      storage: createJSONStorage(() => localStorage),
    }
  )
)

// Partial persistence
const useStore = create(
  persist(
    (set) => ({ bears: 0, fish: 0 }),
    {
      name: 'storage',
      partialize: (state) => ({ bears: state.bears }), // only persist bears
    }
  )
)
```

## DevTools

```typescript
import { devtools } from 'zustand/middleware'

const useStore = create<State>()(
  devtools(
    (set) => ({
      bears: 0,
      increase: () => set(
        (s) => ({ bears: s.bears + 1 }),
        undefined,
        'bear/increase'  // Action name for DevTools
      ),
    }),
    { name: 'BearStore' }
  )
)
```

## Immer (Mutable Updates)

```typescript
import { immer } from 'zustand/middleware/immer'

const useStore = create<State>()(
  immer((set) => ({
    nested: { count: 0 },
    increment: () =>
      set((state) => {
        state.nested.count += 1  // mutate directly with immer
      }),
  }))
)
```

## Combine Middleware

```typescript
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import { immer } from 'zustand/middleware/immer'

const useStore = create<State>()(
  devtools(
    persist(
      immer((set) => ({
        // store implementation
      })),
      { name: 'storage' }
    ),
    { name: 'DevToolsName' }
  )
)
```

## SubscribeWithSelector

```typescript
import { subscribeWithSelector } from 'zustand/middleware'

const useStore = create(
  subscribeWithSelector((set) => ({ bears: 0, fish: 0 }))
)

// Subscribe to specific field changes
const unsub = useStore.subscribe(
  (state) => state.bears,
  (bears, prevBears) => console.log(bears, prevBears),
  { fireImmediately: true }
)
```

## Next.js / SSR Hydration

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
const useStore = create(
  persist(
    (set) => ({ data: null }),
    {
      name: 'async-storage',
      storage: createJSONStorage(() => ({
        getItem: async (name) => {
          const value = await asyncStorage.getItem(name)
          return value
        },
        setItem: async (name, value) => {
          await asyncStorage.setItem(name, value)
        },
        removeItem: async (name) => {
          await asyncStorage.removeItem(name)
        },
      })),
    }
  )
)
```
