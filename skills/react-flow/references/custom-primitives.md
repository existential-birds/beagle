# Custom Nodes, Edges & UI Primitives

## Custom Nodes & Dynamic Handles

Import `CSSProperties` from `'react'` (never `'@xyflow/react'`). Always wrap custom nodes in `memo()`.

When adding or removing `<Handle>` elements dynamically, `useUpdateNodeInternals()` takes **no arguments** and returns an updater function `updateNodeInternals(id)`. You **must** call `updateNodeInternals(id)` inside `useEffect` **after** React commits the new handles to the DOM — calling it synchronously inside `onClick` measures stale DOM handles.

```tsx
import { memo, useEffect, useState, type CSSProperties } from 'react';
import {
  Handle,
  Position,
  useUpdateNodeInternals,
  type Node,
  type NodeProps,
} from '@xyflow/react';

export type MultiPortNode = Node<{ label: string; portCount: number }, 'multiPort'>;

const handleStyleA: CSSProperties = { top: 12 };
const handleStyleB: CSSProperties = { bottom: 12, top: 'auto' };

export const MultiPortNodeComponent = memo(function MultiPortNodeComponent({
  id,
  data,
  isConnectable,
  selected,
}: NodeProps<MultiPortNode>) {
  const [portCount, setPortCount] = useState(data.portCount ?? 1);
  const updateNodeInternals = useUpdateNodeInternals();

  useEffect(() => {
    updateNodeInternals(id);
  }, [id, portCount, updateNodeInternals]);

  return (
    <div className={`rounded border bg-white p-3 ${selected ? 'ring-2 ring-blue-500' : ''}`}>
      <Handle type="target" position={Position.Left} id="in-a" style={handleStyleA} isConnectable={isConnectable} />
      <Handle type="target" position={Position.Left} id="in-b" style={handleStyleB} isConnectable={isConnectable} />

      <div className="text-sm font-medium">{data.label}</div>
      <button
        type="button"
        className="nodrag nopan mt-1 text-xs underline"
        onClick={() => setPortCount((c) => c + 1)}
      >
        Add Output ({portCount})
      </button>

      {Array.from({ length: portCount }, (_, i) => (
        <Handle
          key={`out-${i}`}
          id={`out-${i}`}
          type="source"
          position={Position.Right}
          style={{ top: 14 + i * 14 }}
          isConnectable={isConnectable}
        />
      ))}
    </div>
  );
});
```

## Toolbars, Resizers & Panels

```tsx
import {
  NodeToolbar,
  NodeResizer,
  EdgeToolbar,
  Panel,
  BaseEdge,
  Position,
  getSmoothStepPath,
  type NodeProps,
  type EdgeProps,
} from '@xyflow/react';

function ResizableNode({ selected }: NodeProps) {
  return (
    <>
      <NodeResizer isVisible={selected} minWidth={120} minHeight={60} />
      <NodeToolbar isVisible={selected} position={Position.Top}>
        <button type="button" className="nodrag">Inspect</button>
      </NodeToolbar>
      <div className="h-full w-full p-2">Resizable Content</div>
    </>
  );
}

function ToolbarEdge({ selected, ...props }: EdgeProps) {
  const [path, labelX, labelY] = getSmoothStepPath(props);
  return (
    <>
      <BaseEdge id={props.id} path={path} />
      <EdgeToolbar edgeId={props.id} x={labelX} y={labelY} isVisible={selected}>
        <button type="button" className="nodrag">Edit Edge</button>
      </EdgeToolbar>
    </>
  );
}

// Overlay UI pinned to canvas corners ('top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right')
<ReactFlow nodes={nodes} edges={edges}>
  <Panel position="top-right">
    <button type="button" onClick={onSave}>Save</button>
  </Panel>
</ReactFlow>
```

## Custom Edges, Path Utils & Labels

All path helpers return `[path, labelX, labelY, offsetX, offsetY]`:

- `getBezierPath({ ...props, curvature: 0.25 })`
- `getSmoothStepPath({ ...props, borderRadius: 8, offset: 20, stepPosition: 0.5 })` (`borderRadius: 0` produces sharp orthogonal steps; `stepPosition` controls bend placement from `0` source to `1` target)
- `getStraightPath({ sourceX, sourceY, targetX, targetY })`
- `getSimpleBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition })`

Use `EdgeLabelRenderer` with `pointerEvents: 'all'` and `className="nodrag nopan"` for interactive HTML edge labels, or `EdgeText` for SVG text with a pill background (avoid bare SVG `<text>` without positioning/background).

```tsx
import { memo } from 'react';
import {
  BaseEdge,
  EdgeLabelRenderer,
  EdgeText,
  MarkerType,
  getSmoothStepPath,
  type Edge,
  type EdgeProps,
} from '@xyflow/react';

export type ActionEdge = Edge<{ label?: string }, 'action'>;

export const ActionEdgeComponent = memo(function ActionEdgeComponent({
  id,
  data,
  markerEnd,
  style,
  ...props
}: EdgeProps<ActionEdge>) {
  const [edgePath, labelX, labelY] = getSmoothStepPath({ ...props, borderRadius: 6 });

  return (
    <>
      <BaseEdge id={id} path={edgePath} style={style} markerEnd={markerEnd} interactionWidth={20} />
      <EdgeLabelRenderer>
        <div
          style={{
            position: 'absolute',
            transform: `translate(-50%, -50%) translate(${labelX}px, ${labelY}px)`,
            pointerEvents: 'all',
          }}
          className="nodrag nopan"
        >
          <button type="button" onClick={() => onDeleteEdge(id)}>
            {data?.label ?? '×'}
          </button>
        </div>
      </EdgeLabelRenderer>
    </>
  );
});

// Built-in or custom edge markers
const edgeWithArrow = {
  id: 'e1-2',
  source: '1',
  target: '2',
  markerEnd: { type: MarkerType.ArrowClosed, width: 18, height: 18 },
};
```

For non-interactive SVG labels with background styling, prefer `<EdgeText x={labelX} y={labelY} label={data?.label ?? ''} labelBgStyle={{ fill: '#fff' }} />`.

## Deletion Guard (`onBeforeDelete`)

`onBeforeDelete` runs before `Backspace`/`Delete` or `deleteElements()` removes items. Return `false` to abort, `true` to allow all, or `{ nodes, edges }` to filter what gets deleted:

```tsx
import type { OnBeforeDelete } from '@xyflow/react';

const onBeforeDelete: OnBeforeDelete<AppNode, AppEdge> = async ({ nodes, edges }) => {
  return {
    nodes: nodes.filter((n) => n.deletable !== false),
    edges,
  };
};
```
