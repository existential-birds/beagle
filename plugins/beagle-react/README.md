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

## See Also

- [beagle-core](../beagle-core) - Shared workflows, verification protocol, and git commands
- [beagle marketplace](https://github.com/existential-birds/beagle) - Full plugin marketplace with 10 focused plugins
