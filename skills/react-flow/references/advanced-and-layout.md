# Advanced Patterns & Dagre Auto-Layout

## Sub-Flows (Nested Nodes)

Use `parentId` (replaced v11 `parentNode`), `extent: 'parent'` to keep children inside bounds, and `expandParent: true` to grow the parent automatically when children approach its edges. Child `position` is relative to the parent's top-left corner.

- **v12 rule**: Parent nodes **must appear before** their children in the `nodes` array.
- **v13**: Parent-before-child array ordering is no longer required (still good practice for readability), and `useReactFlow().changeParent` is available.

```tsx
const nodes: AppNode[] = [
  {
    id: 'group-1',
    type: 'group',
    position: { x: 0, y: 0 },
    style: { width: 400, height: 260 },
    data: {}, // BuiltInNode 'group' types data as Record<string, never>
  },
  {
    id: 'child-1',
    parentId: 'group-1',
    extent: 'parent',
    expandParent: true,
    position: { x: 24, y: 48 }, // Relative to group-1
    data: { label: 'Step A' },
  },
];
```

## Drop-to-Create on `onConnectEnd`

When a user drops a connection on the empty pane (`!connectionState.isValid`), spawn a node and connect it.

- **v13**: `connectionState.to` is already in flow coordinates (use `connectionState.pointer` for screen coordinates).
- **v12**: Convert `event` `clientX`/`clientY` (or `changedTouches[0]`) with `screenToFlowPosition`.

```tsx
// v13: connectionState.to is already in flow coordinates
const onConnectEnd: OnConnectEnd = useCallback(
  (_event, connectionState) => {
    if (connectionState.isValid || !connectionState.fromNode || !connectionState.to) return;

    const id = crypto.randomUUID();
    const position = connectionState.to;
    const source = connectionState.fromNode.id;
    const sourceHandle = connectionState.fromHandle?.id ?? null;

    setNodes((nds) => [...nds, { id, position, data: { label: 'New Node' } }]);
    setEdges((eds) => [...eds, { id: `e-${source}-${id}`, source, sourceHandle, target: id }]);
  },
  [setNodes, setEdges]
);

// v12: FinalConnectionState.to is screen-space; convert event coords via screenToFlowPosition
const onConnectEndV12: OnConnectEnd = useCallback(
  (event, connectionState) => {
    if (connectionState.isValid || !connectionState.fromNode) return;

    const id = crypto.randomUUID();
    const { clientX, clientY } =
      'changedTouches' in event ? event.changedTouches[0] : event;
    const position = screenToFlowPosition({ x: clientX, y: clientY });
    const source = connectionState.fromNode.id;
    const sourceHandle = connectionState.fromHandle?.id ?? null;

    setNodes((nds) => [...nds, { id, position, data: { label: 'New Node' } }]);
    setEdges((eds) => [...eds, { id: `e-${source}-${id}`, source, sourceHandle, target: id }]);
  },
  [screenToFlowPosition, setNodes, setEdges]
);
```

## Change Middleware

Filter or transform `NodeChange[]` before calling `applyNodeChanges`:

```tsx
const onNodesChange = useCallback(
  (changes: NodeChange<AppNode>[]) => {
    setNodes((nds) => {
      const protectedIds = new Set(
        nds.filter((n) => n.deletable === false).map((n) => n.id)
      );
      const allowed = changes.filter(
        (c) => !(c.type === 'remove' && protectedIds.has(c.id))
      );
      return applyNodeChanges(allowed, nds);
    });
  },
  [setNodes]
);
```

## Targeted Subscriptions (Avoiding Re-Render Traps)

Never subscribe a node/edge/toolbar component to the full `nodes` or `edges` array just to inspect one neighbor or connection.

- **Data from connected/specific nodes**: `useNodesData<AppNode>(id | ids)`
- **Connections on a node/handle**: `useNodeConnections({ id, handleType, handleId })` (`UseNodeConnectionsParams` uses `id`, defaulting to the current node context when omitted; replaces the deprecated v12 `useHandleConnections` hook removed in v13). For imperative queries outside render, use `useReactFlow().getNodeConnections({ nodeId, type, handleId })` (uses `nodeId` and `type`).
- **Store selectors**:
  - **v12**: `useStore(selector, shallow)` (import `shallow` from `'zustand/shallow'`).
  - **v13**: Monolithic `useStore` is split into `useNodesStore`, `useEdgesStore`, `useViewportStore`, `useOptionsStore`, `useConnectionStore`, and `useSelectionStore`, paired with `useShallow` (exported from `'@xyflow/react'`, re-exporting `'zustand/react/shallow'`) when returning objects/arrays.

