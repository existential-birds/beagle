# useChat Hook Reference

Complete API reference for the `useChat` hook from `@ai-sdk/react`.

## Table of Contents

- [Hook Signature](#hook-signature)
- [Options](#options)
- [Return Values](#return-values)
- [Methods](#methods)
- [Callbacks](#callbacks)
- [Types](#types)

## Hook Signature

```typescript
function useChat<UI_MESSAGE extends UIMessage = UIMessage>(
  options?: UseChatOptions<UI_MESSAGE>
): UseChatHelpers<UI_MESSAGE>
```

## Options

### Basic Options

```typescript
interface UseChatOptions<UI_MESSAGE extends UIMessage> {
  // Chat instance (existing) or initialization parameters
  chat?: Chat<UI_MESSAGE>;

  // Chat identifier (auto-generated if not provided)
  id?: string;

  // Initial messages
  messages?: UI_MESSAGE[];

  // Whether to resume an ongoing stream on mount
  resume?: boolean;

  // Custom transport for API communication
  transport?: ChatTransport<UI_MESSAGE>;

  // ID generator function
  generateId?: IdGenerator;
}
```

### Schema Options

```typescript
interface UseChatOptions<UI_MESSAGE extends UIMessage> {
  // Schema for message metadata validation
  messageMetadataSchema?: FlexibleSchema<InferUIMessageMetadata<UI_MESSAGE>>;

  // Schemas for custom data parts
  dataPartSchemas?: UIDataTypesToSchemas<InferUIMessageData<UI_MESSAGE>>;
}
```

### Performance Options

```typescript
interface UseChatOptions<UI_MESSAGE extends UIMessage> {
  // Throttle message updates (in milliseconds)
  // Default: undefined (no throttling)
  experimental_throttle?: number;
}
```

### Callback Options

```typescript
interface UseChatOptions<UI_MESSAGE extends UIMessage> {
  // Called when an error occurs
  onError?: (error: Error) => void;

  // Called when a tool call is received
  onToolCall?: (options: {
    toolCall: InferUIMessageToolCall<UI_MESSAGE>;
  }) => void | PromiseLike<void>;

  // Called when streaming finishes
  onFinish?: (options: {
    message: UI_MESSAGE;
    messages: UI_MESSAGE[];
    isAbort: boolean;
    isDisconnect: boolean;
    isError: boolean;
    finishReason?: FinishReason;
  }) => void;

  // Called when a data part is received
  onData?: (dataPart: DataUIPart<InferUIMessageData<UI_MESSAGE>>) => void;
}
```

### Automation Options

```typescript
interface UseChatOptions<UI_MESSAGE extends UIMessage> {
  // Automatically send messages when condition is met
  sendAutomaticallyWhen?: (options: {
    messages: UI_MESSAGE[];
  }) => boolean | PromiseLike<boolean>;
}
```

## Return Values

```typescript
interface UseChatHelpers<UI_MESSAGE extends UIMessage> {
  // Chat identifier
  readonly id: string;

  // Current chat status
  status: ChatStatus;

  // Current error (if any)
  error: Error | undefined;

  // Array of all messages
  messages: UI_MESSAGE[];

  // Methods (see below)
  sendMessage: (message?, options?) => Promise<void>;
  regenerate: (options?) => Promise<void>;
  stop: () => Promise<void>;
  resumeStream: (options?) => Promise<void>;
  setMessages: (messages) => void;
  clearError: () => void;
  addToolOutput: (options) => Promise<void>;
  addToolApprovalResponse: (options) => Promise<void>;

  // Deprecated
  addToolResult: (options) => Promise<void>; // Use addToolOutput
}
```

### ChatStatus Type

```typescript
type ChatStatus = 'ready' | 'submitted' | 'streaming' | 'error';
```

- **`ready`**: No active request, ready for new messages
- **`submitted`**: Request sent, awaiting stream start
- **`streaming`**: Response actively streaming
- **`error`**: Error occurred during request

## Methods

### sendMessage

Send a new user message or replace an existing one.

```typescript
// Send text message
await sendMessage({ text: 'Hello' });

// Send with files
await sendMessage({
  text: 'Analyze this image',
  files: fileList // FileList or FileUIPart[]
});

// Send with metadata
await sendMessage({
  text: 'Hello',
  metadata: { createdAt: Date.now(), userId: '123' }
});

// Replace existing message
await sendMessage({
  text: 'Updated message',
  messageId: 'msg-123'
});

// Send full UIMessage structure
await sendMessage({
  parts: [
    { type: 'text', text: 'Hello' },
    { type: 'file', url: 'data:...', mediaType: 'image/png' }
  ],
  metadata: { custom: 'data' }
});

// Send with request options
await sendMessage(
  { text: 'Hello' },
  {
    headers: { 'X-Custom': 'value' },
    body: { extra: 'data' },
    metadata: { custom: 'metadata' }
  }
);

// Continue existing conversation (no message)
await sendMessage();
```

**Signature:**
```typescript
sendMessage: (
  message?:
    | { text: string; files?: FileList | FileUIPart[]; metadata?: Metadata; messageId?: string }
    | { files: FileList | FileUIPart[]; metadata?: Metadata; messageId?: string }
    | CreateUIMessage<UI_MESSAGE> & { messageId?: string },
  options?: ChatRequestOptions
) => Promise<void>
```

### regenerate

Regenerate an assistant message.

```typescript
// Regenerate last assistant message
await regenerate();

// Regenerate specific message
await regenerate({ messageId: 'msg-123' });

// With request options
await regenerate({
  messageId: 'msg-123',
  headers: { 'X-Custom': 'value' }
});
```

**Signature:**
```typescript
regenerate: (options?: {
  messageId?: string;
  headers?: Record<string, string> | Headers;
  body?: object;
  metadata?: unknown;
}) => Promise<void>
```

### stop

Stop the current streaming request.

```typescript
await stop();
```

Aborts the active request and sets status to `ready`. Keeps any tokens generated so far.

### resumeStream

Resume an interrupted streaming response.

```typescript
await resumeStream();

// With options
await resumeStream({
  headers: { 'X-Session': 'token' }
});
```

**Signature:**
```typescript
resumeStream: (options?: ChatRequestOptions) => Promise<void>
```

### setMessages

Update messages locally without triggering a request.

```typescript
// Set messages directly
setMessages([...newMessages]);

// Update with function
setMessages(current => current.filter(m => m.role !== 'system'));

// Clear all messages
setMessages([]);
```

**Signature:**
```typescript
setMessages: (
  messages: UI_MESSAGE[] | ((messages: UI_MESSAGE[]) => UI_MESSAGE[])
) => void
```

### clearError

Clear error state and reset to ready.

```typescript
if (error) {
  clearError();
}
```

### addToolOutput

Provide output for a client-side tool call.

```typescript
// Successful tool execution
await addToolOutput({
  tool: 'getWeather',
  toolCallId: 'call-123',
  output: { temperature: 72, weather: 'sunny' }
});

// Tool execution error
await addToolOutput({
  state: 'output-error',
  tool: 'getWeather',
  toolCallId: 'call-123',
  errorText: 'API unavailable'
});
```

**Signature:**
```typescript
addToolOutput: <TOOL extends keyof Tools>(
  options:
    | {
        state?: 'output-available';
        tool: TOOL;
        toolCallId: string;
        output: ToolOutput<TOOL>;
      }
    | {
        state: 'output-error';
        tool: TOOL;
        toolCallId: string;
        errorText: string;
      }
) => Promise<void>
```

### addToolApprovalResponse

Respond to a tool approval request.

```typescript
// Approve tool execution
await addToolApprovalResponse({
  id: 'approval-123',
  approved: true,
  reason: 'Safe to proceed'
});

// Deny tool execution
await addToolApprovalResponse({
  id: 'approval-123',
  approved: false,
  reason: 'User denied location access'
});
```

**Signature:**
```typescript
addToolApprovalResponse: (options: {
  id: string;
  approved: boolean;
  reason?: string;
}) => Promise<void>
```

## Callbacks

### onError

Called when any error occurs during the chat.

```typescript
useChat({
  onError: (error) => {
    console.error('Chat error:', error);
    toast.error(error.message);
  }
});
```

### onToolCall

Called when a tool call is received. Use for automatic client-side tool execution.

```typescript
useChat({
  onToolCall: async ({ toolCall }) => {
    // Handle different tools
    if (toolCall.toolName === 'getLocation') {
      const location = await getCurrentLocation();
      addToolOutput({
        tool: 'getLocation',
        toolCallId: toolCall.toolCallId,
        output: location
      });
    }
  }
});
```

**Important**: This callback is for automatic execution. For user-interactive tools (like confirmations), handle them in the render phase.

### onFinish

Called when streaming completes (success, abort, or error).

```typescript
useChat({
  onFinish: ({ message, messages, isAbort, isDisconnect, isError, finishReason }) => {
    if (isError) {
      console.error('Stream ended with error');
      return;
    }

    if (isAbort) {
      console.log('User aborted request');
      return;
    }

    if (isDisconnect) {
      console.warn('Network disconnected');
      return;
    }

    // Save to database
    saveMessages(messages);

    console.log('Finish reason:', finishReason); // 'stop' | 'length' | 'tool-calls' | ...
  }
});
```

### onData

Called when custom data parts are received.

```typescript
useChat<UIMessage<never, { progress: { percent: number } }>>({
  onData: (dataPart) => {
    if (dataPart.type === 'data-progress') {
      updateProgressBar(dataPart.data.percent);
    }
  }
});
```

## Types

### ChatRequestOptions

```typescript
interface ChatRequestOptions {
  // Additional headers for the API request
  headers?: Record<string, string> | Headers;

  // Additional body properties for the API request
  body?: object;

  // Request-specific metadata
  metadata?: unknown;
}
```

### CreateUIMessage

```typescript
type CreateUIMessage<UI_MESSAGE extends UIMessage> = Omit<
  UI_MESSAGE,
  'id' | 'role'
> & {
  id?: UI_MESSAGE['id'];
  role?: UI_MESSAGE['role'];
};
```

Used for creating messages without requiring `id` and `role` (auto-generated).

## Examples

### Basic Chat

```typescript
function ChatComponent() {
  const { messages, status, sendMessage } = useChat({
    id: 'my-chat',
    onError: (error) => toast.error(error.message)
  });

  return (
    <div>
      {messages.map(msg => (
        <div key={msg.id}>{msg.role}: {msg.parts[0]?.text}</div>
      ))}
      <input
        disabled={status !== 'ready'}
        onSubmit={(text) => sendMessage({ text })}
      />
    </div>
  );
}
```

### With Tools

```typescript
function ChatWithTools() {
  const { messages, addToolOutput } = useChat<MyToolMessage>({
    onToolCall: async ({ toolCall }) => {
      if (toolCall.toolName === 'autoExecute') {
        const result = await executeAutomatically();
        addToolOutput({
          tool: 'autoExecute',
          toolCallId: toolCall.toolCallId,
          output: result
        });
      }
    },
    sendAutomaticallyWhen: lastAssistantMessageIsCompleteWithToolCalls
  });

  return (
    <div>
      {messages.map(msg => (
        <Message
          key={msg.id}
          message={msg}
          onToolApprove={(toolCallId) =>
            addToolOutput({
              tool: 'userConfirm',
              toolCallId,
              output: 'confirmed'
            })
          }
        />
      ))}
    </div>
  );
}
```

### Custom Transport

```typescript
const { messages } = useChat({
  transport: new DefaultChatTransport({
    api: '/api/my-chat',
    prepareSendMessagesRequest: ({ id, messages, trigger, messageId }) => ({
      url: `/api/my-chat/${id}`,
      body: {
        lastMessage: messages[messages.length - 1],
        action: trigger,
        targetMessageId: messageId
      },
      headers: {
        'X-Session-Token': getSessionToken()
      }
    })
  })
});
```

### Throttled Updates

```typescript
// Update UI at most once per 100ms during streaming
const { messages } = useChat({
  experimental_throttle: 100
});
```

### Resume Interrupted Stream

```typescript
function ChatComponent({ chatId }) {
  const [shouldResume, setShouldResume] = useState(false);

  useEffect(() => {
    // Check if there's an active stream for this chat
    checkActiveStream(chatId).then(setShouldResume);
  }, [chatId]);

  const chat = useChat({
    id: chatId,
    resume: shouldResume
  });

  return <ChatUI {...chat} />;
}
```
