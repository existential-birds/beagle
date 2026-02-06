# Visualization Components

ReactFlow-based components for workflow visualization, custom nodes, and animated edges.

## Core Components

### Canvas

ReactFlow wrapper with aviation-specific defaults and background.

```typescript
type CanvasProps = ReactFlowProps & {
  children?: ReactNode;
};
```

**Usage:**

```tsx
import { Canvas } from "@/components/ai-elements/canvas";
import { Background, Controls, Panel } from "@xyflow/react";
import "@xyflow/react/dist/style.css";

<Canvas
  nodes={nodes}
  edges={edges}
  nodeTypes={nodeTypes}
  edgeTypes={edgeTypes}
  onNodesChange={onNodesChange}
  onEdgesChange={onEdgesChange}
>
  <Background bgColor="var(--sidebar)" />
  <Controls />
  <Panel position="top-left">
    <h3>Workflow</h3>
  </Panel>
</Canvas>
```

**Default Props:**
- `deleteKeyCode: ["Backspace", "Delete"]` - Keys to delete selected elements
- `fitView: true` - Automatically fit content in viewport
- `panOnDrag: false` - Disable pan on drag (use selection instead)
- `panOnScroll: true` - Enable pan on scroll
- `selectionOnDrag: true` - Enable selection box on drag
- `zoomOnDoubleClick: false` - Disable zoom on double click

**Features:**
- Includes Background component with sidebar color
- Accepts all ReactFlow props
- Optimized for workflow visualization

## Node Components

Custom node components built on shadcn/ui Card components.

### Node

Main node container with connection handles.

```typescript
type NodeProps = ComponentProps<typeof Card> & {
  handles: {
    target: boolean;
    source: boolean;
  };
};
```

**Props:**
- `handles: { target: boolean; source: boolean }` - Which handles to show (required)
- All Card component props

**Usage:**

```tsx
<Node handles={{ target: true, source: true }}>
  <NodeHeader>
    <NodeTitle>Process Data</NodeTitle>
    <NodeDescription>Transform input data</NodeDescription>
  </NodeHeader>
  <NodeContent>
    {/* Node content */}
  </NodeContent>
  <NodeFooter>
    Status: Running
  </NodeFooter>
</Node>
```

**Handle Positions:**
- Target: Left side (incoming connections)
- Source: Right side (outgoing connections)

**Default Styling:**
- Relative positioning for handles
- Auto height
- Fixed width (w-sm)
- Rounded corners

### NodeHeader

Header section with border bottom and secondary background.

```typescript
type NodeHeaderProps = ComponentProps<typeof CardHeader>;
```

**Usage:**

```tsx
<NodeHeader>
  <NodeTitle>Step 1</NodeTitle>
  <NodeDescription>Initial processing</NodeDescription>
  <NodeAction onClick={handleEdit}>
    <EditIcon />
  </NodeAction>
</NodeHeader>
```

**Default Styling:**
- Rounded top corners
- Border bottom
- Secondary background
- Compact padding (p-3)

### NodeTitle

Title text for node header.

```typescript
type NodeTitleProps = ComponentProps<typeof CardTitle>;
```

**Usage:**

```tsx
<NodeTitle>Data Processing</NodeTitle>
```

### NodeDescription

Secondary description text.

```typescript
type NodeDescriptionProps = ComponentProps<typeof CardDescription>;
```

**Usage:**

```tsx
<NodeDescription>
  Transform and validate input data
</NodeDescription>
```

### NodeAction

Action button in header (typically edit/delete).

```typescript
type NodeActionProps = ComponentProps<typeof CardAction>;
```

**Usage:**

```tsx
<NodeAction onClick={handleEdit}>
  <EditIcon className="size-4" />
</NodeAction>
```

### NodeContent

Main content area of the node.

```typescript
type NodeContentProps = ComponentProps<typeof CardContent>;
```

**Usage:**

```tsx
<NodeContent>
  <div className="space-y-2">
    <Label>Input</Label>
    <Input value={data.input} readOnly />
    <Label>Output</Label>
    <Input value={data.output} readOnly />
  </div>
</NodeContent>
```

**Default Styling:**
- Compact padding (p-3)

### NodeFooter

Footer section with border top and secondary background.

```typescript
type NodeFooterProps = ComponentProps<typeof CardFooter>;
```

**Usage:**

```tsx
<NodeFooter>
  <Badge variant="success">Completed</Badge>
  <span className="text-xs text-muted-foreground">
    Duration: 1.2s
  </span>
</NodeFooter>
```

