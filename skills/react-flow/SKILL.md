---
name: react-flow
description: "Implements and structures node-based UIs with React Flow (@xyflow/react v12/v13), covering custom nodes and edges, handles, viewport control, sub-flows, store subscriptions, and @dagrejs/dagre auto-layout. Use when building flow editors, workflow diagrams, or interactive graphs in React."
---

# React Flow (`@xyflow/react`)

Implement interactive node-based graphs and workflow editors using `@xyflow/react` (v12 and v13, React 18/19).

## Implementation Gates

Run these checks in order before treating any integration as complete:

1. **CSS & container dimensions** — Import `@xyflow/react/style.css` (v13, wrapped in `@layer xyflow` for Tailwind v4 precedence) or `@xyflow/react/dist/style.css` (v12), and give the wrapper element explicit dimensions (`width` and `height`).
2. **Stable `nodeTypes` / `edgeTypes`** — Define `nodeTypes` and `edgeTypes` at module scope or memoize with `useMemo`; never create inline object literals on every render (causes full node/edge remounting).
3. **Provider boundary** — Any component calling `useReactFlow()`, `useNodesData()`, `useNodeConnections()`, or store hooks must be a descendant of `<ReactFlowProvider>` (or rendered inside `<ReactFlow />`).
4. **Measured vs SSR dimensions** — Read DOM-measured node sizes from `node.measured?.width` / `node.measured?.height` (falling back to `node.width ?? defaultWidth`). For SSR/SSG, provide static `width`/`height` or `initialWidth`/`initialHeight` on nodes so `fitView` and initial layout work without DOM measurement.

## Quick Start & TypeScript Unions

```tsx
import { useCallback } from 'react';
import {
  ReactFlow,
  ReactFlowProvider,
  Background,
  Controls,
  useNodesState,
  useEdgesState,
  addEdge,
  type Node,
  type Edge,
  type BuiltInNode,
  type BuiltInEdge,
  type OnConnect,
} from '@xyflow/react';
import '@xyflow/react/style.css'; // v13 (@layer xyflow); use '@xyflow/react/dist/style.css' on v12

export type TaskNode = Node<{ label: string; active: boolean }, 'task'>;
export type AppNode = BuiltInNode | TaskNode;

export type WeightedEdge = Edge<{ weight: number }, 'weighted'>;
export type AppEdge = BuiltInEdge | WeightedEdge;

const nodeTypes = { /* task: TaskNodeComponent */ };
const edgeTypes = { /* weighted: WeightedEdgeComponent */ };

const initialNodes: AppNode[] = [
  { id: '1', type: 'input', position: { x: 0, y: 0 }, data: { label: 'Start' } },
  { id: '2', position: { x: 240, y: 80 }, data: { label: 'Process' } },
];
const initialEdges: AppEdge[] = [{ id: 'e1-2', source: '1', target: '2' }];

function FlowCanvas() {
  const [nodes, setNodes, onNodesChange] = useNodesState<AppNode>(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState<AppEdge>(initialEdges);

  const onConnect: OnConnect = useCallback(
    (connection) => setEdges((eds) => addEdge(connection, eds)),
    [setEdges]
  );

  return (
    <div style={{ width: '100%', height: '100vh' }}>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        fitView
      >
        <Background />
        <Controls />
      </ReactFlow>
    </div>
  );
}

export default function App() {
  return (
    <ReactFlowProvider>
      <FlowCanvas />
    </ReactFlowProvider>
  );
}
```

## Custom Nodes, Edges & Interaction Classes

- **Typed props**: Use `NodeProps<TaskNode>` and `EdgeProps<WeightedEdge>`, wrapped in `memo()`. Import `CSSProperties` from `'react'` (not `'@xyflow/react'`).
- **Handles**: Always use `Position` enum (`Position.Top`, `Position.Right`, `Position.Bottom`, `Position.Left`). Assign distinct `id` props when a node has multiple handles of the same type, and match them via `sourceHandle` / `targetHandle` on edges.
- **Interaction classes**: Prevent accidental graph interactions on embedded controls:
  - `nodrag` — prevents dragging the node (required on `<input>`, `<button>`, `<select>`)
  - `nopan` — prevents canvas panning from the element
  - `nowheel` — prevents canvas zoom on scroll inside scrollable areas
  - `nokey` — prevents React Flow keyboard shortcuts (backspace/delete) when typing in inputs

For multi-handle nodes, dynamic handles (`useUpdateNodeInternals`), `NodeToolbar`, `NodeResizer`, `EdgeToolbar`, `Panel`, `BaseEdge`, `EdgeLabelRenderer`, `EdgeText`, `MarkerType`, and `onBeforeDelete`, see [Custom Primitives](./references/custom-primitives.md).

## Core APIs & Patterns

### Updating Node/Edge Data & Reconnecting

Prefer `useReactFlow().updateNodeData` / `updateEdgeData` over manually mapping the full `nodes`/`edges` array for data-only updates:

