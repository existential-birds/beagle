# Conversation Components

Components for building chat-style interfaces with messages, attachments, and intelligent auto-scrolling.

## Core Components

### Conversation

Container component that wraps the entire conversation area with auto-scroll functionality.

```typescript
type ConversationProps = ComponentProps<typeof StickToBottom>;
```

**Props:**
- `className?: string` - Additional CSS classes
- `initial?: "smooth" | "auto"` - Initial scroll behavior (default: "smooth")
- `resize?: "smooth" | "auto"` - Scroll behavior on resize (default: "smooth")

**Usage:**

```tsx
<Conversation className="flex-1 overflow-y-hidden">
  <ConversationContent>
    {/* Messages go here */}
  </ConversationContent>
  <ConversationScrollButton />
</Conversation>
```

**Features:**
- Uses `use-stick-to-bottom` for intelligent scrolling
- Automatically scrolls to bottom when new messages arrive
- Pauses auto-scroll when user scrolls up manually
- Provides context for scroll state to child components
- Sets `role="log"` for accessibility

### ConversationContent

Content area for messages within the conversation.

```typescript
type ConversationContentProps = ComponentProps<typeof StickToBottom.Content>;
```

**Usage:**

```tsx
<ConversationContent className="flex flex-col gap-8 p-4">
  {messages.map(message => (
    <Message key={message.id} from={message.role}>
      {/* Message content */}
    </Message>
  ))}
</ConversationContent>
```

**Default Styling:**
- Flexbox column layout with gap
- Padding for content separation

### ConversationEmptyState

Placeholder shown when there are no messages.

```typescript
type ConversationEmptyStateProps = ComponentProps<"div"> & {
  title?: string;
  description?: string;
  icon?: React.ReactNode;
};
```

**Props:**
- `title?: string` - Heading text (default: "No messages yet")
- `description?: string` - Descriptive text (default: "Start a conversation to see messages here")
- `icon?: React.ReactNode` - Icon to display above text
- `children?: React.ReactNode` - Custom content (overrides default)

**Usage:**

```tsx
{messages.length === 0 ? (
  <ConversationEmptyState
    title="Welcome!"
    description="Ask me anything to get started"
    icon={<MessageSquareIcon className="size-12" />}
  />
) : (
  <ConversationContent>
    {/* Messages */}
  </ConversationContent>
)}
```

### ConversationScrollButton

Button that appears when user is not at the bottom of the conversation, allowing quick navigation to latest messages.

```typescript
type ConversationScrollButtonProps = ComponentProps<typeof Button>;
```

**Usage:**

```tsx
<Conversation>
  <ConversationContent>
    {/* Messages */}
  </ConversationContent>
  <ConversationScrollButton />
</Conversation>
```

**Behavior:**
- Only visible when `isAtBottom` is false
- Positioned at bottom center of conversation
- Calls `scrollToBottom()` on click
- Uses `ArrowDownIcon` by default

## Message Components

### Message

Container for an individual message with role-based styling.

```typescript
type MessageProps = HTMLAttributes<HTMLDivElement> & {
  from: UIMessage["role"]; // "user" | "assistant"
};
```

**Props:**
- `from: "user" | "assistant"` - Message sender role
- `className?: string` - Additional CSS classes
- Standard HTML div attributes

**Usage:**

```tsx
<Message from="assistant">
  <MessageContent>
    <MessageResponse>{content}</MessageResponse>
  </MessageContent>
  <MessageActions>
    <MessageAction tooltip="Copy" onClick={copyToClipboard}>
      <CopyIcon />
    </MessageAction>
  </MessageActions>
</Message>
```

**Styling:**
- User messages: right-aligned, max-width 80%
- Assistant messages: left-aligned, max-width 80%
- Adds `is-user` or `is-assistant` class for context-specific styling

### MessageContent

Content area for message text and media.

```typescript
type MessageContentProps = HTMLAttributes<HTMLDivElement>;
```

**Usage:**

```tsx
<MessageContent>
  <MessageResponse>{text}</MessageResponse>
</MessageContent>
```