```tsx
// Subscribing inside a custom edge without re-rendering on unrelated node drags
import { useNodesData, BaseEdge, EdgeLabelRenderer, getSmoothStepPath, type EdgeProps } from '@xyflow/react';

function DataEdge({ source, target, ...props }: EdgeProps) {
  const nodesData = useNodesData<AppNode>([source, target]);
  const [path, labelX, labelY] = getSmoothStepPath(props);

  return (
    <>
      <BaseEdge id={props.id} path={path} />
      <EdgeLabelRenderer>
        <div
          style={{
            position: 'absolute',
            transform: `translate(-50%, -50%) translate(${labelX}px, ${labelY}px)`,
          }}
        >
          {nodesData[0]?.data?.label} → {nodesData[1]?.data?.label}
        </div>
      </EdgeLabelRenderer>
    </>
  );
}
```

## `@dagrejs/dagre` Auto-Layout

Always install and import the maintained `@dagrejs/dagre` package (never the unmaintained legacy `dagre` package).

### Critical Dagre Pitfalls

1. **Center-to-top-left offset**: Dagre outputs **center** coordinates `{ x, y }`; React Flow positions nodes by **top-left** `{ x: pos.x - width / 2, y: pos.y - height / 2 }`. Use the exact same `width`/`height` passed to `g.setNode` when subtracting half-dimensions.
2. **Measured dimensions**: Prefer `node.measured?.width ?? node.width ?? defaultWidth` (and `.height`).
3. **Exclude `group` / sub-flow nodes**: Filter out `type === 'group'` (or layout each group's children separately) before feeding flat edges into Dagre.
4. **Post-commit `fitView`**: Schedule `fitView()` inside `window.requestAnimationFrame` after `setNodes([...layouted])` (or trigger on `useNodesInitialized()`) so React Flow reads updated node positions.

```tsx
import dagre from '@dagrejs/dagre';
import type { Edge, Node } from '@xyflow/react';

export interface DagreLayoutOptions {
  direction?: 'TB' | 'BT' | 'LR' | 'RL';
  nodeWidth?: number;
  nodeHeight?: number;
  nodesep?: number;
  ranksep?: number;
}

export function getLayoutedElements<N extends Node, E extends Edge>(
  nodes: N[],
  edges: E[],
  options: DagreLayoutOptions = {}
): { nodes: N[]; edges: E[] } {
  const {
    direction = 'TB',
    nodeWidth = 172,
    nodeHeight = 40,
    nodesep = 50,
    ranksep = 60,
  } = options;

  const g = new dagre.graphlib.Graph();
  g.setGraph({ rankdir: direction, nodesep, ranksep });
  g.setDefaultEdgeLabel(() => ({}));

  const groupNodes: N[] = [];
  const layoutTargets: N[] = [];
  for (const node of nodes) {
    if (node.type === 'group') groupNodes.push(node);
    else layoutTargets.push(node);
  }

  const dims = new Map<string, { width: number; height: number }>();
  for (const node of layoutTargets) {
    const width = node.measured?.width ?? node.width ?? nodeWidth;
    const height = node.measured?.height ?? node.height ?? nodeHeight;
    dims.set(node.id, { width, height });
    g.setNode(node.id, { width, height });
  }

  for (const edge of edges) {
    if (dims.has(edge.source) && dims.has(edge.target)) {
      g.setEdge(edge.source, edge.target);
    }
  }

  dagre.layout(g);

  const layouted = layoutTargets.map((node) => {
    const pos = g.node(node.id);
    const { width, height } = dims.get(node.id)!;
    return {
      ...node,
      position: { x: pos.x - width / 2, y: pos.y - height / 2 },
    };
  });

  return { nodes: [...groupNodes, ...layouted], edges };
}
```

Wait for initial measurement with `useNodesInitialized()`, then apply layout once and defer `fitView`:

```tsx
const nodesInitialized = useNodesInitialized();
const hasRun = useRef(false);

useEffect(() => {
  if (!nodesInitialized || hasRun.current) return;
  hasRun.current = true;
  const { nodes: nextNodes, edges: nextEdges } = getLayoutedElements(getNodes(), getEdges(), {
    direction: 'LR',
  });
  setNodes([...nextNodes]);
  setEdges([...nextEdges]);
  window.requestAnimationFrame(() => fitView({ duration: 300 }));
}, [nodesInitialized, getNodes, getEdges, setNodes, setEdges, fitView]);
```