```tsx
const { updateNodeData, setEdges } = useReactFlow<AppNode, AppEdge>();

// Merge partial data (or pass { replace: true } as 3rd arg); generics live on useReactFlow<AppNode, AppEdge>()
updateNodeData('node-1', { active: true });

// Functional updater on union AppNode: narrow node.type before reading custom fields
updateNodeData('node-1', (node) => {
  if (node.type !== 'task') return node.data;
  return { ...node.data, active: !node.data.active };
});
```

Use `reconnectEdge` with `onReconnect` (replaced v11's `updateEdge` utility):

```tsx
import { reconnectEdge, type OnReconnect } from '@xyflow/react';

const onReconnect: OnReconnect<AppEdge> = useCallback(
  (oldEdge, newConnection) => setEdges((els) => reconnectEdge(oldEdge, newConnection, els)),
  [setEdges]
);
```

### Connection Validation

`isValidConnection` receives `Connection | Edge`:

```tsx
import type { Connection, Edge } from '@xyflow/react';

const isValidConnection = useCallback(
  (connection: Connection | Edge) => connection.source !== connection.target,
  []
);
```

### Viewport, Coordinates & Serialization

```tsx
const {
  fitView,
  setCenter,
  getNode,
  screenToFlowPosition,
  toObject,
  setViewport,
  viewportInitialized,
} = useReactFlow();

// Pan to a measured node center (use node.measured, not bare node.width)
const focusNode = (id: string) => {
  const node = getNode(id);
  if (!node) return;
  const w = node.measured?.width ?? node.width ?? 0;
  const h = node.measured?.height ?? node.height ?? 0;
  setCenter(node.position.x + w / 2, node.position.y + h / 2, { zoom: 1.5, duration: 400 });
};

// Convert pointer coordinates to flow space
const onPaneClick = (e: React.MouseEvent) => {
  const position = screenToFlowPosition({ x: e.clientX, y: e.clientY });
  // add node at position
};

// Save & restore full flow state (nodes, edges, viewport)
const snapshot = toObject();
```

## v12 vs v13 Differences

| Area | `@xyflow/react` v12 | `@xyflow/react` v13 (React 19 + Zustand 5) |
|---|---|---|
| **CSS & Tailwind v4** | `@xyflow/react/dist/style.css` | `@xyflow/react/style.css` (wrapped in `@layer xyflow`); optional `@xyflow/react/xy-theme.css` |
| **Connection hook** | `useNodeConnections` (preferred; `useHandleConnections` deprecated in v12.4+) | `useNodeConnections` / `getNodeConnections` (`useHandleConnections` & `getHandleConnections` removed) |
| **Store hooks** | Monolithic `useStore(selector, shallow)` & `useStoreApi()` | Split stores: `useNodesStore`, `useEdgesStore`, `useViewportStore`, `useOptionsStore`, `useConnectionStore`, `useSelectionStore` (use `useShallow`), plus `useReactFlowStoreApi`, `useNode`, `useEdge` |
| **Sub-flow ordering** | Parent nodes MUST precede child nodes in `nodes[]` | Parent-before-child ordering requirement removed |
| **`onConnectEnd` coords** | Convert `clientX`/`clientY` via `screenToFlowPosition` | `connectionState.to` is already in flow coordinates (`pointer` has screen coords) |
| **`fitViewOptions.padding`** | Fraction (`0.2` = 20%) | Defaults to `'5%'`; unitless numbers are treated as pixels (use `'20%'` for percentage) |

## Scale & Alternatives Heuristic

- **< 100 nodes**: Default `<ReactFlow />` settings.
- **100–500 nodes**: Enable `onlyRenderVisibleElements={true}` and keep custom nodes lightweight with `memo()`.
- **500–1,000+ nodes**: Simplify node DOM, avoid subscribing nodes to full `nodes`/`edges` arrays, and run layout in a Web Worker.
- **10k+ nodes / static / 3D**: Consider WebGL graph renderers (e.g., Sigma.js) for 10k+ nodes, plain SVG/Canvas for static diagrams, or Three.js / react-three-fiber for 3D.

## Reference Files

- [Custom Primitives](./references/custom-primitives.md) — `CSSProperties` typing, dynamic handles (`useUpdateNodeInternals` post-commit), `NodeToolbar`, `NodeResizer`, `EdgeToolbar`, `Panel`, path helpers (`stepPosition`), `EdgeLabelRenderer`, `EdgeText`, `MarkerType`, and `onBeforeDelete`.
- [Advanced Patterns & Dagre Layout](./references/advanced-and-layout.md) — Sub-flows (`parentId`, `extent`, `expandParent`), `onConnectEnd` drop-to-create, `useNodesData` + `useNodeConnections`, `onNodesChange` middleware, v12 vs v13 store selectors, and `@dagrejs/dagre` auto-layout.
