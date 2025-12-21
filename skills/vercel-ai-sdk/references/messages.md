# UIMessage Structure Reference

Complete reference for the UIMessage type system and message parts.

## Table of Contents

- [UIMessage Interface](#uimessage-interface)
- [Message Parts](#message-parts)
- [Text Parts](#text-parts)
- [Tool Parts](#tool-parts)
- [File Parts](#file-parts)
- [Reasoning Parts](#reasoning-parts)
- [Data Parts](#data-parts)
- [Type Guards](#type-guards)
- [Type Inference](#type-inference)

## UIMessage Interface

```typescript
interface UIMessage<
  METADATA = unknown,
  DATA_PARTS extends UIDataTypes = UIDataTypes,
  TOOLS extends UITools = UITools,
> {
  // Unique identifier
  id: string;

  // Message role
  role: 'system' | 'user' | 'assistant';

  // Optional custom metadata
  metadata?: METADATA;

  // Array of message parts
  parts: Array<UIMessagePart<DATA_PARTS, TOOLS>>;
}
```

### Role Guidelines

- **`system`**: System prompts (avoid in UI messages, set on server instead)
- **`user`**: User-generated messages (text, files)
- **`assistant`**: AI-generated messages (text, reasoning, tools, files)

### Parts-Based Architecture

Unlike traditional chat systems with single `content` fields, UIMessages use a `parts` array. This enables:

- Multiple content types in a single message
- Independent streaming states for each part
- Tool calls with their own state machines
- File attachments mixed with text
- Custom data parts for specialized UI

## Message Parts

```typescript
type UIMessagePart<DATA_TYPES, TOOLS> =
  | TextUIPart
  | ReasoningUIPart
  | ToolUIPart<TOOLS>
  | DynamicToolUIPart
  | SourceUrlUIPart
  | SourceDocumentUIPart
  | FileUIPart
  | DataUIPart<DATA_TYPES>
  | StepStartUIPart;
```

## Text Parts

### TextUIPart

```typescript
interface TextUIPart {
  type: 'text';
  text: string;
  state?: 'streaming' | 'done';
  providerMetadata?: ProviderMetadata;
}
```

### Usage

```typescript
// Complete text
const textPart: TextUIPart = {
  type: 'text',
  text: 'Hello, world!',
  state: 'done'
};

// Streaming text
const streamingPart: TextUIPart = {
  type: 'text',
  text: 'Hello, wor',
  state: 'streaming'
};
```

### Rendering

```typescript
function renderTextPart(part: TextUIPart) {
  return (
    <div className={part.state === 'streaming' ? 'opacity-70' : ''}>
      {part.text}
      {part.state === 'streaming' && <Cursor />}
    </div>
  );
}
```

## Tool Parts

### ToolUIPart

Type-safe tool parts with tool name in the type.

```typescript
type ToolUIPart<TOOLS extends UITools> = ValueOf<{
  [NAME in keyof TOOLS & string]: {
    type: `tool-${NAME}`;
  } & UIToolInvocation<TOOLS[NAME]>;
}>;
```

### UIToolInvocation States

Tool parts have a state machine with the following states:

```typescript
type UIToolInvocation<TOOL> =
  | { state: 'input-streaming'; input: Partial<ToolInput> | undefined; }
  | { state: 'input-available'; input: ToolInput; callProviderMetadata?: ProviderMetadata; }
  | { state: 'approval-requested'; input: ToolInput; approval: { id: string }; }
  | { state: 'approval-responded'; input: ToolInput; approval: { id: string; approved: boolean; reason?: string }; }
  | { state: 'output-available'; input: ToolInput; output: ToolOutput; preliminary?: boolean; }
  | { state: 'output-error'; input: ToolInput | undefined; errorText: string; }
  | { state: 'output-denied'; input: ToolInput; approval: { id: string; approved: false; reason?: string }; }
```

**Common fields:**
- `toolCallId: string` - Unique identifier for this tool call
- `title?: string` - Optional display title
- `providerExecuted?: boolean` - True if provider executed the tool

### State Progression

```
input-streaming → input-available → [approval flow] → output-available
                                  ↓
                            approval-requested → approval-responded → output-available/output-denied
                                                                    ↓
                                                              (at any point) → output-error
```

### Example: Rendering Tool Parts

```typescript
function renderToolPart(part: ToolUIPart<MyTools>) {
  // Extract common fields
  const { toolCallId, title } = part;

  // Type narrows based on tool type
  if (part.type === 'tool-getWeather') {
    switch (part.state) {
      case 'input-streaming':
        return (
          <div>
            Preparing weather request...
            <pre>{JSON.stringify(part.input, null, 2)}</pre>
          </div>
        );

      case 'input-available':
        return <div>Fetching weather for {part.input.city}...</div>;

      case 'output-available':
        return (
          <div>
            Weather in {part.input.city}: {part.output.weather}
            {part.preliminary && <Badge>Preliminary</Badge>}
          </div>
        );

      case 'output-error':
        return <div className="error">{part.errorText}</div>;
    }
  }

  if (part.type === 'tool-askConfirmation') {
    switch (part.state) {
      case 'approval-requested':
        return (
          <div>
            {part.input.message}
            <button onClick={() => approve(part.approval.id)}>Yes</button>
            <button onClick={() => deny(part.approval.id)}>No</button>
          </div>
        );

      case 'approval-responded':
        return (
          <div>
            User {part.approval.approved ? 'approved' : 'denied'}
            {part.approval.reason && `: ${part.approval.reason}`}
          </div>
        );
    }
  }
}
```

### DynamicToolUIPart

For tools not known at compile time.

```typescript
interface DynamicToolUIPart {
  type: 'dynamic-tool';
  toolName: string; // Name as string, not in type
  toolCallId: string;
  title?: string;
  providerExecuted?: boolean;
  // Same state union as UIToolInvocation but with unknown types
  state: 'input-streaming' | 'input-available' | ...;
  input: unknown;
  output?: unknown;
  errorText?: string;
}
```

### Tool Type Utilities

```typescript
// Check if part is a tool part
if (isToolUIPart(part)) {
  const toolName = getToolName(part); // Type-safe tool name
}

// Check if tool or dynamic tool
if (isToolOrDynamicToolUIPart(part)) {
  const name = getToolOrDynamicToolName(part); // string
}

// Check if dynamic tool
if (isDynamicToolUIPart(part)) {
  console.log(part.toolName); // Access toolName field
}
```

## File Parts

### FileUIPart

```typescript
interface FileUIPart {
  type: 'file';
  mediaType: string; // IANA media type
  filename?: string;
  url: string; // Hosted URL or Data URL
  providerMetadata?: ProviderMetadata;
}
```

### Usage

```typescript
// Image file
const imagePart: FileUIPart = {
  type: 'file',
  mediaType: 'image/png',
  filename: 'screenshot.png',
  url: 'data:image/png;base64,iVBORw0KG...'
};

// PDF document
const pdfPart: FileUIPart = {
  type: 'file',
  mediaType: 'application/pdf',
  filename: 'report.pdf',
  url: 'https://example.com/files/report.pdf'
};
```

### Rendering

```typescript
function renderFilePart(part: FileUIPart) {
  if (part.mediaType.startsWith('image/')) {
    return <img src={part.url} alt={part.filename} />;
  }

  if (part.mediaType.startsWith('video/')) {
    return <video src={part.url} controls />;
  }

  return (
    <a href={part.url} download={part.filename}>
      {part.filename || 'Download file'}
    </a>
  );
}
```

## Reasoning Parts

### ReasoningUIPart

For AI reasoning traces (e.g., from OpenAI o1 models).

```typescript
interface ReasoningUIPart {
  type: 'reasoning';
  text: string;
  state?: 'streaming' | 'done';
  providerMetadata?: ProviderMetadata;
}
```

### Usage

```typescript
function renderReasoningPart(part: ReasoningUIPart) {
  return (
    <details>
      <summary>Reasoning</summary>
      <div className="reasoning">
        {part.text}
        {part.state === 'streaming' && <Spinner />}
      </div>
    </details>
  );
}
```

## Data Parts

### DataUIPart

Custom data parts for specialized UI components.

```typescript
type DataUIPart<DATA_TYPES extends UIDataTypes> = ValueOf<{
  [NAME in keyof DATA_TYPES & string]: {
    type: `data-${NAME}`;
    id?: string;
    data: DATA_TYPES[NAME];
  };
}>;
```

### Defining Custom Data Types

```typescript
// Define data types
type MyDataTypes = {
  progress: { percent: number; status: string };
  chart: { data: number[]; labels: string[] };
};

// Use in message type
type MyMessage = UIMessage<unknown, MyDataTypes>;

// Create data parts
const progressPart: DataUIPart<MyDataTypes> = {
  type: 'data-progress',
  data: { percent: 75, status: 'Processing...' }
};

const chartPart: DataUIPart<MyDataTypes> = {
  type: 'data-chart',
  id: 'chart-1',
  data: {
    data: [10, 20, 30],
    labels: ['A', 'B', 'C']
  }
};
```

### Rendering Custom Data

```typescript
function renderDataPart(part: UIMessagePart<MyDataTypes, MyTools>) {
  if (isDataUIPart(part)) {
    if (part.type === 'data-progress') {
      return (
        <ProgressBar
          percent={part.data.percent}
          label={part.data.status}
        />
      );
    }

    if (part.type === 'data-chart') {
      return <Chart data={part.data.data} labels={part.data.labels} />;
    }
  }
}
```

## Source Parts

### SourceUrlUIPart

```typescript
interface SourceUrlUIPart {
  type: 'source-url';
  sourceId: string;
  url: string;
  title?: string;
  providerMetadata?: ProviderMetadata;
}
```

### SourceDocumentUIPart

```typescript
interface SourceDocumentUIPart {
  type: 'source-document';
  sourceId: string;
  mediaType: string;
  title: string;
  filename?: string;
  providerMetadata?: ProviderMetadata;
}
```

### Usage

```typescript
// URL source
const urlSource: SourceUrlUIPart = {
  type: 'source-url',
  sourceId: 'src-1',
  url: 'https://example.com/article',
  title: 'Example Article'
};

// Document source
const docSource: SourceDocumentUIPart = {
  type: 'source-document',
  sourceId: 'src-2',
  mediaType: 'application/pdf',
  title: 'Research Paper',
  filename: 'paper.pdf'
};
```

## Step Parts

### StepStartUIPart

Marks the beginning of a new reasoning/execution step.

```typescript
interface StepStartUIPart {
  type: 'step-start';
}
```

### Rendering

```typescript
function renderMessage(message: UIMessage) {
  return (
    <div>
      {message.parts.map((part, index) => {
        if (part.type === 'step-start' && index > 0) {
          return <hr key={index} className="step-divider" />;
        }
        return renderPart(part, index);
      })}
    </div>
  );
}
```

## Type Guards

```typescript
// Text
if (isTextUIPart(part)) {
  console.log(part.text);
}

// File
if (isFileUIPart(part)) {
  console.log(part.url, part.mediaType);
}

// Reasoning
if (isReasoningUIPart(part)) {
  console.log(part.text);
}

// Tool (static)
if (isToolUIPart(part)) {
  const toolName = getToolName(part);
}

// Dynamic tool
if (isDynamicToolUIPart(part)) {
  console.log(part.toolName);
}

// Tool or dynamic tool
if (isToolOrDynamicToolUIPart(part)) {
  const name = getToolOrDynamicToolName(part);
}

// Data
if (isDataUIPart(part)) {
  // Check specific data type
  if (part.type === 'data-progress') {
    console.log(part.data.percent);
  }
}
```

## Type Inference

### Infer from UIMessage

```typescript
type MyMessage = UIMessage<
  { createdAt: number },
  { progress: { percent: number } },
  { getTool: { input: string; output: number } }
>;

// Infer metadata type
type Metadata = InferUIMessageMetadata<MyMessage>;
// { createdAt: number }

// Infer data types
type DataTypes = InferUIMessageData<MyMessage>;
// { progress: { percent: number } }

// Infer tool types
type Tools = InferUIMessageTools<MyMessage>;
// { getTool: { input: string; output: number } }

// Infer tool outputs
type ToolOutputs = InferUIMessageToolOutputs<MyMessage>;
// number

// Infer tool calls
type ToolCall = InferUIMessageToolCall<MyMessage>;
// ToolCall<'getTool', string> | ...

// Infer part type
type Part = InferUIMessagePart<MyMessage>;
// TextUIPart | ToolUIPart<...> | DataUIPart<...> | ...
```

### Infer Tool Types

```typescript
import { InferUITool, InferUITools } from 'ai';

const weatherTool = tool({
  inputSchema: z.object({ city: z.string() }),
  execute: async ({ city }) => ({ temp: 72 })
});

// Infer single tool
type WeatherTool = InferUITool<typeof weatherTool>;
// { input: { city: string }; output: { temp: number } }

// Infer tool set
const tools = { weather: weatherTool };
type MyTools = InferUITools<typeof tools>;
// { weather: { input: { city: string }; output: { temp: number } } }
```

## Complete Example

```typescript
import { UIMessage, InferUITools, isTextUIPart, isToolUIPart } from 'ai';

// Define tools
const tools = {
  getWeather: tool({
    inputSchema: z.object({ city: z.string() }),
    execute: async ({ city }) => ({ weather: 'sunny', temp: 72 })
  })
};

// Define message type
type MyMessage = UIMessage<
  { createdAt: number },
  { progress: { percent: number } },
  InferUITools<typeof tools>
>;

// Render function
function Message({ message }: { message: MyMessage }) {
  return (
    <div className={`message message-${message.role}`}>
      <div className="timestamp">
        {new Date(message.metadata.createdAt).toLocaleString()}
      </div>

      <div className="parts">
        {message.parts.map((part, index) => {
          if (isTextUIPart(part)) {
            return <div key={index}>{part.text}</div>;
          }

          if (part.type === 'tool-getWeather') {
            if (part.state === 'output-available') {
              return (
                <div key={index}>
                  Weather: {part.output.weather}, {part.output.temp}°F
                </div>
              );
            }
          }

          if (part.type === 'data-progress') {
            return (
              <ProgressBar
                key={index}
                percent={part.data.percent}
              />
            );
          }

          return null;
        })}
      </div>
    </div>
  );
}
```
