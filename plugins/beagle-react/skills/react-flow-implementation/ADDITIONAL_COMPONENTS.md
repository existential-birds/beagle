# React Flow Additional Components

## MiniMap

```tsx
import { MiniMap } from '@xyflow/react';

<MiniMap
  nodeColor={(node) => {
    switch (node.type) {
      case 'input': return '#6ede87';
      case 'output': return '#ff0072';
      default: return '#eee';
    }
  }}
  nodeStrokeWidth={3}
  zoomable
  pannable
/>
```

## Controls

```tsx
import { Controls } from '@xyflow/react';

<Controls
  showZoom={true}
  showFitView={true}
  showInteractive={true}
  position="bottom-left"
/>
```

## Background

```tsx
import { Background, BackgroundVariant } from '@xyflow/react';

// Dots pattern
<Background variant={BackgroundVariant.Dots} gap={16} size={1} />

// Lines pattern
<Background variant={BackgroundVariant.Lines} gap={24} />

// Cross pattern
<Background variant={BackgroundVariant.Cross} />

// Custom color
<Background bgColor="#1a1a1a" color="#444" />
```

## NodeToolbar

```tsx
import { NodeToolbar, Position } from '@xyflow/react';

function CustomNode({ id, selected }: NodeProps) {
  return (
    <>
      <NodeToolbar
        isVisible={selected}
        position={Position.Top}
      >
        <button onClick={() => console.log('delete', id)}>Delete</button>
        <button>Edit</button>
      </NodeToolbar>
      <div>Node Content</div>
    </>
  );
}
```

## NodeResizer

```tsx
import { NodeResizer } from '@xyflow/react';

function ResizableNode({ selected }: NodeProps) {
  return (
    <>
      <NodeResizer
        isVisible={selected}
        minWidth={100}
        minHeight={50}
        handleStyle={{ width: 8, height: 8 }}
      />
      <div style={{ padding: 10 }}>
        Resize me
      </div>
    </>
  );
}
```

## EdgeToolbar (for custom edges)

```tsx
import { EdgeToolbar } from '@xyflow/react';

function CustomEdge({ id, selected, ...props }: EdgeProps) {
  const [path, labelX, labelY] = getSmoothStepPath(props);

  return (
    <>
      <BaseEdge path={path} />
      <EdgeToolbar x={labelX} y={labelY} isVisible={selected}>
        <button>Edit</button>
      </EdgeToolbar>
    </>
  );
}
```

## Panel

```tsx
import { Panel } from '@xyflow/react';

// Positions: top-left, top-center, top-right, bottom-left, bottom-center, bottom-right
<ReactFlow ...>
  <Panel position="top-right">
    <button onClick={onSave}>Save</button>
    <button onClick={onRestore}>Restore</button>
  </Panel>
</ReactFlow>
```