**Default Styling:**
- Rounded bottom corners
- Border top
- Secondary background
- Compact padding (p-3)

## Edge Components

Custom edge types for different connection styles.

### Edge.Temporary

Dashed edge for temporary or preview connections.

```typescript
type TemporaryEdgeProps = EdgeProps;
```

**Usage:**

```tsx
const edgeTypes = {
  temporary: Edge.Temporary,
};

<Canvas edges={edges} edgeTypes={edgeTypes} />
```

**Features:**
- Simple Bezier curve
- Dashed stroke (5, 5)
- Ring color stroke
- Stroke width: 1

**Use Cases:**
- Drag preview connections
- Temporary workflow paths
- Suggested connections

### Edge.Animated

Animated edge with moving dot indicator.

```typescript
type AnimatedEdgeProps = EdgeProps;
```

**Usage:**

```tsx
const edgeTypes = {
  animated: Edge.Animated,
};

<Canvas edges={edges} edgeTypes={edgeTypes} />
```

**Features:**
- Bezier curve path
- Animated circle following edge path
- 2-second animation duration
- Infinite repeat
- Primary color dot (4px radius)

**Use Cases:**
- Active data flow
- Processing pipelines
- Real-time connections

**Implementation Details:**
- Uses `useInternalNode` to get node positions
- Calculates handle coordinates based on position
- Supports Left (target) and Right (source) handle positions
- Uses `getBezierPath` for smooth curves

## ReactFlow Integration

### Controls

Standard ReactFlow controls (zoom, fit view, etc.).

```typescript
import { Controls } from "@xyflow/react";
```

**Usage:**

```tsx
<Canvas>
  <Controls />
</Canvas>
```

### Panel

Panel for custom UI overlays.

```typescript
import { Panel } from "@xyflow/react";
```

**Usage:**

```tsx
<Canvas>
  <Panel position="top-left">
    <h3>Workflow Name</h3>
    <p>Status: Running</p>
  </Panel>
  <Panel position="bottom-right">
    <Button onClick={handleSave}>Save</Button>
  </Panel>
</Canvas>
```

**Positions:**
- `top-left`, `top-center`, `top-right`
- `bottom-left`, `bottom-center`, `bottom-right`

### Background

Background pattern for the canvas.

```typescript
import { Background } from "@xyflow/react";
```

**Usage:**

```tsx
<Canvas>
  <Background bgColor="var(--sidebar)" />
</Canvas>
```

## Custom Node Types

Example of creating custom node types with aviation-specific styling.

```tsx
import { Node, NodeHeader, NodeTitle, NodeContent, NodeFooter } from "@/components/ai-elements/node";
import type { NodeProps } from "@xyflow/react";

type ProcessNodeData = {
  label: string;
  status: "pending" | "running" | "completed" | "failed";
  input?: string;
  output?: string;
};

function ProcessNode({ data }: NodeProps<ProcessNodeData>) {
  const statusColors = {
    pending: "bg-gray-500",
    running: "bg-blue-500 animate-pulse",
    completed: "bg-green-500",
    failed: "bg-red-500",
  };

  return (
    <Node handles={{ target: true, source: true }}>
      <NodeHeader>
        <NodeTitle>{data.label}</NodeTitle>
      </NodeHeader>

      <NodeContent>
        {data.input && (
          <div className="space-y-1">
            <Label className="text-xs">Input</Label>
            <p className="text-xs text-muted-foreground">{data.input}</p>
          </div>
        )}
        {data.output && (
          <div className="space-y-1">
            <Label className="text-xs">Output</Label>
            <p className="text-xs text-muted-foreground">{data.output}</p>
          </div>
        )}
      </NodeContent>

      <NodeFooter>
        <div className="flex items-center gap-2">
          <div className={cn("size-2 rounded-full", statusColors[data.status])} />
          <span className="text-xs capitalize">{data.status}</span>
        </div>
      </NodeFooter>
    </Node>
  );
}

// Register custom node type
const nodeTypes = {
  process: ProcessNode,
};

<Canvas nodeTypes={nodeTypes} />
```

## Complete Example

