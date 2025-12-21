# Mocking Patterns

## Module Mocking

```ts
// Mock entire module (hoisted automatically)
vi.mock('./module', () => ({
  namedExport: vi.fn(() => 'mocked'),
  default: vi.fn()
}))

// Partial mock with importActual
vi.mock('./utils', async () => {
  const actual = await vi.importActual('./utils')
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
// Create mock function
const mockFn = vi.fn()
const mockFnWithImpl = vi.fn((x) => x * 2)

// Mock return values
mockFn.mockReturnValue(42)
mockFn.mockReturnValueOnce(1).mockReturnValueOnce(2)

// Mock async returns
mockFn.mockResolvedValue({ data: 'value' })
mockFn.mockRejectedValue(new Error('failed'))

// Mock implementation
mockFn.mockImplementation((arg) => arg + 1)
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
// Spy on object methods
const obj = { method: () => 'real' }
const spy = vi.spyOn(obj, 'method')

// Spy with custom implementation
vi.spyOn(obj, 'method').mockImplementation(() => 'mocked')

// Spy on getters/setters
vi.spyOn(obj, 'property', 'get').mockReturnValue('value')
vi.spyOn(obj, 'property', 'set')

// Restore original
spy.mockRestore()
```

## Mock Cleanup

```ts
import { vi, beforeEach, afterEach } from 'vitest'

beforeEach(() => {
  vi.clearAllMocks()    // Clear mock history
  vi.resetAllMocks()    // Clear history + reset implementations
  vi.restoreAllMocks()  // Restore original implementations (spies)
})

// Or configure in vitest.config.ts
export default defineConfig({
  test: {
    clearMocks: true,      // Auto-clear before each test
    mockReset: true,       // Auto-reset before each test
    restoreMocks: true,    // Auto-restore before each test
  }
})
```

## Mock Methods Quick Reference

| Method | Purpose |
|--------|---------|
| `vi.fn()` | Create mock function |
| `vi.spyOn()` | Spy on method |
| `vi.mock()` | Mock module |
| `vi.importActual()` | Import real module |
| `vi.mocked()` | Type helper for mocks |
| `vi.clearAllMocks()` | Clear call history |
| `vi.resetAllMocks()` | Reset implementations |
| `vi.restoreAllMocks()` | Restore originals |
