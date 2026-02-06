# Prompt Input Components

Advanced text input components with file attachments, drag-and-drop, speech input, and comprehensive state management.

## Table of Contents

- [Core Components](#core-components)
- [State Management](#state-management)
- [Attachment Handling](#attachment-handling)
- [Action Menus](#action-menus)
- [Submit Button](#submit-button)
- [Speech Input](#speech-input)
- [Advanced Features](#advanced-features)
- [Complete Example](#complete-example)

## Core Components

### PromptInput

Main form container that handles text input, file attachments, and submission.

```typescript
type PromptInputProps = Omit<HTMLAttributes<HTMLFormElement>, "onSubmit" | "onError"> & {
  accept?: string;
  multiple?: boolean;
  globalDrop?: boolean;
  syncHiddenInput?: boolean;
  maxFiles?: number;
  maxFileSize?: number;
  onError?: (err: { code: "max_files" | "max_file_size" | "accept"; message: string }) => void;
  onSubmit: (message: PromptInputMessage, event: FormEvent<HTMLFormElement>) => void | Promise<void>;
};

type PromptInputMessage = {
  text: string;
  files: FileUIPart[];
};
```

**Props:**
- `accept?: string` - File type filter (e.g., "image/*")
- `multiple?: boolean` - Allow multiple file selection
- `globalDrop?: boolean` - Accept drops anywhere on document (default: false)
- `syncHiddenInput?: boolean` - Keep hidden input in sync (default: false)
- `maxFiles?: number` - Maximum number of files
- `maxFileSize?: number` - Maximum file size in bytes
- `onError?: (err) => void` - Error handler for file validation
- `onSubmit: (message, event) => void | Promise<void>` - Submit handler (required)

**Usage:**

```tsx
<PromptInput
  accept="image/*"
  multiple
  maxFiles={5}
  maxFileSize={10 * 1024 * 1024} // 10MB
  onError={(err) => toast.error(err.message)}
  onSubmit={async (message) => {
    await sendMessage(message.text, message.files);
  }}
>
  <PromptInputAttachments>
    {(attachment) => <PromptInputAttachment data={attachment} />}
  </PromptInputAttachments>

  <PromptInputBody>
    <PromptInputTextarea placeholder="Type a message..." />
  </PromptInputBody>

  <PromptInputFooter>
    <PromptInputTools>
      <PromptInputButton onClick={() => attachments.openFileDialog()}>
        <PaperclipIcon />
      </PromptInputButton>
    </PromptInputTools>
    <PromptInputSubmit status={chatStatus} />
  </PromptInputFooter>
</PromptInput>
```

**Features:**
- Dual-mode operation (controlled/uncontrolled)
- Drag-and-drop file handling (local or global)
- Paste image/file support
- File validation (type, size, count)
- Automatic blob URL to data URL conversion
- Async/sync onSubmit support
- Auto-reset on successful submission

### PromptInputBody

Container for the main input area.

```typescript
type PromptInputBodyProps = HTMLAttributes<HTMLDivElement>;
```

**Usage:**

```tsx
<PromptInputBody>
  <PromptInputTextarea />
</PromptInputBody>
```

### PromptInputTextarea

Auto-expanding textarea with keyboard shortcuts and paste handling.

```typescript
type PromptInputTextareaProps = ComponentProps<typeof InputGroupTextarea>;
```

**Props:**
- `placeholder?: string` - Placeholder text (default: "What would you like to know?")
- Standard textarea props

**Usage:**

```tsx
<PromptInputTextarea
  placeholder="Ask me anything..."
  className="max-h-48 min-h-16"
/>
```

**Keyboard Shortcuts:**
- `Enter` - Submit (without Shift)
- `Shift+Enter` - New line
- `Backspace` - Remove last attachment when textarea is empty

**Features:**
- Auto-expands with content (field-sizing-content)
- Paste image/file support
- Composition event handling (for IME)
- Respects submit button disabled state
- Controlled/uncontrolled dual-mode

### PromptInputHeader

Header section for additional controls above the textarea.

```typescript
type PromptInputHeaderProps = Omit<ComponentProps<typeof InputGroupAddon>, "align">;
```

**Usage:**

```tsx
<PromptInputHeader>
  <PromptInputSelect>
    <PromptInputSelectTrigger>
      <PromptInputSelectValue placeholder="Select model" />
    </PromptInputSelectTrigger>
    <PromptInputSelectContent>
      <PromptInputSelectItem value="gpt-4">GPT-4</PromptInputSelectItem>
      <PromptInputSelectItem value="claude">Claude</PromptInputSelectItem>
    </PromptInputSelectContent>
  </PromptInputSelect>
</PromptInputHeader>
```

### PromptInputFooter

Footer section for tools and submit button.

```typescript
type PromptInputFooterProps = Omit<ComponentProps<typeof InputGroupAddon>, "align">;
```

**Usage:**

```tsx
<PromptInputFooter>
  <PromptInputTools>
    {/* Tool buttons */}
  </PromptInputTools>
  <PromptInputSubmit status="ready" />
</PromptInputFooter>
```

### PromptInputTools

Container for tool buttons in the footer.

```typescript
type PromptInputToolsProps = HTMLAttributes<HTMLDivElement>;
```

**Usage:**

```tsx
<PromptInputTools>
  <PromptInputButton onClick={openFileDialog}>
    <PaperclipIcon />
  </PromptInputButton>
  <PromptInputSpeechButton textareaRef={textareaRef} />
</PromptInputTools>
```

### PromptInputButton

Generic button for actions and tools.

```typescript
type PromptInputButtonProps = ComponentProps<typeof InputGroupButton>;
```

**Props:**
- `variant?: ButtonVariant` - Button style (default: "ghost")
- `size?: ButtonSize` - Button size (auto-determined based on children)

**Usage:**

```tsx
<PromptInputButton onClick={handleAction}>
  <IconComponent />
</PromptInputButton>

<PromptInputButton onClick={handleAction}>
  <IconComponent />
  Label
</PromptInputButton>
```

## State Management

### PromptInputProvider

Optional global provider that lifts input and attachment state outside of PromptInput.

```typescript
type PromptInputProviderProps = PropsWithChildren<{
  initialInput?: string;
}>;
```

**Usage:**

```tsx
<PromptInputProvider initialInput="">
  {/* App content */}
  <PromptInput onSubmit={handleSubmit}>
    {/* Input content */}
  </PromptInput>

  {/* External components can access state */}
  <ExternalComponent />
</PromptInputProvider>
```

**Provides:**
- `textInput: TextInputContext` - Text state and setters
- `attachments: AttachmentsContext` - File state and methods
- `__registerFileInput` - Internal registration method

### usePromptInputController

Hook to access the provider state.

```typescript
const usePromptInputController = () => {
  const { textInput, attachments } = usePromptInputController();

  return {
    textInput: {
      value: string;
      setInput: (v: string) => void;
      clear: () => void;
    },
    attachments: {
      files: (FileUIPart & { id: string })[];
      add: (files: File[] | FileList) => void;
      remove: (id: string) => void;
      clear: () => void;
      openFileDialog: () => void;
      fileInputRef: RefObject<HTMLInputElement | null>;
    }
  };
};
```

**Usage:**

```tsx
function ExternalComponent() {
  const { textInput, attachments } = usePromptInputController();

  return (
    <div>
      <p>Current input: {textInput.value}</p>
      <p>Attachments: {attachments.files.length}</p>
      <Button onClick={() => textInput.clear()}>Clear</Button>
    </div>
  );
}
```

### useProviderAttachments

Hook to access attachment state from provider.

```typescript
const useProviderAttachments = () => AttachmentsContext;
```

### usePromptInputAttachments

Hook to access attachment state (dual-mode: provider or local).

```typescript
const usePromptInputAttachments = () => AttachmentsContext;
```

## Attachment Handling

### PromptInputAttachments

Container for rendering attachments.

```typescript
type PromptInputAttachmentsProps = Omit<HTMLAttributes<HTMLDivElement>, "children"> & {
  children: (attachment: FileUIPart & { id: string }) => ReactNode;
};
```

**Usage:**

```tsx
<PromptInputAttachments>
  {(attachment) => (
    <PromptInputAttachment data={attachment} />
  )}
</PromptInputAttachments>
```

**Behavior:**
- Only renders if attachments exist
- Uses render prop pattern for flexibility

### PromptInputAttachment

Individual attachment display with preview and remove button.

```typescript
type PromptInputAttachmentProps = HTMLAttributes<HTMLDivElement> & {
  data: FileUIPart & { id: string };
  className?: string;
};
```

**Usage:**

```tsx
<PromptInputAttachment
  data={{
    id: "abc123",
    type: "file",
    url: "blob:...",
    filename: "image.png",
    mediaType: "image/png"
  }}
/>
```

**Features:**
- Image preview for image/* media types
- Paperclip icon for other files
- Hover to reveal remove button
- Hover card with full preview
- Truncated filename display

### PromptInputHoverCard

Hover card for attachment preview.

```typescript
type PromptInputHoverCardProps = ComponentProps<typeof HoverCard>;
```

**Default Delays:**
- `openDelay: 0` - Instant open
- `closeDelay: 0` - Instant close

### PromptInputHoverCardContent

Content area for hover card preview.

```typescript
type PromptInputHoverCardContentProps = ComponentProps<typeof HoverCardContent>;
```

## Action Menus

### PromptInputActionMenu

Dropdown menu for additional actions.

```typescript
type PromptInputActionMenuProps = ComponentProps<typeof DropdownMenu>;
```

**Usage:**

```tsx
<PromptInputActionMenu>
  <PromptInputActionMenuTrigger>
    <PlusIcon />
  </PromptInputActionMenuTrigger>
  <PromptInputActionMenuContent>
    <PromptInputActionAddAttachments label="Add files" />
    <PromptInputActionMenuItem>
      <SettingsIcon className="mr-2 size-4" />
      Settings
    </PromptInputActionMenuItem>
  </PromptInputActionMenuContent>
</PromptInputActionMenu>
```

### PromptInputActionMenuTrigger

Trigger button for action menu.

```typescript
type PromptInputActionMenuTriggerProps = PromptInputButtonProps;
```

**Default Icon:** `PlusIcon`

### PromptInputActionMenuContent

Content area for menu items.

```typescript
type PromptInputActionMenuContentProps = ComponentProps<typeof DropdownMenuContent>;
```

**Default Alignment:** `align="start"`

### PromptInputActionMenuItem

Individual menu item.

```typescript
type PromptInputActionMenuItemProps = ComponentProps<typeof DropdownMenuItem>;
```

### PromptInputActionAddAttachments

Pre-built menu item for adding attachments.

```typescript
type PromptInputActionAddAttachmentsProps = ComponentProps<typeof DropdownMenuItem> & {
  label?: string;
};
```

**Props:**
- `label?: string` - Button label (default: "Add photos or files")

**Usage:**

```tsx
<PromptInputActionMenuContent>
  <PromptInputActionAddAttachments label="Upload images" />
</PromptInputActionMenuContent>
```

## Submit Button

### PromptInputSubmit

Status-aware submit button with dynamic icons.

```typescript
type PromptInputSubmitProps = ComponentProps<typeof InputGroupButton> & {
  status?: ChatStatus; // "submitted" | "streaming" | "error" | "ready"
};
```

**Status Icons:**
- `undefined` / `"ready"` - `CornerDownLeftIcon` (enter key)
- `"submitted"` - `Loader2Icon` (spinning)
- `"streaming"` - `SquareIcon` (stop)
- `"error"` - `XIcon` (error)

**Usage:**

```tsx
<PromptInputSubmit status={chatStatus} />
```

**Behavior:**
- `type="submit"` - Triggers form submission
- `aria-label="Submit"` - Accessible label

## Speech Input

### PromptInputSpeechButton

Voice input button using Web Speech API.

```typescript
type PromptInputSpeechButtonProps = ComponentProps<typeof PromptInputButton> & {
  textareaRef?: RefObject<HTMLTextAreaElement | null>;
  onTranscriptionChange?: (text: string) => void;
};
```

**Props:**
- `textareaRef?: RefObject` - Reference to textarea for text insertion
- `onTranscriptionChange?: (text: string) => void` - Callback when text changes

**Usage:**

```tsx
const textareaRef = useRef<HTMLTextAreaElement>(null);

<PromptInputTextarea ref={textareaRef} />
<PromptInputSpeechButton
  textareaRef={textareaRef}
  onTranscriptionChange={(text) => console.log("Transcribed:", text)}
/>
```

**Features:**
- Browser-based speech recognition
- Continuous recording mode
- Interim results support
- Automatic text insertion
- Visual feedback (pulse animation when listening)
- Disabled if browser doesn't support Speech Recognition
- Error handling

## Advanced Features

### Select Components

For model selection or other dropdowns.

```tsx
<PromptInputSelect value={model} onValueChange={setModel}>
  <PromptInputSelectTrigger>
    <PromptInputSelectValue placeholder="Select model" />
  </PromptInputSelectTrigger>
  <PromptInputSelectContent>
    <PromptInputSelectItem value="gpt-4">GPT-4</PromptInputSelectItem>
    <PromptInputSelectItem value="claude">Claude</PromptInputSelectItem>
  </PromptInputSelectContent>
</PromptInputSelect>
```

### Command Components

For slash commands or autocomplete.

```tsx
<PromptInputCommand>
  <PromptInputCommandInput placeholder="Search commands..." />
  <PromptInputCommandList>
    <PromptInputCommandEmpty>No commands found</PromptInputCommandEmpty>
    <PromptInputCommandGroup heading="Actions">
      <PromptInputCommandItem value="summarize">
        Summarize
      </PromptInputCommandItem>
      <PromptInputCommandItem value="translate">
        Translate
      </PromptInputCommandItem>
    </PromptInputCommandGroup>
    <PromptInputCommandSeparator />
    <PromptInputCommandGroup heading="Settings">
      <PromptInputCommandItem value="preferences">
        Preferences
      </PromptInputCommandItem>
    </PromptInputCommandGroup>
  </PromptInputCommandList>
</PromptInputCommand>
```

### Tab Components

For organizing input modes or templates.

```tsx
<PromptInputTabsList>
  <PromptInputTab>
    <PromptInputTabLabel>Templates</PromptInputTabLabel>
    <PromptInputTabBody>
      <PromptInputTabItem>Summarize article</PromptInputTabItem>
      <PromptInputTabItem>Write email</PromptInputTabItem>
    </PromptInputTabBody>
  </PromptInputTab>
</PromptInputTabsList>
```

## Complete Example

```tsx
import { useRef, useState } from "react";
import {
  PromptInput,
  PromptInputProvider,
  PromptInputAttachments,
  PromptInputAttachment,
  PromptInputBody,
  PromptInputTextarea,
  PromptInputFooter,
  PromptInputTools,
  PromptInputButton,
  PromptInputSpeechButton,
  PromptInputSubmit,
  PromptInputActionMenu,
  PromptInputActionMenuTrigger,
  PromptInputActionMenuContent,
  PromptInputActionAddAttachments,
  usePromptInputAttachments,
} from "@/components/ai-elements/prompt-input";
import { PaperclipIcon, PlusIcon } from "lucide-react";

function ChatInput() {
  const [status, setStatus] = useState<ChatStatus>("ready");
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const attachments = usePromptInputAttachments();

  const handleSubmit = async (message: PromptInputMessage) => {
    setStatus("submitted");
    try {
      await sendMessage(message.text, message.files);
      setStatus("ready");
    } catch (error) {
      setStatus("error");
    }
  };

  return (
    <PromptInput
      accept="image/*,.pdf,.doc,.docx"
      multiple
      maxFiles={10}
      maxFileSize={10 * 1024 * 1024}
      onError={(err) => toast.error(err.message)}
      onSubmit={handleSubmit}
    >
      <PromptInputAttachments>
        {(attachment) => <PromptInputAttachment data={attachment} />}
      </PromptInputAttachments>

      <PromptInputBody>
        <PromptInputTextarea
          ref={textareaRef}
          placeholder="Type a message..."
        />
      </PromptInputBody>

      <PromptInputFooter>
        <PromptInputTools>
          <PromptInputButton onClick={() => attachments.openFileDialog()}>
            <PaperclipIcon className="size-4" />
          </PromptInputButton>

          <PromptInputSpeechButton textareaRef={textareaRef} />

          <PromptInputActionMenu>
            <PromptInputActionMenuTrigger>
              <PlusIcon className="size-4" />
            </PromptInputActionMenuTrigger>
            <PromptInputActionMenuContent>
              <PromptInputActionAddAttachments />
              <PromptInputActionMenuItem>
                Insert template
              </PromptInputActionMenuItem>
            </PromptInputActionMenuContent>
          </PromptInputActionMenu>
        </PromptInputTools>

        <PromptInputSubmit status={status} />
      </PromptInputFooter>
    </PromptInput>
  );
}

// With global provider
function App() {
  return (
    <PromptInputProvider initialInput="">
      <ChatInput />
    </PromptInputProvider>
  );
}
```
