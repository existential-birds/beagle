# Frontend Code Review

## Arguments

- `--parallel`: Spawn specialized subagents per technology area
- Path: Target directory (default: current working directory)

## Step 1: Identify Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.(tsx?|css)$'
```

## Step 2: Detect Technologies

```bash
# Detect React Flow
grep -r "@xyflow/react\|ReactFlow\|useNodesState" --include="*.tsx" -l | head -3

# Detect Zustand
grep -r "from 'zustand'\|create\(\(" --include="*.ts" --include="*.tsx" -l | head -3

# Detect Tailwind v4
grep -r "@theme\|@layer theme" --include="*.css" -l | head -3

# Check for test files
git diff --name-only $(git merge-base HEAD main)..HEAD | grep -E '\.test\.tsx?$'
```

## Step 3: Technology-Specific Review Guidelines

The following sections provide comprehensive review guidance for each technology area. Apply the relevant sections based on detected technologies:

- **Always apply**: React Router, shadcn/ui
- **Conditionally apply**: React Flow, Zustand, Tailwind v4, Vitest (based on detection results)

---

# React Router Code Review

## Review Checklist

- [ ] Data loaded via `loader` not `useEffect`
- [ ] Route params accessed type-safely with validation
- [ ] Using `defer()` for parallel data fetching when appropriate
- [ ] Mutations use `<Form>` or `useFetcher` not manual fetch
- [ ] Actions handle both success and error cases
- [ ] Error boundaries with `errorElement` on routes
- [ ] Using `isRouteErrorResponse()` to check error types
- [ ] Navigation uses `<Link>` over `navigate()` where possible
- [ ] Pending states shown via `useNavigation()` or `fetcher.state`
- [ ] No navigation in render (only in effects or handlers)

## Critical Issues to Flag

### Data Loading Anti-Patterns

**Using useEffect Instead of Loaders**
- **Issue**: Race conditions, loading states, unnecessary client-side fetching
- **Fix**: Use route loaders for data fetching
- **Example**:
```tsx
// BAD - Loading data in useEffect
function UserProfile() {
  const [user, setUser] = useState(null);
  const { userId } = useParams();
  useEffect(() => {
    fetch(`/api/users/${userId}`).then(r => r.json()).then(setUser);
  }, [userId]);
}

// GOOD - Using loader
const loader = async ({ params }) => {
  const response = await fetch(`/api/users/${params.userId}`);
  if (!response.ok) throw new Response("Not Found", { status: 404 });
  return response.json();
};
```

**Unsafe Route Params Access**
- **Issue**: Runtime errors from missing or invalid params
- **Fix**: Validate params before use, preferably with zod
- **Example**:
```tsx
// GOOD - Validate params
const loader = async ({ params }) => {
  const userId = params.userId;
  if (!userId) throw new Response("User ID required", { status: 400 });
  return fetch(`/api/users/${userId}`);
};
```

**Sequential Data Fetching**
- **Issue**: Slow page loads when data can be fetched in parallel
- **Fix**: Use `Promise.all()` or `defer()` for non-critical data
- **Example**:
```tsx
// GOOD - Parallel fetching
const loader = async ({ params }) => {
  const [user, posts, comments] = await Promise.all([
    fetchUser(params.userId),
    fetchPosts(params.userId),
    fetchComments(params.userId),
  ]);
  return { user, posts, comments };
};
```

### Error Handling Anti-Patterns

**Missing Error Boundaries**
- **Issue**: Entire app crashes on route errors
- **Fix**: Add `errorElement` to routes
- **Example**:
```tsx
// GOOD - Error boundaries at route level
{
  path: "users/:userId",
  element: <UserProfile />,
  errorElement: <UserErrorBoundary />,
  loader: userLoader
}
```

**Not Using isRouteErrorResponse**
- **Issue**: Unsafe error access, runtime errors in error handlers
- **Fix**: Always use `isRouteErrorResponse()` to check error types
- **Example**:
```tsx
// GOOD - Type-safe error checking
import { isRouteErrorResponse } from 'react-router-dom';

function ErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    return <div>Error {error.status}: {error.statusText}</div>;
  }

  if (error instanceof Error) {
    return <div>Unexpected Error: {error.message}</div>;
  }

  return <div>An unknown error occurred</div>;
}
```

**Throwing Raw Errors Instead of Responses**
- **Issue**: Missing status codes, inconsistent error format
- **Fix**: Throw Response objects with proper status codes
- **Example**:
```tsx
// GOOD - Throwing Response objects
const loader = async ({ params }) => {
  const user = await db.user.findUnique({ where: { id: params.userId } });

  if (!user) {
    throw new Response('User not found', { status: 404 });
  }

  return user;
};
```

### Mutations Anti-Patterns

**Manual Form Submission with fetch**
- **Issue**: Missing navigation state, manual revalidation, no progressive enhancement
- **Fix**: Use `<Form>` and route actions
- **Example**:
```tsx
// GOOD - Using Form and action
import { Form, useNavigation, useActionData } from 'react-router-dom';

function CreateUser() {
  const navigation = useNavigation();
  const actionData = useActionData();
  const isSubmitting = navigation.state === 'submitting';

  return (
    <Form method="post">
      <input name="name" />
      {actionData?.error && <div>{actionData.error}</div>}
      <button disabled={isSubmitting}>
        {isSubmitting ? 'Creating...' : 'Create'}
      </button>
    </Form>
  );
}
```

**Using Form When useFetcher is Appropriate**
- **Issue**: Unnecessary navigation, losing current page state
- **Fix**: Use `useFetcher` for mutations that should stay on current page
- **Example**:
```tsx
// GOOD - useFetcher stays on current page
function TodoItem({ todo }) {
  const fetcher = useFetcher();

  const isComplete = fetcher.formData
    ? fetcher.formData.get('complete') === 'true'
    : todo.complete;

  return (
    <fetcher.Form method="post" action={`/todos/${todo.id}/toggle`}>
      <input type="hidden" name="complete" value={String(!isComplete)} />
      <button disabled={fetcher.state !== 'idle'}>Toggle</button>
    </fetcher.Form>
  );
}
```

**Missing Optimistic UI**
- **Issue**: Slow perceived performance, no immediate feedback
- **Fix**: Show optimistic state using `fetcher.formData`
- **Example**:
```tsx
// GOOD - Optimistic UI
function LikeButton({ postId, liked, likeCount }) {
  const fetcher = useFetcher();

  const optimisticLiked = fetcher.formData
    ? fetcher.formData.get('liked') === 'true'
    : liked;

  const optimisticCount = fetcher.formData
    ? optimisticLiked ? likeCount + 1 : likeCount - 1
    : likeCount;

  return (
    <fetcher.Form method="post">
      <input type="hidden" name="liked" value={String(!optimisticLiked)} />
      <button>{optimisticLiked ? '❤️' : '🤍'} {optimisticCount}</button>
    </fetcher.Form>
  );
}
```

### Navigation Anti-Patterns

**Using navigate() Instead of Link**
- **Issue**: Missing accessibility, no progressive enhancement, can't open in new tab
- **Fix**: Use `<Link>` for user-initiated navigation
- **Example**:
```tsx
// GOOD - Use Link for navigation
function UserCard({ userId }) {
  return (
    <Link to={`/users/${userId}`} className="user-card">
      <h3>User {userId}</h3>
    </Link>
  );
}
```

**Missing Pending UI States**
- **Issue**: No feedback during navigation, feels broken
- **Fix**: Show loading state via `useNavigation()`
- **Example**:
```tsx
// GOOD - Show loading state
import { useNavigation } from 'react-router-dom';

