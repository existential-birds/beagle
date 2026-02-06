# Dagre Configuration Reference

Complete configuration options for dagre layout algorithm.

## Graph-Level Options

Set via `g.setGraph(options)`:

| Option | Default | Description |
|--------|---------|-------------|
| `rankdir` | `'TB'` | Layout direction: `'TB'` (top-bottom), `'BT'` (bottom-top), `'LR'` (left-right), `'RL'` (right-left) |
| `align` | `undefined` | Node alignment within rank: `'UL'`, `'UR'`, `'DL'`, `'DR'`. `U`=up, `D`=down, `L`=left, `R`=right |
| `nodesep` | `50` | Horizontal spacing between nodes in same rank (pixels) |
| `edgesep` | `10` | Horizontal spacing between edges (pixels) |
| `ranksep` | `50` | Vertical spacing between ranks (pixels) |
| `marginx` | `0` | Horizontal margin around graph (pixels) |
| `marginy` | `0` | Vertical margin around graph (pixels) |
| `acyclicer` | `undefined` | Set to `'greedy'` for greedy cycle removal heuristic |
| `ranker` | `'network-simplex'` | Rank assignment algorithm: `'network-simplex'`, `'tight-tree'`, `'longest-path'` |

### Example

```typescript
g.setGraph({
  rankdir: 'LR',          // Horizontal layout
  align: 'UL',            // Align nodes to upper-left
  nodesep: 80,            // 80px horizontal spacing
  ranksep: 100,           // 100px between ranks
  marginx: 20,            // 20px horizontal margin
  marginy: 20,            // 20px vertical margin
  ranker: 'tight-tree',   // Faster ranking algorithm
});
```

### Ranker Algorithms

| Algorithm | Speed | Quality | Use Case |
|-----------|-------|---------|----------|
| `network-simplex` | Slower | Best | Default, optimal for most graphs |
| `tight-tree` | Fast | Good | Large graphs where speed matters |
| `longest-path` | Fastest | Acceptable | Very large graphs, quick preview |

## Node-Level Options

Set via `g.setNode(nodeId, options)`:

| Option | Default | Description |
|--------|---------|-------------|
| `width` | `0` | Node width in pixels (required for layout) |
| `height` | `0` | Node height in pixels (required for layout) |

### Output Properties

After `dagre.layout(g)`, each node gains:

| Property | Description |
|----------|-------------|
| `x` | Center x-coordinate |
| `y` | Center y-coordinate |

### Example

```typescript
// Setting node dimensions
g.setNode('node-1', { width: 200, height: 50 });

// After layout, reading position
dagre.layout(g);
const { x, y } = g.node('node-1'); // Center coordinates
```

## Edge-Level Options

Set via `g.setEdge(source, target, options)`:

| Option | Default | Description |
|--------|---------|-------------|
| `minlen` | `1` | Minimum number of ranks between source and target |
| `weight` | `1` | Edge weight for prioritization (higher = shorter path) |
| `width` | `0` | Edge label width in pixels |
| `height` | `0` | Edge label height in pixels |
| `labelpos` | `'r'` | Label position: `'l'` (left), `'c'` (center), `'r'` (right) |
| `labeloffset` | `10` | Pixels to offset label from edge |

### Output Properties

After `dagre.layout(g)`, each edge gains:

| Property | Description |
|----------|-------------|
| `points` | Array of `{x, y}` control points for edge path |
| `x` | Label center x-coordinate (if label dimensions set) |
| `y` | Label center y-coordinate (if label dimensions set) |

### Example

```typescript
// High priority edge (shorter path)
g.setEdge('a', 'b', { weight: 2 });

// Force separation of 3 ranks
g.setEdge('a', 'c', { minlen: 3 });

// Edge with label
g.setEdge('a', 'd', {
  width: 50,
  height: 20,
  labelpos: 'c',
});

// After layout
dagre.layout(g);
const edge = g.edge('a', 'b');
console.log(edge.points); // [{x: 0, y: 0}, {x: 50, y: 50}, ...]
```

## Graph Methods

### Reading Graph State

```typescript
// Get all node IDs
const nodeIds = g.nodes(); // ['a', 'b', 'c']

// Get all edges
const edges = g.edges(); // [{v: 'a', w: 'b'}, ...]

// Check if node exists
g.hasNode('a'); // true/false

// Check if edge exists
g.hasEdge('a', 'b'); // true/false

// Get node data
g.node('a'); // { width: 100, height: 50, x: 200, y: 100 }

// Get edge data
g.edge('a', 'b'); // { points: [...], weight: 1 }
```

