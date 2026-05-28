# beagle-react

React, React Flow, React Router, shadcn/ui, Tailwind v4, Vitest, and Zustand code review skills for [Claude Code](https://claude.ai/code). Part of the [beagle](https://github.com/existential-birds/beagle) plugin marketplace.

## Installation

```bash
# Add the marketplace (if not already added)
claude plugin marketplace add https://github.com/existential-birds/beagle

# Install the plugin
claude plugin install beagle-react@existential-birds
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| **review-frontend** | `/beagle-react:review-frontend` | Comprehensive React/TypeScript frontend code review with optional parallel agents |

Reviews changed `.tsx`, `.ts`, and `.css` files against `main`. Detects frameworks in use and loads appropriate skills. Use `--parallel` to spawn specialized subagents per technology area.

## Skills

| Skill | Description |
|-------|-------------|
| **ai-elements** | Vercel AI Elements for workflow UI components (chat interfaces, tool execution, reasoning displays) |
| **dagre-react-flow** | Automatic graph layout using dagre with React Flow for hierarchical and tree structures |
| **react-flow** | React Flow (@xyflow/react) for workflow visualization with custom nodes and edges |
| **react-flow-advanced** | Advanced React Flow patterns: sub-flows, custom connection lines, drag-and-drop, undo/redo |
| **react-flow-architecture** | Architectural guidance for building node-based UIs with React Flow |
| **react-flow-code-review** | Reviews React Flow code for anti-patterns, performance issues, and best practices |
| **react-flow-implementation** | Implements React Flow node-based UIs: nodes, edges, handles, state management, viewport control |
| **react-router-code-review** | Reviews React Router code for data loading, mutations, error handling, and navigation patterns |
| **react-router-v7** | React Router v7 best practices for data-driven routing, loaders, actions, and navigation |
| **review-verification-protocol** | Mandatory verification steps to reduce false positives in code reviews |
| **shadcn-code-review** | Reviews shadcn/ui components for CVA patterns, composition, accessibility, and data-slot usage |
| **shadcn-ui** | shadcn/ui component patterns with Radix primitives and Tailwind styling |
| **tailwind-v4** | Tailwind CSS v4 with CSS-first configuration, OKLCH colors, and design tokens |
| **vitest-testing** | Vitest testing framework patterns: mocking, snapshots, coverage, and configuration |
| **remix-v2-data-flow** | Remix v2 data loading and mutations: loaders, actions, deferred data, revalidation, pending state |
| **remix-v2-data-flow-review** | Reviews Remix v2 loaders and actions for mutations-in-loader, missing validation, leaked server fields, wrong return helpers |
| **remix-v2-error-boundaries-review** | Reviews Remix v2 error-handling code for unified ErrorBoundary, isRouteErrorResponse narrowing, throw-vs-return, v1 holdovers |
| **remix-v2-forms** | Remix v2 form submissions and mutations: forms, optimistic UI, file uploads, multi-action routes |
| **remix-v2-forms-review** | Reviews Remix v2 form code for manual fetch() mutations, native form misuse, wrong useNavigation/useFetcher choice |
| **remix-v2-meta-sessions** | Remix v2 meta/SEO, sessions, auth, and CSRF: document head, cookie sessions, auth gates |
| **remix-v2-meta-sessions-review** | Reviews Remix v2 code for v1-shape meta exports, cookie security gaps, auth gates in wrong layer, missing CSRF |
| **remix-v2-perf-ssr** | Remix v2 performance, streaming, caching, and server/client boundaries |
| **remix-v2-perf-ssr-review** | Reviews Remix v2 code for caching header misuse, missing server/client split, hydration mismatches, prefetch hygiene |
| **remix-v2-routing** | Remix v2 routing patterns: flat-routes v2 conventions, route file naming, nested layouts, resource routes |
| **remix-v2-routing-review** | Reviews Remix v2 route files for naming convention violations, missing layouts, resource-route shape, v1 holdovers |
| **review-remix-v2** | Comprehensive Remix v2 code review with optional parallel agents and verification protocol |
| **zustand-state** | Zustand state management: stores, selectors, persistence, devtools, and middleware |

### Reference Material

Each skill includes detailed reference documents:

**react-flow**: custom nodes, custom edges, events, viewport

**react-flow-implementation**: additional components, edge paths

**react-router-code-review**: data loading, mutations, error handling, navigation

**react-router-v7**: loaders, actions, navigation, advanced patterns

**shadcn-code-review**: CVA patterns, composition, accessibility, data-slot

**shadcn-ui**: components, CVA, patterns

**tailwind-v4**: setup, theming, dark mode

**vitest-testing**: config, mocking, patterns

**zustand-state**: middleware, patterns, TypeScript

**ai-elements**: conversation, prompt input, visualization, workflow

**dagre-react-flow**: reference

**remix-v2-data-flow**: loaders, actions, deferred data, revalidation

**remix-v2-data-flow-review**: data-flow anti-patterns, validation

**remix-v2-error-boundaries-review**: error boundary patterns, v1 holdovers

**remix-v2-forms**: form submissions, optimistic UI, file uploads

**remix-v2-forms-review**: form anti-patterns, pending state

**remix-v2-meta-sessions**: meta/SEO, sessions, auth, CSRF

**remix-v2-meta-sessions-review**: meta/session anti-patterns

**remix-v2-perf-ssr**: streaming, caching, server/client boundaries

**remix-v2-perf-ssr-review**: caching misuse, hydration mismatches

**remix-v2-routing**: flat-routes, nested layouts, resource routes

**remix-v2-routing-review**: naming conventions, layout violations

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
