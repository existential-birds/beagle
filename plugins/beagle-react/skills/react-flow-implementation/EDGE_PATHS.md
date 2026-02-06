# Edge Path Utilities

React Flow provides utilities for generating SVG paths for custom edges.

## Available Path Functions

### getBezierPath (Default)
```tsx
import { getBezierPath, Position } from '@xyflow/react';

const [path, labelX, labelY, offsetX, offsetY] = getBezierPath({
  sourceX: 0,
  sourceY: 0,
  sourcePosition: Position.Right,
  targetX: 200,
  targetY: 100,
  targetPosition: Position.Left,
  curvature: 0.25,  // optional, default 0.25
});
```

### getSmoothStepPath
```tsx
import { getSmoothStepPath } from '@xyflow/react';

const [path, labelX, labelY] = getSmoothStepPath({
  sourceX, sourceY, sourcePosition,
  targetX, targetY, targetPosition,
  borderRadius: 5,      // Corner rounding
  offset: 20,           // Distance from handle before first bend
  stepPosition: 0.5,    // 0-1, where bend occurs (0=source, 1=target)
});
```

### getStraightPath
```tsx
import { getStraightPath } from '@xyflow/react';

const [path, labelX, labelY] = getStraightPath({
  sourceX, sourceY,
  targetX, targetY,
});
```

### getSimpleBezierPath
```tsx
import { getSimpleBezierPath } from '@xyflow/react';

const [path, labelX, labelY] = getSimpleBezierPath({
  sourceX, sourceY, sourcePosition,
  targetX, targetY, targetPosition,
});
```

## Custom Edge Example

```tsx
import { BaseEdge, EdgeProps, getSmoothStepPath, EdgeLabelRenderer } from '@xyflow/react';

function CustomEdge({
  id, sourceX, sourceY, targetX, targetY,
  sourcePosition, targetPosition, data, style
}: EdgeProps) {
  const [edgePath, labelX, labelY] = getSmoothStepPath({
    sourceX, sourceY, sourcePosition,
    targetX, targetY, targetPosition,
  });

  return (
    <>
      <BaseEdge id={id} path={edgePath} style={style} />
      <EdgeLabelRenderer>
        <div
          style={{
            position: 'absolute',
            transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
            pointerEvents: 'all',
          }}
          className="nodrag nopan"
        >
          <button onClick={() => console.log('edge clicked', id)}>
            {data?.label}
          </button>
        </div>
      </EdgeLabelRenderer>
    </>
  );
}
```

## Edge Markers

```tsx
// Built-in markers
const edge = {
  id: 'e1-2',
  source: '1',
  target: '2',
  markerEnd: MarkerType.ArrowClosed,
  // or custom:
  markerEnd: {
    type: MarkerType.Arrow,
    color: '#f00',
    width: 20,
    height: 20,
  },
};
```
