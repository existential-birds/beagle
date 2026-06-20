# beagle-react

React, React Flow, shadcn/ui, Tailwind, Vitest, and Remix v2 code review. Part of the [beagle](https://github.com/existential-birds/beagle) Agent Skills marketplace — see the [full skill catalog](../../SKILLS.md).

## Installation

For any coding agent that supports [Agent Skills](https://agentskills.io):

```bash
npx skills add existential-birds/beagle
```

For Claude Code:

```bash
claude plugin marketplace add https://github.com/existential-birds/beagle
claude plugin install beagle-react@existential-birds
```

## Skills

| Skill | Description |
|-------|-------------|
| `review-frontend` | Comprehensive React/TypeScript frontend code review, dispatching per-area review skills |
| `review-remix-v2` | Comprehensive Remix v2 code review across all areas with verification protocol |
| `react-flow` | React Flow (@xyflow/react) for workflow visualization with custom nodes and edges |
| `react-flow-implementation` | Build React Flow node-based UIs: nodes, edges, handles, state, viewport control |
| `react-flow-advanced` | Advanced React Flow patterns: sub-flows, custom connection lines, drag-and-drop, undo/redo |
| `react-flow-architecture` | Architectural guidance for designing node-based UIs with React Flow |
| `react-flow-code-review` | Reviews React Flow code for anti-patterns, performance issues, and best practices |
| `dagre-react-flow` | Automatic hierarchical and tree graph layout using dagre with React Flow |
| `react-router-v7` | React Router v7 data-driven routing: loaders, actions, fetchers, navigation |
| `react-router-code-review` | Reviews React Router v6.4+ code for data loading, mutations, error handling, navigation |
| `shadcn-ui` | shadcn/ui component patterns with CVA variants, Radix primitives, and Tailwind |
| `shadcn-code-review` | Reviews shadcn/ui components for CVA, asChild composition, accessibility, data-slot |
| `tailwind-v4` | Tailwind CSS v4 CSS-first config, OKLCH colors, design tokens, and dark mode |
| `zustand-state` | Zustand state management: stores, selectors, persistence, devtools, middleware |
| `vitest-testing` | Vitest patterns: mocking with vi.mock/vi.fn, snapshots, coverage, configuration |
| `ai-elements` | Vercel AI Elements for workflow UI: chat, tool execution, reasoning, job queues |
| `remix-v2-data-flow` | Remix v2 loaders, actions, deferred data, revalidation, and pending state |
| `remix-v2-data-flow-review` | Reviews loaders/actions for mutations-in-loader, missing validation, leaked fields, wrong helpers |
| `remix-v2-forms` | Remix v2 forms, optimistic UI, file uploads, and multi-action intent routes |
| `remix-v2-forms-review` | Reviews form code for manual fetch mutations, native form misuse, wrong fetcher choice |
| `remix-v2-routing` | Remix v2 flat-routes v2 conventions, file naming, nested layouts, resource routes |
| `remix-v2-routing-review` | Reviews route files for naming violations, missing layouts, resource-route shape, v1 holdovers |
| `remix-v2-meta-sessions` | Remix v2 meta/SEO, cookie sessions, auth gates, and CSRF protection |
| `remix-v2-meta-sessions-review` | Reviews meta/session code for v1-shape meta, cookie security gaps, misplaced auth, missing CSRF |
| `remix-v2-perf-ssr` | Remix v2 performance, streaming, HTTP caching, and server/client boundaries |
| `remix-v2-perf-ssr-review` | Reviews code for caching misuse, missing server/client split, hydration mismatches, prefetch hygiene |
| `remix-v2-error-boundaries-review` | Reviews error handling for unified ErrorBoundary, isRouteErrorResponse narrowing, v1 holdovers |
| `review-verification-protocol` | Reference: mandatory verification steps loaded before reporting code review findings |

## See Also

- [beagle-core](../beagle-core) — Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) — Full Agent Skills marketplace
