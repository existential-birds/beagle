# Common Patterns

## Contents

- [Fake Timers](#fake-timers)
- [Waiting Utilities](#waiting-utilities)
- [Snapshots](#snapshots)
- [Testing Errors](#testing-errors)
- [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
- [Best Practices](#best-practices)
- [Environment Methods](#environment-methods)

---

## Fake Timers

```ts
import { vi, beforeEach, afterEach } from 'vitest'

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

it('executes after timeout', () => {
  const callback = vi.fn()
  setTimeout(callback, 1000)

  vi.advanceTimersByTime(1000)
  expect(callback).toHaveBeenCalled()
})

// Timer methods
vi.runAllTimers()
vi.runOnlyPendingTimers()
vi.advanceTimersByTime(1000)
vi.advanceTimersToNextTimer()
vi.setSystemTime(new Date('2024-01-01'))
```

## Waiting Utilities

```ts
// Wait for condition
await vi.waitFor(() => {
  expect(element).toBeTruthy()
}, { timeout: 1000, interval: 50 })

// Wait until truthy
const element = await vi.waitUntil(
  () => document.querySelector('.loaded'),
  { timeout: 1000 }
)
```

## Snapshots

```ts
// Basic snapshot
it('matches snapshot', () => {
  const data = { foo: 'bar' }
  expect(data).toMatchSnapshot()
})

// Inline snapshot (updates test file)
it('matches inline snapshot', () => {
  expect(render()).toMatchInlineSnapshot(`
    <div>
      <h1>Title</h1>
    </div>
  `)
})

// File snapshot
it('matches file snapshot', async () => {
  const html = renderHTML()
  await expect(html).toMatchFileSnapshot('./expected.html')
})

// Property matchers for dynamic values
expect(data).toMatchSnapshot({
  id: expect.any(Number),
  timestamp: expect.any(Date),
  uuid: expect.stringMatching(/^[a-f0-9-]+$/)
})

// Update snapshots: vitest -u
```

## Testing Errors

```ts
// Sync errors
expect(() => throwError()).toThrow()
expect(() => throwError()).toThrow('specific message')
expect(() => throwError()).toThrow(/pattern/)
expect(() => throwError()).toThrowError(CustomError)

// Async errors
await expect(asyncThrow()).rejects.toThrow()
await expect(asyncThrow()).rejects.toThrow('message')
```

## Anti-Patterns to Avoid

```ts
// Don't nest describes excessively
describe('A', () => {
  describe('B', () => {
    describe('C', () => {
      describe('D', () => { /* too nested */ })
    })
  })
})

// Don't forget await on async expects
expect(promise).resolves.toBe(value)  // Wrong - false positive!
await expect(promise).resolves.toBe(value)  // Correct

// Don't test implementation details
expect(component.state.internalFlag).toBe(true)  // Brittle

// Don't share state between tests
let sharedVariable
it('test 1', () => { sharedVariable = 'value' })
it('test 2', () => { expect(sharedVariable).toBe('value') }) // Flaky!

// Don't vi.mock inside tests (hoisting issues)
it('test', () => {
  vi.mock('./module')  // Won't work!
})
```

## Best Practices

```ts
// Keep describes shallow
describe('UserService', () => {
  it('creates user with valid data')
  it('throws on invalid email')
})

// Always await async expects
await expect(promise).resolves.toBe(value)

// Test behavior, not implementation
expect(getUserName()).toBe('John Doe')

// Use beforeEach for isolation
beforeEach(() => {
  state = createFreshState()
})

// vi.mock at top level (before imports)
vi.mock('./module')
import { fn } from './module'
```

## Environment Methods

| Method | Purpose |
|--------|---------|
| `vi.useFakeTimers()` | Enable fake timers |
| `vi.useRealTimers()` | Restore real timers |
| `vi.setSystemTime()` | Mock system time |
| `vi.stubGlobal()` | Mock global variable |
| `vi.stubEnv()` | Mock environment variable |