**Styling:**
- User messages: rounded background with secondary color
- Assistant messages: plain text styling
- Flexbox column layout for multiple content types

### MessageResponse

Renders markdown/text content with streaming support.

```typescript
type MessageResponseProps = ComponentProps<typeof Streamdown>;
```

**Usage:**

```tsx
<MessageResponse>
  {message.content}
</MessageResponse>
```

**Features:**
- Uses `Streamdown` for markdown rendering
- Memoized to prevent unnecessary re-renders
- Supports streaming text updates
- Removes default margin from first/last children

### MessageActions

Container for action buttons (copy, edit, regenerate, etc.).

```typescript
type MessageActionsProps = ComponentProps<"div">;
```

**Usage:**

```tsx
<MessageActions>
  <MessageAction tooltip="Copy" onClick={handleCopy}>
    <CopyIcon />
  </MessageAction>
  <MessageAction tooltip="Regenerate" onClick={handleRegenerate}>
    <RefreshIcon />
  </MessageAction>
</MessageActions>
```

### MessageAction

Individual action button with optional tooltip.

```typescript
type MessageActionProps = ComponentProps<typeof Button> & {
  tooltip?: string;
  label?: string;
};
```

**Props:**
- `tooltip?: string` - Tooltip text shown on hover
- `label?: string` - Accessible label (falls back to tooltip)
- All Button component props

**Usage:**

```tsx
<MessageAction
  tooltip="Copy to clipboard"
  onClick={handleCopy}
  variant="ghost"
  size="icon-sm"
>
  <CopyIcon className="size-4" />
</MessageAction>
```

## Message Branching

### MessageBranch

Container for managing alternative message responses with navigation.

```typescript
type MessageBranchProps = HTMLAttributes<HTMLDivElement> & {
  defaultBranch?: number;
  onBranchChange?: (branchIndex: number) => void;
};
```

**Props:**
- `defaultBranch?: number` - Initial branch index (default: 0)
- `onBranchChange?: (index: number) => void` - Callback when branch changes

**Usage:**

```tsx
<MessageBranch defaultBranch={0} onBranchChange={handleBranchChange}>
  <MessageBranchContent>
    <MessageResponse key="1">{response1}</MessageResponse>
    <MessageResponse key="2">{response2}</MessageResponse>
    <MessageResponse key="3">{response3}</MessageResponse>
  </MessageBranchContent>
  <MessageBranchSelector from="assistant">
    <MessageBranchPrevious />
    <MessageBranchPage />
    <MessageBranchNext />
  </MessageBranchSelector>
</MessageBranch>
```

**Context:**
Provides context with:
- `currentBranch: number` - Current branch index
- `totalBranches: number` - Total number of branches
- `goToPrevious: () => void` - Navigate to previous branch
- `goToNext: () => void` - Navigate to next branch

### MessageBranchContent

Displays the current branch content, hiding others.

```typescript
type MessageBranchContentProps = HTMLAttributes<HTMLDivElement>;
```

**Behavior:**
- Automatically manages branch visibility
- Updates when children change
- Preserves all branches in DOM (display: none for hidden)

### MessageBranchSelector

Container for branch navigation controls.

```typescript
type MessageBranchSelectorProps = HTMLAttributes<HTMLDivElement> & {
  from: UIMessage["role"];
};
```

**Behavior:**
- Only renders if `totalBranches > 1`
- Uses ButtonGroup for grouped appearance

### MessageBranchPrevious

Button to navigate to previous branch.

```typescript
type MessageBranchPreviousProps = ComponentProps<typeof Button>;
```

**Behavior:**
- Wraps around (last branch → first branch)
- Disabled if only one branch exists
- Default icon: `ChevronLeftIcon`

### MessageBranchNext

Button to navigate to next branch.

```typescript
type MessageBranchNextProps = ComponentProps<typeof Button>;
```

**Behavior:**
- Wraps around (first branch → last branch)
- Disabled if only one branch exists
- Default icon: `ChevronRightIcon`

### MessageBranchPage

Displays current branch number and total.

