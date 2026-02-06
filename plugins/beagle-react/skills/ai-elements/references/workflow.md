# Workflow Components

Components for displaying job queues, tool execution, approval workflows, and reasoning displays.

## Table of Contents

- [Queue Components](#queue-components)
- [Tool Components](#tool-components)
- [Confirmation Components](#confirmation-components)
- [Reasoning Components](#reasoning-components)
- [Loading Components](#loading-components)

## Queue Components

Components for displaying task lists, job queues, and progress tracking.

### Queue

Main container for queue items and sections.

```typescript
type QueueProps = ComponentProps<"div">;
```

**Usage:**

```tsx
<Queue>
  <QueueSection>
    {/* Queue items */}
  </QueueSection>
</Queue>
```

**Default Styling:**
- Bordered container with rounded corners
- Background with shadow
- Flexbox column layout with gap

### QueueSection

Collapsible section for organizing queue items.

```typescript
type QueueSectionProps = ComponentProps<typeof Collapsible>;
```

**Props:**
- `defaultOpen?: boolean` - Initial open state (default: true)

**Usage:**

```tsx
<QueueSection defaultOpen={true}>
  <QueueSectionTrigger>
    <QueueSectionLabel count={5} label="pending tasks" />
  </QueueSectionTrigger>
  <QueueSectionContent>
    <QueueList>
      {/* Queue items */}
    </QueueList>
  </QueueSectionContent>
</QueueSection>
```

### QueueSectionTrigger

Clickable header to toggle section visibility.

```typescript
type QueueSectionTriggerProps = ComponentProps<"button">;
```

**Default Styling:**
- Full width button
- Muted background with hover effect
- Flexbox layout for content alignment

### QueueSectionLabel

Label with icon, text, and count display.

```typescript
type QueueSectionLabelProps = ComponentProps<"span"> & {
  count?: number;
  label: string;
  icon?: React.ReactNode;
};
```

**Props:**
- `count?: number` - Item count to display
- `label: string` - Section label (required)
- `icon?: React.ReactNode` - Optional icon

**Usage:**

```tsx
<QueueSectionLabel
  count={todos.length}
  label="todos"
  icon={<CheckSquareIcon className="size-4" />}
/>
```

**Display:**
Shows "{count} {label}" with chevron icon that rotates when expanded.

### QueueSectionContent

Collapsible content area for queue items.

```typescript
type QueueSectionContentProps = ComponentProps<typeof CollapsibleContent>;
```

### QueueList

Scrollable container for queue items.

```typescript
type QueueListProps = ComponentProps<typeof ScrollArea>;
```

**Default Styling:**
- Max height of 40 (10rem)
- Scrollable when content overflows
- Padding for scroll area

**Usage:**

```tsx
<QueueList>
  {items.map(item => (
    <QueueItem key={item.id}>
      {/* Item content */}
    </QueueItem>
  ))}
</QueueList>
```

### QueueItem

Individual queue item container.

```typescript
type QueueItemProps = ComponentProps<"li">;
```

**Usage:**

```tsx
<QueueItem>
  <QueueItemIndicator completed={todo.status === 'completed'} />
  <QueueItemContent completed={todo.status === 'completed'}>
    {todo.title}
  </QueueItemContent>
  {todo.description && (
    <QueueItemDescription completed={todo.status === 'completed'}>
      {todo.description}
    </QueueItemDescription>
  )}
  <QueueItemActions>
    <QueueItemAction onClick={handleEdit}>
      <EditIcon />
    </QueueItemAction>
  </QueueItemActions>
</QueueItem>
```

**Default Styling:**
- Flexbox column layout
- Hover background effect
- Grouped item styling

### QueueItemIndicator

Status indicator dot.

```typescript
type QueueItemIndicatorProps = ComponentProps<"span"> & {
  completed?: boolean;
};
```

**Props:**
- `completed?: boolean` - Whether item is completed (default: false)

**Styling:**
- Pending: Solid border
- Completed: Muted border and background

### QueueItemContent

Main content text for queue item.

```typescript
type QueueItemContentProps = ComponentProps<"span"> & {
  completed?: boolean;
};
```

**Props:**
- `completed?: boolean` - Whether item is completed (default: false)

**Styling:**
- Pending: Normal text
- Completed: Muted text with line-through

### QueueItemDescription

Secondary description text.

```typescript
type QueueItemDescriptionProps = ComponentProps<"div"> & {
  completed?: boolean;
};
```

**Props:**
- `completed?: boolean` - Whether item is completed (default: false)

**Styling:**
- Smaller text size
- Indented under main content
- Muted color (more muted if completed)

### QueueItemActions

Container for action buttons.

```typescript
type QueueItemActionsProps = ComponentProps<"div">;
```

**Usage:**

```tsx
<QueueItemActions>
  <QueueItemAction onClick={handleEdit}>
    <EditIcon />
  </QueueItemAction>
  <QueueItemAction onClick={handleDelete}>
    <TrashIcon />
  </QueueItemAction>
</QueueItemActions>
```

### QueueItemAction

Individual action button.

```typescript
type QueueItemActionProps = Omit<ComponentProps<typeof Button>, "variant" | "size">;
```

**Behavior:**
- Hidden by default
- Visible on item hover
- Ghost variant
- Icon size

### QueueItemAttachment

Container for attached files/images.

```typescript
type QueueItemAttachmentProps = ComponentProps<"div">;
```

### QueueItemImage

Image preview thumbnail.

```typescript
type QueueItemImageProps = ComponentProps<"img">;
```

**Default Size:** 32x32px

### QueueItemFile

File attachment display with icon.

```typescript
type QueueItemFileProps = ComponentProps<"span">;
```

**Features:**
- Paperclip icon
- Truncated filename (max 100px)
- Border and background styling

## Tool Components

Components for displaying tool execution with states, parameters, and results.

### Tool

Main container for tool execution display.

```typescript
type ToolProps = ComponentProps<typeof Collapsible>;
```

**Usage:**

```tsx
<Tool>
  <ToolHeader
    title="search"
    type="tool-call-search"
    state="output-available"
  />
  <ToolContent>
    <ToolInput input={{ query: "AI tools" }} />
    <ToolOutput output={results} errorText={undefined} />
  </ToolContent>
</Tool>
```

**Default Styling:**
- Bordered container
- Rounded corners
- Not prose (for content formatting)

### ToolHeader

Collapsible trigger showing tool name and status.

```typescript
type ToolHeaderProps = {
  title?: string;
  type: ToolUIPart["type"];
  state: ToolUIPart["state"];
  className?: string;
};
```

**Props:**
- `title?: string` - Display name (defaults to type without "tool-call-" prefix)
- `type: string` - Tool type identifier
- `state: ToolState` - Current execution state (required)

**Tool States:**
- `input-streaming` - Parameters being received (Pending badge)
- `input-available` - Ready to execute (Running badge, pulsing)
- `approval-requested` - Awaiting approval (Awaiting Approval badge, yellow)
- `approval-responded` - User responded (Responded badge, blue)
- `output-available` - Completed (Completed badge, green)
- `output-error` - Failed (Error badge, red)
- `output-denied` - Approval denied (Denied badge, orange)

**Features:**
- Wrench icon
- Color-coded status badge
- Chevron that rotates when expanded

### ToolContent

Collapsible content area for parameters and results.

```typescript
type ToolContentProps = ComponentProps<typeof CollapsibleContent>;
```

**Animation:**
- Slide in/out from top
- Fade transition

### ToolInput

Displays tool parameters/arguments.

```typescript
type ToolInputProps = ComponentProps<"div"> & {
  input: ToolUIPart["input"];
};
```

**Props:**
- `input: unknown` - Tool parameters (any JSON-serializable value)

**Usage:**

```tsx
<ToolInput
  input={{
    query: "AI tools",
    limit: 10,
    filters: ["type:library"]
  }}
/>
```

**Features:**
- "PARAMETERS" heading
- JSON syntax highlighting via CodeBlock
- Automatic JSON.stringify with formatting

### ToolOutput

Displays tool results or errors.

```typescript
type ToolOutputProps = ComponentProps<"div"> & {
  output: ToolUIPart["output"];
  errorText: ToolUIPart["errorText"];
};
```

**Props:**
- `output: unknown` - Tool result (any value, React element, or JSON)
- `errorText?: string` - Error message if execution failed

**Usage:**

```tsx
<ToolOutput
  output={{
    results: [...],
    count: 42
  }}
  errorText={undefined}
/>
```

**Behavior:**
- Shows "RESULT" heading for success
- Shows "ERROR" heading for errors
- Renders React elements directly
- JSON stringifies objects
- CodeBlock for strings
- Destructive styling for errors

## Confirmation Components

Components for approval workflows requiring user confirmation.

### Confirmation

Container for confirmation UI with conditional rendering based on state.

```typescript
type ConfirmationProps = ComponentProps<typeof Alert> & {
  approval?: ToolUIPartApproval;
  state: ToolUIPart["state"];
};

type ToolUIPartApproval =
  | { id: string; approved?: never; reason?: never }
  | { id: string; approved: boolean; reason?: string }
  | undefined;
```

**Props:**
- `approval?: ToolUIPartApproval` - Approval data
- `state: ToolState` - Current state

**Usage:**

```tsx
<Confirmation approval={tool.approval} state={tool.state}>
  <ConfirmationTitle>
    Delete {count} files?
  </ConfirmationTitle>

  <ConfirmationRequest>
    <ConfirmationActions>
      <ConfirmationAction onClick={handleApprove} variant="default">
        Approve
      </ConfirmationAction>
      <ConfirmationAction onClick={handleReject} variant="outline">
        Reject
      </ConfirmationAction>
    </ConfirmationActions>
  </ConfirmationRequest>

  <ConfirmationAccepted>
    Action approved and executed.
  </ConfirmationAccepted>

  <ConfirmationRejected>
    Action rejected.
  </ConfirmationRejected>
</Confirmation>
```

**Context:**
Provides `{ approval, state }` to child components.

### ConfirmationTitle

Title/description of the confirmation request.

```typescript
type ConfirmationTitleProps = ComponentProps<typeof AlertDescription>;
```

### ConfirmationRequest

Container shown during approval-requested state.

```typescript
type ConfirmationRequestProps = { children?: ReactNode };
```

**Visibility:**
Only shown when `state === "approval-requested"`

### ConfirmationActions

Container for approve/reject buttons.

```typescript
type ConfirmationActionsProps = ComponentProps<"div">;
```

**Visibility:**
Only shown when `state === "approval-requested"`

### ConfirmationAction

Individual action button.

```typescript
type ConfirmationActionProps = ComponentProps<typeof Button>;
```

**Default Styling:**
- Small height (h-8)
- Compact padding

### ConfirmationAccepted

Content shown when approval is accepted.

```typescript
type ConfirmationAcceptedProps = { children?: ReactNode };
```

**Visibility:**
Only shown when `approval.approved === true` and state is response/output state.

### ConfirmationRejected

Content shown when approval is rejected.

```typescript
type ConfirmationRejectedProps = { children?: ReactNode };
```

**Visibility:**
Only shown when `approval.approved === false` and state is response/output state.

### useConfirmation

Hook to access confirmation context.

```typescript
const useConfirmation = () => {
  const { approval, state } = useConfirmation();
  // ...
};
```

## Reasoning Components

Components for displaying AI thinking/reasoning with auto-collapse behavior.

### Reasoning

Collapsible container for reasoning content with auto-collapse.

```typescript
type ReasoningProps = ComponentProps<typeof Collapsible> & {
  isStreaming?: boolean;
  open?: boolean;
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
  duration?: number;
};
```

**Props:**
- `isStreaming?: boolean` - Whether content is actively streaming (default: false)
- `open?: boolean` - Controlled open state
- `defaultOpen?: boolean` - Initial open state (default: true)
- `onOpenChange?: (open: boolean) => void` - Callback when open state changes
- `duration?: number` - Thinking duration in seconds

**Usage:**

```tsx
<Reasoning isStreaming={isStreaming} defaultOpen={true}>
  <ReasoningTrigger />
  <ReasoningContent>
    {reasoningText}
  </ReasoningContent>
</Reasoning>
```

**Auto-Collapse Behavior:**
1. Opens automatically when streaming starts
2. Tracks duration from start to end of streaming
3. Closes 1 second after streaming ends
4. Auto-close only happens once per component lifecycle

**Context:**
Provides `{ isStreaming, isOpen, setIsOpen, duration }` to children.

### ReasoningTrigger

Trigger button with status message and icon.

```typescript
type ReasoningTriggerProps = ComponentProps<typeof CollapsibleTrigger> & {
  getThinkingMessage?: (isStreaming: boolean, duration?: number) => ReactNode;
};
```

**Props:**
- `getThinkingMessage?: (isStreaming, duration) => ReactNode` - Custom message generator

**Default Messages:**
- Streaming: "Thinking..." with shimmer effect
- Duration 0 or undefined: "Thought for a few seconds"
- Duration N: "Thought for N seconds"

**Usage:**

```tsx
<ReasoningTrigger />

// Custom message
<ReasoningTrigger
  getThinkingMessage={(streaming, duration) =>
    streaming ? <Shimmer>Processing...</Shimmer> : `Done in ${duration}s`
  }
/>
```

**Icons:**
- Brain icon
- Rotating chevron (down when closed, up when open)

### ReasoningContent

Collapsible content area with markdown rendering.

```typescript
type ReasoningContentProps = ComponentProps<typeof CollapsibleContent> & {
  children: string;
};
```

**Props:**
- `children: string` - Reasoning text (required, string only)

**Features:**
- Uses Streamdown for markdown rendering
- Slide and fade animations
- Muted text color

### useReasoning

Hook to access reasoning context.

```typescript
const useReasoning = () => {
  const { isStreaming, isOpen, setIsOpen, duration } = useReasoning();
  // ...
};
```

## Loading Components

### Shimmer

Animated shimmer effect for loading text.

```typescript
type TextShimmerProps = {
  children: string;
  as?: ElementType;
  className?: string;
  duration?: number;
  spread?: number;
};
```

**Props:**
- `children: string` - Text to shimmer (required)
- `as?: ElementType` - HTML element type (default: "p")
- `className?: string` - Additional classes
- `duration?: number` - Animation duration in seconds (default: 2)
- `spread?: number` - Shimmer spread multiplier (default: 2)

**Usage:**

```tsx
<Shimmer duration={1.5}>Thinking...</Shimmer>
<Shimmer as="span" spread={3}>Loading data...</Shimmer>
```

**Features:**
- Framer Motion animation
- Gradient sweep effect
- Dynamic spread based on text length
- Infinite loop

### Loader

Spinning loader icon.

```typescript
type LoaderProps = HTMLAttributes<HTMLDivElement> & {
  size?: number;
};
```

**Props:**
- `size?: number` - Icon size in pixels (default: 16)

**Usage:**

```tsx
<Loader size={24} />
<Loader className="text-primary" />
```

**Features:**
- SVG-based spinner
- CSS animation (spin)
- Respects current color

## Complete Example

```tsx
import {
  Queue,
  QueueSection,
  QueueSectionTrigger,
  QueueSectionLabel,
  QueueSectionContent,
  QueueList,
  QueueItem,
  QueueItemIndicator,
  QueueItemContent,
  QueueItemDescription,
} from "@/components/ai-elements/queue";
import {
  Tool,
  ToolHeader,
  ToolContent,
  ToolInput,
  ToolOutput,
} from "@/components/ai-elements/tool";
import {
  Confirmation,
  ConfirmationTitle,
  ConfirmationRequest,
  ConfirmationActions,
  ConfirmationAction,
  ConfirmationAccepted,
  ConfirmationRejected,
} from "@/components/ai-elements/confirmation";
import {
  Reasoning,
  ReasoningTrigger,
  ReasoningContent,
} from "@/components/ai-elements/reasoning";

function WorkflowDisplay({ todos, tools, reasoning }) {
  return (
    <div className="space-y-4">
      {/* Queue */}
      <Queue>
        <QueueSection>
          <QueueSectionTrigger>
            <QueueSectionLabel count={todos.length} label="tasks" />
          </QueueSectionTrigger>
          <QueueSectionContent>
            <QueueList>
              {todos.map(todo => (
                <QueueItem key={todo.id}>
                  <QueueItemIndicator completed={todo.completed} />
                  <QueueItemContent completed={todo.completed}>
                    {todo.title}
                  </QueueItemContent>
                  {todo.description && (
                    <QueueItemDescription completed={todo.completed}>
                      {todo.description}
                    </QueueItemDescription>
                  )}
                </QueueItem>
              ))}
            </QueueList>
          </QueueSectionContent>
        </QueueSection>
      </Queue>

      {/* Reasoning */}
      {reasoning && (
        <Reasoning isStreaming={reasoning.isStreaming}>
          <ReasoningTrigger />
          <ReasoningContent>{reasoning.content}</ReasoningContent>
        </Reasoning>
      )}

      {/* Tools */}
      {tools.map(tool => (
        <div key={tool.id}>
          <Tool>
            <ToolHeader
              title={tool.name}
              type={tool.type}
              state={tool.state}
            />
            <ToolContent>
              <ToolInput input={tool.args} />
              <ToolOutput output={tool.result} errorText={tool.error} />
            </ToolContent>
          </Tool>

          {tool.requiresApproval && (
            <Confirmation approval={tool.approval} state={tool.state}>
              <ConfirmationTitle>
                Approve {tool.name}?
              </ConfirmationTitle>

              <ConfirmationRequest>
                <ConfirmationActions>
                  <ConfirmationAction
                    onClick={() => approveTool(tool.id)}
                    variant="default"
                  >
                    Approve
                  </ConfirmationAction>
                  <ConfirmationAction
                    onClick={() => rejectTool(tool.id)}
                    variant="outline"
                  >
                    Reject
                  </ConfirmationAction>
                </ConfirmationActions>
              </ConfirmationRequest>

              <ConfirmationAccepted>
                Tool approved and executed.
              </ConfirmationAccepted>

              <ConfirmationRejected>
                Tool execution rejected.
              </ConfirmationRejected>
            </Confirmation>
          )}
        </div>
      ))}
    </div>
  );
}
```
