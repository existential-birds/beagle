# Mocking Patterns

## Contents

- [Hoisted Variables (`vi.hoisted`)](#hoisted-variables-vihoisted)
- [Module Mocking](#module-mocking)
- [Function Mocking](#function-mocking)
- [Mock Assertions](#mock-assertions)
- [Spying](#spying)
- [Mock Cleanup](#mock-cleanup)
- [Mock Methods Quick Reference](#mock-methods-quick-reference)

---

## Hoisted Variables (`vi.hoisted`)

`vi.mock()` calls are hoisted above all `import` statements and top-level `const`/`let` declarations. Any local variable referenced inside a `vi.mock()` factory **must** be created with `vi.hoisted()`, or Vitest throws a `ReferenceError` (`Cannot access '...' before initialization`).

```ts
import { expect, it, vi } from 'vitest'

const { mockFetchUser } = vi.hoisted(() => ({
  mockFetchUser: vi.fn(),
}))

vi.mock('./user-api', () => ({
  fetchUser: mockFetchUser,
}))

import { loadProfile } from './profile'

it('loads profile using hoisted mock', async () => {
  mockFetchUser.mockResolvedValueOnce({ id: '1', name: 'Ada' })
  await expect(loadProfile('1')).resolves.toEqual({ id: '1', name: 'Ada' })
})
```

## Module Mocking

```ts
// Mock entire module (hoisted automatically)
vi.mock('./module', () => ({
  namedExport: vi.fn(() => 'mocked'),
  default: vi.fn()
}))

// Partial mock with importActual (two ways)
// Option 1: Use vi.importActual directly
vi.mock('./utils', async () => {
  const actual = await vi.importActual<typeof import('./utils')>('./utils')
  return {
    ...actual,
    specificFunction: vi.fn()
  }
})

// Option 2: Use the importOriginal helper parameter
vi.mock('./utils', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./utils')>()
  return {
    ...actual,
    specificFunction: vi.fn()
  }
})

// Access mocked module
import { specificFunction } from './utils'
vi.mocked(specificFunction).mockReturnValue('value')

// Mock with spy (keeps implementation)
vi.mock('./calculator', { spy: true })
```

## Function Mocking

```ts
const mockFn = vi.fn()
const mockFnWithImpl = vi.fn((x: number) => x * 2)

mockFn.mockReturnValue(42)
mockFn.mockReturnValueOnce(1).mockReturnValueOnce(2)

mockFn.mockResolvedValue({ data: 'value' })
mockFn.mockRejectedValue(new Error('failed'))

mockFn.mockImplementation((arg: number) => arg + 1)
mockFn.mockImplementationOnce(() => 'once')
```

## Mock Assertions

```ts
expect(mockFn).toHaveBeenCalled()
expect(mockFn).toHaveBeenCalledTimes(2)
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2')
expect(mockFn).toHaveBeenLastCalledWith('arg')
expect(mockFn).toHaveReturnedWith(42)

// Access mock state
mockFn.mock.calls        // [['arg1'], ['arg2']]
mockFn.mock.results      // [{ type: 'return', value: 42 }]
mockFn.mock.lastCall     // ['arg2']
```

## Spying

```ts
const obj = { method: () => 'real' }
const spy = vi.spyOn(obj, 'method')

vi.spyOn(obj, 'method').mockImplementation(() => 'mocked')

// Spy on getters/setters
vi.spyOn(obj, 'property', 'get').mockReturnValue('value')
vi.spyOn(obj, 'property', 'set')

// Restore original
spy.mockRestore()
```

## Mock Cleanup

```ts
import { vi, beforeEach } from 'vitest'

beforeEach(() => {
  vi.clearAllMocks()    // Clear mock call history
  vi.resetAllMocks()    // Clear history + reset implementations
  vi.restoreAllMocks()  // Restore original implementations (spies)
})

// Or configure in vitest.config.ts
export default defineConfig({
  test: {
    clearMocks: true,
    mockReset: true,
    restoreMocks: true,
  }
})
```

## Mock Methods Quick Reference

| Method | Purpose |
|--------|---------|
| `vi.hoisted()` | Declare variables safely before hoisted `vi.mock()` factories |
| `vi.fn()` | Create mock function |
| `vi.spyOn()` | Spy on method |
| `vi.mock()` | Mock module |
| `vi.importActual()` | Import real module |
| `vi.mocked()` | Type helper for mocks |
| `vi.clearAllMocks()` | Clear call history |
| `vi.resetAllMocks()` | Reset implementations |
| `vi.restoreAllMocks()` | Restore originals |
