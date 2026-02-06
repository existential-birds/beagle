# Configuration

## Contents

- [Basic Config](#basic-config)
- [Global Setup](#global-setup)
- [DOM Testing](#dom-testing)
- [Concurrent Tests](#concurrent-tests)
- [Test Isolation](#test-isolation)
- [Type Testing](#type-testing)
- [Environment Variables](#environment-variables)
- [Coverage Configuration](#coverage-configuration)

---

## Basic Config

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,              // Use global test APIs (describe, it, expect)
    environment: 'node',        // 'node' | 'jsdom' | 'happy-dom'
    setupFiles: './test/setup.ts',
    coverage: {
      provider: 'v8',           // 'v8' | 'istanbul'
      reporter: ['text', 'json', 'html'],
      exclude: ['**/*.test.ts', '**/node_modules/**']
    },
    include: ['**/*.test.ts'],
    exclude: ['node_modules', 'dist'],
    testTimeout: 10000,
  }
})
```

## Global Setup

```ts
// test/setup.ts
import { beforeEach, afterEach, vi } from 'vitest'

// Global beforeEach/afterEach
beforeEach(() => {
  vi.clearAllMocks()
})

// Extend matchers
import { expect } from 'vitest'
expect.extend({
  toBeWithinRange(received, floor, ceiling) {
    const pass = received >= floor && received <= ceiling
    return {
      pass,
      message: () => `expected ${received} to be within ${floor}-${ceiling}`
    }
  }
})
```

## DOM Testing

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: './test/setup.ts'
  }
})

// Tests
it('updates DOM', () => {
  document.body.innerHTML = '<div id="app"></div>'
  const app = document.querySelector('#app')
  expect(app).toBeTruthy()
  expect(app?.textContent).toBe('')
})
```

## Concurrent Tests

```ts
// Run tests in parallel
describe.concurrent('suite', () => {
  it('test 1', async () => { /* ... */ })
  it('test 2', async () => { /* ... */ })
})

// Individual concurrent tests
it.concurrent('test 1', async () => { /* ... */ })
it.concurrent('test 2', async () => { /* ... */ })

// Use local expect for concurrent tests
it.concurrent('test', async ({ expect }) => {
  expect(value).toBe(1)
})
```

## Test Isolation

```ts
export default defineConfig({
  test: {
    isolate: false,           // Share environment between tests (faster)
    pool: 'threads',          // 'threads' | 'forks' | 'vmThreads'
    poolOptions: {
      threads: {
        singleThread: true    // Run tests in single thread
      }
    }
  }
})
```

## Type Testing

```ts
import { expectTypeOf, assertType } from 'vitest'

// Compile-time type assertions
expectTypeOf({ a: 1 }).toEqualTypeOf<{ a: number }>()
expectTypeOf('string').toBeString()
expectTypeOf(promise).resolves.toBeNumber()

assertType<string>('hello')  // Type guard
```

## Environment Variables

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    env: {
      TEST_VAR: 'test-value'
    }
  }
})

// Or use .env.test file
// Tests can access via process.env.TEST_VAR
```

## Coverage Configuration

```ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      include: ['src/**/*.ts'],
      exclude: [
        'node_modules',
        'test',
        '**/*.d.ts',
        '**/*.test.ts',
        '**/types.ts'
      ],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80
      }
    }
  }
})
```