```typescript
type MessageBranchPageProps = HTMLAttributes<HTMLSpanElement>;
```

**Display:**
Shows "1 of 3", "2 of 3", etc.

## Attachment Components

### MessageAttachment

Displays a file or image attachment with optional remove button.

```typescript
type MessageAttachmentProps = HTMLAttributes<HTMLDivElement> & {
  data: FileUIPart;
  className?: string;
  onRemove?: () => void;
};
```

**Props:**
- `data: FileUIPart` - Attachment data (url, filename, mediaType)
- `onRemove?: () => void` - Callback to remove attachment

**Usage:**

```tsx
<MessageAttachment
  data={{
    type: "file",
    url: "blob:...",
    filename: "document.pdf",
    mediaType: "application/pdf"
  }}
  onRemove={() => removeAttachment(id)}
/>
```

**Behavior:**
- Images: Shows thumbnail preview
- Files: Shows paperclip icon
- Hover: Shows remove button (if onRemove provided)
- Tooltip: Displays filename on non-image files

### MessageAttachments

Container for multiple attachments.

```typescript
type MessageAttachmentsProps = ComponentProps<"div">;
```

**Usage:**

```tsx
<MessageAttachments>
  {attachments.map(attachment => (
    <MessageAttachment key={attachment.id} data={attachment} />
  ))}
</MessageAttachments>
```

**Styling:**
- Flexbox wrap layout
- Right-aligned (ml-auto)
- Gap between items

## MessageToolbar

Container for toolbar elements below message content.

```typescript
type MessageToolbarProps = ComponentProps<"div">;
```

**Usage:**

```tsx
<MessageToolbar>
  <div className="flex items-center gap-2">
    <span className="text-xs text-muted-foreground">{timestamp}</span>
  </div>
  <MessageActions>
    {/* Action buttons */}
  </MessageActions>
</MessageToolbar>
```

## Complete Example

```tsx
import {
  Conversation,
  ConversationContent,
  ConversationEmptyState,
  ConversationScrollButton,
} from "@/components/ai-elements/conversation";
import {
  Message,
  MessageContent,
  MessageResponse,
  MessageActions,
  MessageAction,
  MessageAttachments,
  MessageAttachment,
  MessageBranch,
  MessageBranchContent,
  MessageBranchSelector,
  MessageBranchPrevious,
  MessageBranchNext,
  MessageBranchPage,
} from "@/components/ai-elements/message";

function ChatInterface({ messages }: { messages: UIMessage[] }) {
  return (
    <Conversation className="flex-1">
      {messages.length === 0 ? (
        <ConversationEmptyState
          title="Start a conversation"
          description="Ask me anything!"
        />
      ) : (
        <ConversationContent className="p-4">
          {messages.map(message => (
            <Message key={message.id} from={message.role}>
              {message.attachments && (
                <MessageAttachments>
                  {message.attachments.map(att => (
                    <MessageAttachment key={att.url} data={att} />
                  ))}
                </MessageAttachments>
              )}

              <MessageContent>
                {message.branches ? (
                  <MessageBranch>
                    <MessageBranchContent>
                      {message.branches.map((branch, idx) => (
                        <MessageResponse key={idx}>{branch}</MessageResponse>
                      ))}
                    </MessageBranchContent>
                    <MessageBranchSelector from={message.role}>
                      <MessageBranchPrevious />
                      <MessageBranchPage />
                      <MessageBranchNext />
                    </MessageBranchSelector>
                  </MessageBranch>
                ) : (
                  <MessageResponse>{message.content}</MessageResponse>
                )}
              </MessageContent>

              <MessageActions>
                <MessageAction tooltip="Copy" onClick={() => copy(message)}>
                  <CopyIcon />
                </MessageAction>
                <MessageAction tooltip="Regenerate" onClick={() => regenerate(message)}>
                  <RefreshIcon />
                </MessageAction>
              </MessageActions>
            </Message>
          ))}
        </ConversationContent>
      )}
      <ConversationScrollButton />
    </Conversation>
  );
}
```