```tsx
import { useState } from "react";
import { Canvas } from "@/components/ai-elements/canvas";
import {
  Node,
  NodeHeader,
  NodeTitle,
  NodeDescription,
  NodeContent,
  NodeFooter,
} from "@/components/ai-elements/node";
import { Edge } from "@/components/ai-elements/edge";
import {
  Background,
  Controls,
  Panel,
  useNodesState,
  useEdgesState,
  addEdge,
  type Connection,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";

const initialNodes = [
  {
    id: "1",
    type: "custom",
    position: { x: 0, y: 0 },
    data: { label: "Start", status: "completed" },
  },
  {
    id: "2",
    type: "custom",
    position: { x: 250, y: 0 },
    data: { label: "Process", status: "running" },
  },
  {
    id: "3",
    type: "custom",
    position: { x: 500, y: 0 },
    data: { label: "End", status: "pending" },
  },
];

const initialEdges = [
  {
    id: "e1-2",
    source: "1",
    target: "2",
    type: "animated",
  },
  {
    id: "e2-3",
    source: "2",
    target: "3",
    type: "temporary",
  },
];

function CustomNode({ data }) {
  return (
    <Node handles={{ target: true, source: true }}>
      <NodeHeader>
        <NodeTitle>{data.label}</NodeTitle>
        <NodeDescription>Step in workflow</NodeDescription>
      </NodeHeader>
      <NodeContent>
        <p className="text-sm">Status: {data.status}</p>
      </NodeContent>
      <NodeFooter>
        <Badge variant={data.status === "completed" ? "success" : "default"}>
          {data.status}
        </Badge>
      </NodeFooter>
    </Node>
  );
}

const nodeTypes = {
  custom: CustomNode,
};

const edgeTypes = {
  temporary: Edge.Temporary,
  animated: Edge.Animated,
};

function WorkflowCanvas() {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);

  const onConnect = (connection: Connection) => {
    setEdges((eds) => addEdge({ ...connection, type: "animated" }, eds));
  };

  return (
    <div className="h-screen">
      <Canvas
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
      >
        <Background bgColor="var(--sidebar)" />
        <Controls />
        <Panel position="top-left">
          <div className="rounded-lg bg-background p-4 shadow-lg">
            <h3 className="font-semibold">Workflow</h3>
            <p className="text-sm text-muted-foreground">
              {nodes.length} nodes, {edges.length} edges
            </p>
          </div>
        </Panel>
      </Canvas>
    </div>
  );
}
```

## Handle Positioning

The edge components use custom handle coordinate calculation:

```typescript
const getHandleCoordsByPosition = (node, handlePosition) => {
  const handleType = handlePosition === Position.Left ? "target" : "source";
  const handle = node.internals.handleBounds?.[handleType]?.find(
    (h) => h.position === handlePosition
  );

  // Calculate absolute coordinates
  const offsetX = handlePosition === Position.Right ? handle.width : 0;
  const offsetY = handlePosition === Position.Bottom ? handle.height : 0;

  const x = node.internals.positionAbsolute.x + handle.x + offsetX;
  const y = node.internals.positionAbsolute.y + handle.y + offsetY;

  return [x, y];
};
```

This ensures edges connect properly to handle centers.

## Styling Tips

### Node Widths

Control node width with Tailwind classes:

```tsx
<Node handles={handles} className="w-64">
  {/* wider node */}
</Node>

<Node handles={handles} className="w-96">
  {/* extra wide node */}
</Node>
```

### Edge Colors

Customize edge colors via className:

```tsx
// In custom edge component
<BaseEdge
  className="stroke-2 stroke-primary"
  id={id}
  path={edgePath}
/>
```

### Node Status Indicators

Add visual status indicators:

```tsx
<NodeFooter>
  <div className="flex items-center gap-2">
    <div className={cn(
      "size-2 rounded-full",
      status === "running" && "bg-blue-500 animate-pulse",
      status === "completed" && "bg-green-500",
      status === "failed" && "bg-red-500"
    )} />
    <span className="text-xs">{status}</span>
  </div>
</NodeFooter>
```

## Integration with Aviation Nodes

AI Elements Canvas integrates seamlessly with custom aviation-specific node types. The Node component provides a flexible base for domain-specific extensions:

```tsx
// Aviation-specific node
function FlightPlanNode({ data }) {
  return (
    <Node handles={{ target: true, source: true }}>
      <NodeHeader>
        <NodeTitle>{data.flightNumber}</NodeTitle>
        <NodeDescription>{data.route}</NodeDescription>
      </NodeHeader>
      <NodeContent>
        <div className="space-y-2 text-xs">
          <div>Departure: {data.departure}</div>
          <div>Arrival: {data.arrival}</div>
          <div>Aircraft: {data.aircraft}</div>
        </div>
      </NodeContent>
      <NodeFooter>
        <Badge>{data.status}</Badge>
      </NodeFooter>
    </Node>
  );
}
```
