---
name: vitest-testing
description: Vitest v4 testing patterns, configuration, mocking, and verification gates. Use when writing unit or integration tests, configuring vitest.config, mocking modules with vi.mock/vi.hoisted/vi.fn, setting up coverage, or configuring Browser Mode.
---

# Vitest Best Practices

## Quick Reference

```ts
import { describe, it, expect, beforeEach, vi } from 'vitest'

describe('feature name', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('should do something specific', () => {
    expect(actual).toBe(expected)
  })

  it.todo('planned test')
  it.skip('temporarily disabled')
  it.only('run only this during dev')
})
```

## Common Assertions

```ts
// Equality
expect(value).toBe(42)                    // Strict (===)
expect(obj).toEqual({ a: 1 })             // Deep equality
expect(obj).toStrictEqual({ a: 1 })       // Strict deep (checks types & undefined keys)

// Numbers & Strings/Arrays
expect(0.1 + 0.2).toBeCloseTo(0.3)
expect(str).toMatch(/pattern/)
expect(array).toContain(item)
expect(array).toHaveLength(3)

// Objects
expect(obj).toHaveProperty('nested.key', 'value')
expect(obj).toMatchObject({ subset: 'of properties' })

// Exceptions
expect(() => fn()).toThrow('error message')
expect(() => fn()).toThrow(/pattern/)
```

## Async Testing

```ts
// Async/await (preferred)
it('fetches data', async () => {
  const data = await fetchData()
  expect(data).toEqual({ id: 1 })
})

// Promise matchers - ALWAYS await these
await expect(fetchData()).resolves.toEqual({ id: 1 })
await expect(fetchData()).rejects.toThrow('Error')

// Wrong - creates false positive
expect(promise).resolves.toBe(value)  // Missing await!
```

## Quick Mock Reference

```ts
const mockFn = vi.fn()
mockFn.mockReturnValue(42)
mockFn.mockResolvedValue({ data: 'value' })

expect(mockFn).toHaveBeenCalled()
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2')
expect(mockFn).toHaveBeenCalledTimes(2)
```

For `vi.hoisted()`, `vi.mock()`, `importOriginal`, and mock cleanup, see [references/mocking.md](references/mocking.md).

## Verification gates

Use this sequence when you add or change tests; each step has an objective pass condition.

1. **Run the test suite** — From the package or workspace root, run the same command CI uses (check `package.json` scripts; often `vitest run`, `pnpm test`, or `npm test`). **Pass:** exit code is 0 and the report shows zero failing tests.
2. **Async matchers** — **Pass:** every `expect(…).resolves` and `expect(…).rejects` is prefixed with `await` (`await expect(...)`), as in [Async Testing](#async-testing). A line where `resolves` or `rejects` appears without `await` fails this gate.
3. **Vitest v4 config compatibility** — **Pass:** config uses top-level `maxWorkers` / `isolate` / `fileParallelism` (not removed v3 `poolOptions`), explicit `coverage.include` for AST coverage, and `@vitest/browser-playwright` (`provider: playwright()`) if Browser Mode is configured.

## Additional Documentation

- **Mocking**: See [references/mocking.md](references/mocking.md) for `vi.hoisted()`, module mocking, spying, and cleanup
- **Configuration**: See [references/config.md](references/config.md) for Vitest v4 `vitest.config`, workers, Browser Mode, and coverage
- **Patterns**: See [references/patterns.md](references/patterns.md) for timers, snapshots, and anti-patterns

## Test Methods Quick Reference

| Method | Purpose |
|--------|---------|
| `it()` / `test()` | Define test |
| `describe()` | Group tests |
| `beforeEach()` / `afterEach()` | Per-test hooks |
| `beforeAll()` / `afterAll()` | Per-suite hooks |
| `.skip` | Skip test/suite |
| `.only` | Run only this |
| `.todo` | Placeholder |
| `.concurrent` | Parallel execution |
| `.each([...])` | Parameterized tests |