### Modifying Graph

```typescript
// Remove node (also removes connected edges)
g.removeNode('a');

// Remove edge
g.removeEdge('a', 'b');

// Get predecessors (nodes with edges TO this node)
g.predecessors('b'); // ['a']

// Get successors (nodes with edges FROM this node)
g.successors('a'); // ['b', 'c']

// Get all connected nodes (in + out)
g.neighbors('a'); // ['b', 'c', 'd']
```

## TypeScript Types

```typescript
import dagre from '@dagrejs/dagre';

interface GraphOptions {
  rankdir?: 'TB' | 'BT' | 'LR' | 'RL';
  align?: 'UL' | 'UR' | 'DL' | 'DR';
  nodesep?: number;
  edgesep?: number;
  ranksep?: number;
  marginx?: number;
  marginy?: number;
  acyclicer?: 'greedy';
  ranker?: 'network-simplex' | 'tight-tree' | 'longest-path';
}

interface NodeOptions {
  width: number;
  height: number;
}

interface NodeOutput extends NodeOptions {
  x: number;
  y: number;
}

interface EdgeOptions {
  minlen?: number;
  weight?: number;
  width?: number;
  height?: number;
  labelpos?: 'l' | 'c' | 'r';
  labeloffset?: number;
}

interface EdgeOutput extends EdgeOptions {
  points: Array<{ x: number; y: number }>;
  x?: number;  // If label dimensions set
  y?: number;  // If label dimensions set
}
```

## Performance Considerations

### Graph Size Guidelines

| Nodes | Performance | Recommendation |
|-------|-------------|----------------|
| < 100 | Fast | Use `network-simplex` |
| 100-500 | Moderate | Consider `tight-tree` |
| 500-1000 | Slow | Use `longest-path`, layout in worker |
| > 1000 | Very slow | Virtualize, paginate, or use WebGL renderer |

### Optimization Tips

1. **Reuse graph instance** when only positions change
2. **Layout in Web Worker** for graphs > 200 nodes
3. **Debounce layout calls** during rapid changes
4. **Cache layout results** for static portions

### Web Worker Example

```typescript
// layout.worker.ts
import dagre from '@dagrejs/dagre';

self.onmessage = (e) => {
  const { nodes, edges, options } = e.data;

  const g = new dagre.graphlib.Graph();
  g.setGraph(options);
  g.setDefaultEdgeLabel(() => ({}));

  nodes.forEach((n) => g.setNode(n.id, { width: n.width, height: n.height }));
  edges.forEach((e) => g.setEdge(e.source, e.target));

  dagre.layout(g);

  const positions = nodes.map((n) => ({
    id: n.id,
    x: g.node(n.id).x,
    y: g.node(n.id).y,
  }));

  self.postMessage({ positions });
};
```

## Comparison with Alternatives

| Library | Best For | Bundle Size | Async |
|---------|----------|-------------|-------|
| **dagre** | Trees, hierarchies | ~30KB | No |
| **elkjs** | Complex constraints | ~150KB | Yes |
| **d3-hierarchy** | Pure trees only | ~10KB | No |
| **d3-force** | Organic layouts | ~15KB | Iterative |

Choose dagre when:
- Graph is hierarchical/tree-like
- Need simple, fast layouts
- Bundle size matters
- Don't need edge routing around nodes

## Animated Layout Transitions

Programmatic animation for smooth position changes:

```typescript
const animateLayout = (
  currentNodes: Node[],
  newNodes: Node[],
  setNodes: (nodes: Node[]) => void,
  duration = 300
) => {
  const startPositions = new Map(
    currentNodes.map((n) => [n.id, { ...n.position }])
  );

  const animate = (progress: number) => {
    const interpolated = newNodes.map((node) => {
      const start = startPositions.get(node.id);
      if (!start) return node;

      return {
        ...node,
        position: {
          x: start.x + (node.position.x - start.x) * progress,
          y: start.y + (node.position.y - start.y) * progress,
        },
      };
    });
    setNodes(interpolated);
  };

  const startTime = Date.now();
  const tick = () => {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(elapsed / duration, 1);
    // Ease-out curve
    const eased = 1 - Math.pow(1 - progress, 3);
    animate(eased);
    if (progress < 1) requestAnimationFrame(tick);
  };
  tick();
};

// Usage
const onLayout = (direction: 'TB' | 'LR') => {
  const { nodes: layouted } = getLayoutedElements(nodes, edges, { direction });
  animateLayout(nodes, layouted, setNodes, 400);
};
```