function UserList() {
  const users = useLoaderData();
  const navigation = useNavigation();

  return (
    <div>
      {navigation.state === 'loading' && <div className="loading-bar" />}
      <ul className={navigation.state === 'loading' ? 'opacity-50' : ''}>
        {users.map(user => (
          <li key={user.id}>
            <Link to={`/users/${user.id}`}>{user.name}</Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

**Not Using NavLink for Active Styles**
- **Issue**: Manual active state management, inconsistent UI
- **Fix**: Use `<NavLink>` with className function
- **Example**:
```tsx
// GOOD - NavLink with className function
import { NavLink } from 'react-router-dom';

function Navigation() {
  return (
    <nav>
      <NavLink
        to="/"
        end
        className={({ isActive }) => isActive ? 'active' : ''}
      >
        Home
      </NavLink>
    </nav>
  );
}
```

---

# shadcn/ui Code Review

## Review Checklist

- [ ] `cn()` receives className, not CVA variants
- [ ] `VariantProps<typeof variants>` exported for consumers
- [ ] Compound variants used for complex state combinations
- [ ] `asChild` pattern uses `@radix-ui/react-slot`
- [ ] Context used for component composition (Card, Accordion, etc.)
- [ ] `focus-visible:` states, not just `:focus`
- [ ] `aria-invalid`, `aria-disabled` for form states
- [ ] `disabled:` variants for all interactive elements
- [ ] `sr-only` for screen reader text
- [ ] `data-slot` attributes for targetable composition parts
- [ ] CSS uses `has()` selectors for state-based styling
- [ ] No direct className overrides of variant styles

## Critical Issues to Flag

### CVA Patterns

**className Passed to CVA Instead of cn()**
- **Issue**: CVA variants cannot be overridden by consumers
- **Fix**: Pass className to `cn()` after CVA, not as a CVA variant
- **Example**:
```tsx
// GOOD - className in cn()
import { cva, type VariantProps } from "class-variance-authority"

const buttonVariants = cva("base-styles", {
  variants: {
    variant: { default: "bg-primary", destructive: "bg-destructive" },
    size: { sm: "h-9", lg: "h-11" },
  },
  defaultVariants: { variant: "default", size: "default" },
})

export function Button({ variant, size, className, ...props }) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}
```

**Missing VariantProps Export**
- **Issue**: Consumers cannot type-check variant props correctly
- **Fix**: Export VariantProps for type safety
- **Example**:
```tsx
// GOOD - export VariantProps
const buttonVariants = cva(...)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

export function Button({ variant, size, className, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />
}
```

**Not Using Compound Variants**
- **Issue**: Complex state combinations create verbose, repetitive variant definitions
- **Fix**: Use `compoundVariants` for state combinations
- **Example**:
```tsx
// GOOD - use compoundVariants
const buttonVariants = cva("rounded font-medium", {
  variants: {
    variant: {
      default: "bg-primary text-primary-foreground",
      outline: "border border-input bg-background",
    },
    size: {
      sm: "h-9 px-3",
      lg: "h-11 px-8",
    },
  },
  compoundVariants: [
    {
      variant: "outline",
      size: "sm",
      class: "border-2",
    },
  ],
})
```

### Component Composition

**asChild Without Slot**
- **Issue**: The asChild pattern requires `@radix-ui/react-slot` to work correctly
- **Fix**: Use Slot from @radix-ui/react-slot
- **Example**:
```tsx
// GOOD - using Slot
import { Slot } from "@radix-ui/react-slot"

export function Button({ asChild, className, variant, ...props }) {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      className={cn(buttonVariants({ variant }), className)}
      {...props}
    />
  );
}
```

**Missing Context for Compound Components**
- **Issue**: Component parts cannot communicate state without Context
- **Fix**: Use React Context for state sharing
- **Example**:
```tsx
// GOOD - using Context
const CardContext = React.createContext<{ variant?: string }>({})

export function Card({ variant = "default", children, ...props }) {
  return (
    <CardContext.Provider value={{ variant }}>
      <div className={cn(cardVariants({ variant }))} {...props}>
        {children}
      </div>
    </CardContext.Provider>
  );
}

export function CardHeader({ className, ...props }) {
  const { variant } = React.useContext(CardContext)
  return (
    <div
      className={cn(headerVariants({ variant }), className)}
      {...props}
    />
  );
}
```

**Not Forwarding Refs with asChild**
- **Issue**: Refs break when using asChild without forwardRef
- **Fix**: Use React.forwardRef
- **Example**:
```tsx
// GOOD - forwardRef with asChild
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ asChild = false, className, variant, ...props }, ref) => {
    const Comp = asChild ? Slot : "button"

    return (
      <Comp
        className={cn(buttonVariants({ variant }), className)}
        ref={ref}
        {...props}
      />
    );
  }
)
Button.displayName = "Button"
```

### Accessibility Patterns

**Using :focus Instead of :focus-visible**
- **Issue**: Visible focus rings on mouse clicks create poor UX
- **Fix**: Use `focus-visible:` for keyboard-only focus
- **Example**:
```tsx
// GOOD - :focus-visible shows ring only for keyboard
const buttonVariants = cva(
  "rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
)
```

**Missing aria-invalid for Form States**
- **Issue**: Screen readers cannot announce validation errors
- **Fix**: Use `aria-invalid` with proper error announcement
- **Example**:
```tsx
// GOOD - aria-invalid with proper error announcement
export function Input({ error, className, ...props }) {
  const errorId = React.useId()

  return (
    <div>
      <input
        className={cn(
          "border rounded focus-visible:ring-2",
          error && "border-destructive focus-visible:ring-destructive",
          className
        )}
        aria-invalid={error ? "true" : undefined}
        aria-describedby={error ? errorId : undefined}
        {...props}
      />
      {error && (
        <p id={errorId} className="text-sm text-destructive mt-1">
          {error}
        </p>
      )}
    </div>
  );
}
```

**Missing Screen Reader Text**
- **Issue**: Icon-only buttons need sr-only text for screen readers
- **Fix**: Add `sr-only` text or `aria-label`
- **Example**:
```tsx
// GOOD - sr-only text for screen readers
export function CloseButton({ onClick }) {
  return (
    <button onClick={onClick} aria-label="Close">
      <X className="h-4 w-4" />
      <span className="sr-only">Close</span>
    </button>
  );
}
```

### data-slot Pattern

**Missing data-slot Attributes**
- **Issue**: Component parts cannot be targeted by consumers for custom styling
- **Fix**: Add `data-slot` attributes to component parts
- **Example**:
```tsx
// GOOD - data-slot for targetable parts
export function Card({ children, ...props }) {
  return (
    <div className="border rounded-lg" data-slot="card" {...props}>
      {children}
    </div>
  );
}

export function CardHeader({ children, ...props }) {
  return (
    <div className="p-6" data-slot="card-header" {...props}>
      {children}
    </div>
  );
}

// Consumer can target with stable selector:
// <Card className="[&_[data-slot=card-header]]:bg-red-500">
```

**Not Using has() Selectors for State-Based Styling**
- **Issue**: Parent styling based on child state requires manual prop threading
- **Fix**: Use `has()` selector with `data-slot`
- **Example**:
```tsx
// GOOD - has() selector with data-slot
export function Card({ children, ...props }) {
  return (
    <div
      className="border has-[[data-slot=card-content][data-error]]:border-destructive"
      data-slot="card"
      {...props}
    >
      {children}
    </div>
  );
}

export function CardContent({ error, children, ...props }) {
  return (
    <div data-slot="card-content" data-error={error ? "" : undefined} {...props}>
      {error && <p className="text-sm text-destructive">{error}</p>}
      {children}
    </div>
  );
}
```

---

# React Flow Code Review (if detected)

## Critical Anti-Patterns

### Defining nodeTypes/edgeTypes Inside Components
- **Issue**: Causes all nodes to re-mount on every render
- **Fix**: Define outside component or use `useMemo`
- **Example**:
```tsx
// GOOD - defined outside component
const nodeTypes = { custom: CustomNode };
function Flow() {
  return <ReactFlow nodeTypes={nodeTypes} />;
}

// GOOD - useMemo if dynamic
function Flow() {
  const nodeTypes = useMemo(() => ({ custom: CustomNode }), []);
  return <ReactFlow nodeTypes={nodeTypes} />;
}
```

### Missing memo() on Custom Nodes/Edges
- **Issue**: Custom components re-render on every parent update
- **Fix**: Wrap in `memo()`
- **Example**:
```tsx
// GOOD - wrapped in memo
import { memo } from 'react';
const CustomNode = memo(function CustomNode({ data }) {
  return <div>{data.label}</div>;
});
```

### Inline Callbacks Without useCallback
- **Issue**: Creates new function references, breaking memoization
- **Fix**: Wrap callbacks in `useCallback`
- **Example**:
```tsx
// GOOD - memoized callback
const onNodesChange = useCallback(
  (changes) => setNodes((nds) => applyNodeChanges(changes, nds)),
  []
);
<ReactFlow onNodesChange={onNodesChange} />
```

### Using useReactFlow Outside Provider
- **Issue**: Will throw error if not inside ReactFlowProvider
- **Fix**: Wrap component tree in ReactFlowProvider
- **Example**:
```tsx
// GOOD - wrap in provider
function App() {
  return (
    <ReactFlowProvider>
      <FlowContent />
    </ReactFlowProvider>
  );
}
```

## Performance Checklist

- [ ] Custom nodes wrapped in `memo()`
- [ ] nodeTypes defined outside component or memoized
- [ ] Heavy computations inside nodes use `useMemo`
- [ ] Event handlers use `useCallback`
- [ ] Using functional form of setState: `setNodes((nds) => ...)`
- [ ] Using `updateNodeData` for data-only changes
- [ ] Container has explicit height (flow won't render without it)
- [ ] CSS import present: `import '@xyflow/react/dist/style.css'`
- [ ] Interactive elements marked with `nodrag` class
- [ ] Position constants used instead of string literals

---

# Zustand State Management (if detected)

## Critical Issues to Flag

### Selector Performance
- **Issue**: Subscribing to entire store causes unnecessary rerenders
- **Fix**: Use specific selectors
- **Example**:
```tsx
// GOOD - subscribes only to bears
const bears = useBearStore((state) => state.bears)

// BAD - rerenders on any change
const state = useBearStore()
```

### Multiple Values with useShallow
- **Issue**: Multiple values cause rerenders with shallow comparison
- **Fix**: Use `useShallow` from zustand/react/shallow
- **Example**:
```tsx
// GOOD - prevents rerenders with shallow comparison
import { useShallow } from 'zustand/react/shallow'

const { bears, fish } = useBearStore(
  useShallow((state) => ({ bears: state.bears, fish: state.fish }))
)
```

### State Updates
- **Issue**: Direct mutation of state
- **Fix**: Use immutable updates
- **Example**:
```tsx
// GOOD - immutable update
set((state) => ({ bears: state.bears + 1 }))

// BAD - mutation
set((state) => {
  state.bears += 1  // Mutation!
  return state
})
```

### Nested Objects
- **Issue**: Zustand only auto-merges at one level
- **Fix**: Manual spread for nested objects
- **Example**:
```tsx
// GOOD - manual spread for nested
set((state) => ({
  nested: { ...state.nested, count: state.nested.count + 1 }
}))
```

## Best Practices

- Use single selector for one piece of state
- Use `useShallow` for multiple values
- Use `getState()` outside React or in event handlers
- Use `subscribe()` for external systems
- Don't mutate state directly (use immer middleware if needed)
- Avoid fetching entire store in components

---

# Tailwind v4 Review (if detected)

## Critical Issues to Flag

### Using v3 Patterns
- **Issue**: Using tailwind.config.js or postcss.config.js
- **Fix**: Use @theme in CSS and @tailwindcss/vite plugin
- **Example**:
```css
/* GOOD - v4 approach */
@import 'tailwindcss';

@theme {
  --color-primary: oklch(60% 0.24 262);
}
```

### Incorrect @theme Mode
- **Issue**: Using wrong @theme mode for use case
- **Fix**: Use `inline` for static values, `default` for CSS variables
- **Example**:
```css
/* GOOD - inline for static values */
@theme inline {
  --color-brand: oklch(60% 0.24 262);
}

/* GOOD - default for runtime theming */
@theme {
  --color-primary: oklch(60% 0.24 262);
}
```

### Not Using OKLCH
- **Issue**: Using rgb() or hsl() instead of oklch()
- **Fix**: Use oklch() for perceptually uniform colors
- **Example**:
```css
/* GOOD - OKLCH colors */
@theme {
  --color-blue-600: oklch(54.6% 0.245 262.881);
}
```

### Missing CSS Variable Naming Convention
- **Issue**: Not following Tailwind v4 naming patterns
- **Fix**: Use `--color-{name}-{shade}` pattern
- **Example**:
```css
/* GOOD - follows convention */
@theme {
  --color-primary-500: oklch(60% 0.24 262);
  --font-display: 'Inter Variable', system-ui;
}
```

## Dark Mode

### Class-Based Dark Mode Setup
- **Issue**: Missing darkMode configuration for class-based approach
- **Fix**: Add v3 config file with `darkMode: 'class'`
- **Example**:
```js
// tailwind.config.js
module.exports = {
  darkMode: 'class',
};
```

### FOUC Prevention
- **Issue**: Flash of unstyled content on page load
- **Fix**: Add inline script before any styled content
- **Example**:
```html
<script>
  (function() {
    const theme = localStorage.getItem('theme') || 'system';
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    const effectiveTheme = theme === 'system' ? systemTheme : theme;
    document.documentElement.classList.add(effectiveTheme);
  })();
</script>
```

---

# Vitest Testing (if test files detected)

## Critical Issues to Flag

### Missing await on Async Expects
- **Issue**: Creates false positives
- **Fix**: Always await async expects
- **Example**:
```ts
// GOOD - awaited
await expect(promise).resolves.toBe(value)

// BAD - false positive!
expect(promise).resolves.toBe(value)
```

### Shared State Between Tests
- **Issue**: Flaky tests, order-dependent failures
- **Fix**: Use beforeEach for isolation
- **Example**:
```ts
// GOOD - isolated state
beforeEach(() => {
  state = createFreshState()
})
```

### vi.mock Inside Tests
- **Issue**: Hoisting issues, won't work
- **Fix**: vi.mock at top level before imports
- **Example**:
```ts
// GOOD - vi.mock at top level
vi.mock('./module')
import { fn } from './module'
```

### Missing Mock Cleanup
- **Issue**: Mocks leak between tests
- **Fix**: Clear/reset mocks in beforeEach
- **Example**:
```ts
// GOOD - cleanup in beforeEach
beforeEach(() => {
  vi.clearAllMocks()
})
```

## Best Practices

- Always await async expects
- Use beforeEach for test isolation
- vi.mock at top level, not inside tests
- Clear mocks between tests
- Don't nest describes excessively
- Test behavior, not implementation details

---

## Step 4: Review Execution

**Sequential (default):**
1. Apply React Router patterns to all components
2. Apply shadcn/ui patterns to all components
3. Apply conditionally detected technology patterns
4. Consolidate findings

**Parallel (--parallel flag):**
1. Detect all technologies upfront
2. Spawn one parallel review per technology area
3. Wait for all reviews
4. Consolidate findings

## Output Format

```markdown
## Review Summary

[1-2 sentence overview of findings]

## Issues

### Critical (Blocking)

1. [FILE:LINE] ISSUE_TITLE
   - Issue: Description of what's wrong
   - Why: Why this matters (bug, a11y, perf, security)
   - Fix: Specific recommended fix

### Major (Should Fix)

2. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

### Minor (Nice to Have)

N. [FILE:LINE] ISSUE_TITLE
   - Issue: ...
   - Why: ...
   - Fix: ...

## Good Patterns

- [FILE:LINE] Pattern description (preserve this)

## Verdict

Ready: Yes | No | With fixes 1-N
Rationale: [1-2 sentences]
```

## Post-Fix Verification

After fixes are applied, run:

```bash
npm run lint
npm run typecheck
npm run test
```

All checks must pass before approval.

## Rules

- Number every issue sequentially (1, 2, 3...)
- Include FILE:LINE for each issue
- Separate Issue/Why/Fix clearly
- Categorize by actual severity
- Don't assume Next.js patterns (no "use client")
- Run verification after fixes
