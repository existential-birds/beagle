# Configuration (Vitest v4)

## Contents

- [Basic Config](#basic-config)
- [Global Setup](#global-setup)
- [DOM Testing & Browser Mode](#dom-testing--browser-mode)
- [Concurrent Tests](#concurrent-tests)
- [Workers & Test Isolation (Vitest v4)](#workers--test-isolation-vitest-v4)
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
    include: ['**/*.test.ts'],
    exclude: ['node_modules', 'dist'],
    testTimeout: 10000,
    coverage: {
      provider: 'v8',           // 'v8' | 'istanbul'
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['**/*.test.{ts,tsx}', '**/node_modules/**']
    },
  }
})
```

## Global Setup

```ts
// test/setup.ts
import { beforeEach, expect, vi } from 'vitest'

beforeEach(() => {
  vi.clearAllMocks()
})

expect.extend({
  toBeWithinRange(received: number, floor: number, ceiling: number) {
    const pass = received >= floor && received <= ceiling
    return {
      pass,
      message: () => `expected ${received} to be within ${floor}-${ceiling}`
    }
  }
})
```

## DOM Testing & Browser Mode

For simulated DOM tests (`jsdom` / `happy-dom`):

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: './test/setup.ts'
  }
})
```

For real browser tests in **Vitest 4**, use modular provider factories (`@vitest/browser-playwright`, `@vitest/browser-webdriverio`) instead of the removed v3 string `provider: 'playwright'`:

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import { playwright } from '@vitest/browser-playwright'

export default defineConfig({
  test: {
    browser: {
      enabled: true,
      provider: playwright(),
      instances: [{ browser: 'chromium' }],
    },
  },
})
```

## Concurrent Tests

```ts
describe.concurrent('suite', () => {
  it('test 1', async ({ expect }) => { /* use local expect in concurrent tests */ })
  it('test 2', async ({ expect }) => { /* ... */ })
})
```

## Workers & Test Isolation (Vitest v4)

In Vitest 4, `test.poolOptions` was **removed** — configure worker limits and isolation at the top level of `test`:

```ts
export default defineConfig({
  test: {
    pool: 'threads',          // 'threads' | 'forks' | 'vmThreads' | 'vmForks'
    maxWorkers: 1,            // Replaces removed threads.singleThread / minThreads / maxThreads
    isolate: false,           // Share environment between test files (faster, requires clean teardown)
    fileParallelism: false,   // Run test files sequentially (useful for shared DB integration tests)
  }
})
```

## Type Testing

```ts
import { expectTypeOf, assertType } from 'vitest'

expectTypeOf({ a: 1 }).toEqualTypeOf<{ a: number }>()
expectTypeOf('string').toBeString()
expectTypeOf(promise).resolves.toBeNumber()

assertType<string>('hello')
```

## Environment Variables

```ts
export default defineConfig({
  test: {
    env: {
      TEST_VAR: 'test-value'
    }
  }
})
```

## Coverage Configuration

Vitest 4 (`@vitest/coverage-v8` `^4`) uses AST-aware coverage remapping and requires explicit `coverage.include` so only intended source files are measured (removed `coverage.all` / `coverage.extensions`):

```ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'node_modules',
        'test',
        '**/*.d.ts',
        '**/*.test.{ts,tsx}',
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
