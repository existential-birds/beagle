---
name: react-flow-code-review
description: Reviews React Flow (@xyflow/react v12/v13) code for anti-patterns, re-render traps, SSR/measurement bugs, layout coordinate errors, and API deprecations. Use when reviewing node-based UI code or auditing @xyflow/react implementations.
---

# React Flow Code Review

When reviewing React Flow (`@xyflow/react` v12/v13) code, complete the gates below in order. Each step has an objective pass condition before moving on.

## Review Gates (Sequenced)

1. **Locate flow code** — Search the review scope for `@xyflow/react`, `ReactFlow`, `ReactFlowProvider`, `useReactFlow`, `nodeTypes`, `edgeTypes`, and `@dagrejs/dagre`. **Pass:** a list of file paths (or explicit "none in scope").
2. **Provider & container boundary** — For each `useReactFlow()`, `useNodesData()`, `useNodeConnections()`, or store hook, trace the component tree to an enclosing `<ReactFlowProvider>` (or `<ReactFlow />`). Confirm the flow wrapper has explicit height/width and styles are imported. **Pass:** provider + container verified or concrete mismatch cited with **file:line**.
3. **Stable types, memoization & subscriptions** — Confirm `nodeTypes`/`edgeTypes` are defined outside render or memoized, custom nodes/edges use `memo()` and typed `NodeProps<T>`/`EdgeProps<T>`, and components avoid subscribing to full `nodes`/`edges` arrays when targeted hooks suffice. **Pass:** stability and subscriptions verified or traps cited with **file:line**.
4. **Report with evidence** — For each finding you deliver, record **file path and line number(s)** (plus a minimal quoted snippet). **Pass:** no critical or high-severity issue is stated without that citation.
5. **Close the checklists** — Verify [Critical Anti-Patterns](#critical-anti-patterns), [v12 / v13, SSR & Layout Checks](#v12--v13-ssr--layout-checks), and [Performance Checklist](#performance-checklist); mark each area satisfied, not applicable (with reason), or open with evidence.

## Critical Anti-Patterns

### 1. Defining `nodeTypes` / `edgeTypes` Inside Components

Recreates the object reference on every render, causing React Flow to unmount and remount every node/edge.

```tsx
// BAD - recreates object every render
function Flow() {
  const nodeTypes = { custom: CustomNode };
  return <ReactFlow nodeTypes={nodeTypes} />;
}

// GOOD - module scope (or useMemo with stable deps)
const nodeTypes = { custom: CustomNode };
function Flow() {
  return <ReactFlow nodeTypes={nodeTypes} />;
}
```

### 2. Missing `memo()` on Custom Nodes / Edges

Without `memo()`, panning/selecting or updating one node triggers unnecessary re-renders across every custom node/edge.

### 3. Subscribing to Full `nodes` / `edges` in Nodes, Edges, or Toolbars (`useNodes()` Trap)

Calling `useNodes()`, `useEdges()`, or subscribing to `state.nodes` inside a custom node/edge or status bar re-renders that component on every drag tick.

- **Fix**: Use `useNodesData(id | ids)` for specific node data, `useNodeConnections(...)` for handle connections, or targeted store selectors (`useStore(selector, shallow)` in v12; split stores `useNodesStore`/`useEdgesStore` + `useShallow` in v13).

### 4. Using `useReactFlow()` Outside `ReactFlowProvider`

Calling `useReactFlow()` in the same component that renders `<ReactFlow>` without an enclosing `<ReactFlowProvider>` throws a missing-provider runtime error. Wrap the parent in `<ReactFlowProvider>` or move the hook into a child component.

### 5. Full-Array Cloning vs `updateNodeData` & Direct Mutation

- **Direct mutation** (`nodes[0].position = ...; setNodes(nodes)`) breaks React Flow's reference checks and fails to update.
- **Full-array mapping for data updates** causes unnecessary churn; prefer `useReactFlow().updateNodeData(id, partialOrUpdater)` (or `updateEdgeData`) for data-only updates.
- **Inline callbacks**: Wrap `onNodesChange`, `onEdgesChange`, `onConnect`, and `isValidConnection` in `useCallback` with functional `setNodes((nds) => ...)` / `setEdges((eds) => ...)`.

## v12 / v13, SSR & Layout Checks

Flag these concrete bugs when present:

| Issue | What to Look For | Correct Pattern |
|---|---|---|
| **Missing CSS or Tailwind v4 layer clash** | No `@xyflow/react/style.css` (v13) or `@xyflow/react/dist/style.css` (v12) import; unlayered CSS overriding Tailwind utilities | Import `@xyflow/react/style.css` (wrapped in `@layer xyflow` in v13) or `@xyflow/react/dist/style.css` (v12) |
| **Missing container dimensions** | `<ReactFlow />` inside a `height: auto` or flex parent with no explicit height | Explicit `width` & `height` (e.g., `h-screen w-full` or `style={{ width: '100%', height: '100%' }}`) |
| **SSR / SSG missing node dimensions** | Server-rendered flow relies on `fitView` or layout without static dimensions | Provide static `width`/`height` or `initialWidth`/`initialHeight` on nodes for SSR/SSG |
| **Bare `node.width` for measured nodes** | Reading `node.width` / `node.height` after render instead of DOM-measured dimensions | Use `node.measured?.width ?? node.width ?? defaultWidth` |
| **Dynamic handles + stale measurement** | Calling `updateNodeInternals(id)` synchronously inside `onClick` (before React commits), or passing args to `useUpdateNodeInternals(id)` | `const updateNodeInternals = useUpdateNodeInternals();` (no args), called inside `useEffect` after handle count/IDs change |
| **Missing interaction classes** | `<input>`, `<button>`, `<select>`, or scrollable containers inside custom nodes or `EdgeLabelRenderer` lacking `nodrag` / `nopan` / `nowheel` / `nokey` | Add `nodrag` (and `nopan`/`nowheel`/`nokey` as appropriate); `EdgeLabelRenderer` overlays also need `pointerEvents: 'all'` |
| **String literal handle positions** | `<Handle position="right" />` | Use `Position.Right` enum from `@xyflow/react` |
| **Sub-flow ordering (v12)** | Child node with `parentId` placed before its parent node in `nodes[]` on `@xyflow/react` v12 | Place parent before children in v12 (relaxed in v13) |
| **Dagre package & coordinate bug** | Importing unmaintained legacy `dagre` package instead of `@dagrejs/dagre`, missing `- width/2, - height/2` center-to-top-left offset, or not excluding `group` nodes | Use `@dagrejs/dagre`, subtract half-dimensions matching `g.setNode`, exclude `group` nodes, and defer `fitView` to `requestAnimationFrame` |
| **v13 removed / changed APIs** | Calling removed `useHandleConnections` / `getHandleConnections` or v11 `updateEdge` utility; monolithic `useStore` on v13; `isValidConnection` typed without `Connection \| Edge` | Use `useNodeConnections` / `getNodeConnections`, `reconnectEdge`, v13 split stores (`useNodesStore`, etc. with `useShallow`), and `Connection \| Edge` |
| **Wrong `CSSProperties` import** | Importing `CSSProperties` from `'@xyflow/react'` | Import `CSSProperties` from `'react'` |

## Performance Checklist

- [ ] Custom nodes and custom edges wrapped in `memo()`
- [ ] `nodeTypes` and `edgeTypes` defined at module scope or memoized with `useMemo`
- [ ] No `useNodes()` / `useEdges()` inside custom nodes/edges (use `useNodesData` / `useNodeConnections` / targeted selectors)
- [ ] Functional state updates (`setNodes((nds) => ...)`) and `updateNodeData` for data-only updates
- [ ] `onlyRenderVisibleElements={true}` considered for graphs > 100 nodes
- [ ] `fitView` not called on every render; post-layout `fitView` deferred via `requestAnimationFrame` / `useNodesInitialized`
- [ ] TypeScript unions use `BuiltInNode | CustomNode`, `NodeProps<CustomNode>`, `EdgeProps<CustomEdge>`, and `useNodesState<AppNode>`
