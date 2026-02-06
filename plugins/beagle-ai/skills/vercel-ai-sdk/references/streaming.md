# Streaming Reference

Server-side streaming implementation with the Vercel AI SDK.

## Table of Contents

- [Basic Streaming Setup](#basic-streaming-setup)
- [streamText Function](#streamtext-function)
- [toUIMessageStreamResponse](#touimessagestreamresponse)
- [UIMessageChunk Types](#uimessagechunk-types)
- [SSE Protocol](#sse-protocol)
- [Tool Execution Flow](#tool-execution-flow)
- [Error Handling](#error-handling)
- [Advanced Patterns](#advanced-patterns)

## Basic Streaming Setup

### Server Route

```typescript
import { streamText, convertToModelMessages } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4'),
    messages: convertToModelMessages(messages)
  });

  return result.toUIMessageStreamResponse();
}
```

### Client Setup

```typescript
import { useChat } from '@ai-sdk/react';

function Chat() {
  const { messages, sendMessage } = useChat({
    api: '/api/chat'
  });

  return <ChatUI messages={messages} onSend={sendMessage} />;
}
```

## streamText Function

### Basic Options

```typescript
const result = streamText({
  // Model to use
  model: openai('gpt-4'),

  // Messages (converted from UIMessage)
  messages: convertToModelMessages(uiMessages),

  // System prompt (optional)
  system: 'You are a helpful assistant.',

  // Temperature, max tokens, etc.
  temperature: 0.7,
  maxTokens: 2000,

  // Abort signal
  abortSignal: abortController.signal
});
```

### With Tools

```typescript
import { tool } from 'ai';
import { z } from 'zod';

const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),

  tools: {
    getWeather: tool({
      description: 'Get weather for a city',
      inputSchema: z.object({
        city: z.string()
      }),
      execute: async ({ city }) => {
        const data = await fetchWeather(city);
        return { temperature: data.temp, weather: data.conditions };
      }
    })
  }
});
```

### Multi-Step Tool Execution

```typescript
import { stepCountIs } from 'ai';

const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),
  tools: {
    getWeather: weatherTool,
    searchWeb: searchTool
  },

  // Allow up to 5 steps (model can call tools multiple times)
  stopWhen: stepCountIs(5)
});
```

### Streaming Tool Outputs

```typescript
const getWeatherTool = tool({
  description: 'Get weather information',
  inputSchema: z.object({ city: z.string() }),

  // Generator function for streaming outputs
  async *execute({ city }) {
    // Yield preliminary results
    yield { state: 'loading' as const };

    const data = await fetchWeather(city);

    // Yield intermediate results
    yield {
      state: 'partial' as const,
      temperature: data.temp
    };

    // Yield final result
    yield {
      state: 'complete' as const,
      temperature: data.temp,
      weather: data.conditions,
      forecast: data.forecast
    };
  }
});
```

### Callbacks

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),

  // Called on each chunk
  onChunk({ chunk }) {
    console.log('Chunk:', chunk);
  },

  // Called when a step finishes (with multi-step)
  onStepFinish({ request, response, toolCalls, toolResults }) {
    console.log('Step finished');
    console.log('Tool calls:', toolCalls);
    console.log('Tool results:', toolResults);
  },

  // Called when generation finishes
  onFinish({ text, finishReason, usage }) {
    console.log('Generated text:', text);
    console.log('Finish reason:', finishReason);
    console.log('Token usage:', usage);
  }
});
```

## toUIMessageStreamResponse

Convert streamText result to a UIMessage stream response.

### Basic Usage

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages)
});

return result.toUIMessageStreamResponse();
```

### With Options

```typescript
return result.toUIMessageStreamResponse({
  // Include original messages in the stream
  originalMessages: uiMessages,

  // Custom message ID generator
  generateMessageId: () => crypto.randomUUID(),

  // Add/update message metadata
  messageMetadata: ({ part, message }) => {
    if (part.type === 'start') {
      return { createdAt: Date.now() };
    }
    if (part.type === 'finish') {
      return { finishedAt: Date.now() };
    }
  },

  // Called when streaming finishes
  onFinish: ({ messages, finishReason }) => {
    // Save to database
    saveMessages(messages);
  }
});
```

### Custom Headers

```typescript
const response = result.toUIMessageStreamResponse({
  originalMessages: uiMessages
});

// Add custom headers
response.headers.set('X-Custom-Header', 'value');

return response;
```

## UIMessageChunk Types

Chunks sent over the stream as Server-Sent Events.

### Text Chunks

```typescript
// Text streaming starts
{ type: 'text-start', id: 'text-1' }

// Text delta (incremental update)
{ type: 'text-delta', id: 'text-1', delta: 'Hello' }
{ type: 'text-delta', id: 'text-1', delta: ' world' }

// Text streaming ends
{ type: 'text-end', id: 'text-1' }
```

### Reasoning Chunks

```typescript
// Reasoning starts
{ type: 'reasoning-start', id: 'reasoning-1' }

// Reasoning delta
{ type: 'reasoning-delta', id: 'reasoning-1', delta: 'First, ' }
{ type: 'reasoning-delta', id: 'reasoning-1', delta: 'I will...' }

// Reasoning ends
{ type: 'reasoning-end', id: 'reasoning-1' }
```

### Tool Chunks

```typescript
// Tool input streaming starts
{
  type: 'tool-input-start',
  toolCallId: 'call-123',
  toolName: 'getWeather',
  dynamic: false
}

// Tool input delta (for large inputs)
{
  type: 'tool-input-delta',
  toolCallId: 'call-123',
  inputTextDelta: '{"city": '
}

// Tool input complete
{
  type: 'tool-input-available',
  toolCallId: 'call-123',
  toolName: 'getWeather',
  input: { city: 'San Francisco' }
}

// Tool output available
{
  type: 'tool-output-available',
  toolCallId: 'call-123',
  output: { temperature: 72, weather: 'sunny' },
  preliminary: false
}

// Tool execution error
{
  type: 'tool-output-error',
  toolCallId: 'call-123',
  errorText: 'API unavailable'
}
```

### Tool Approval Chunks

```typescript
// Tool needs approval
{
  type: 'tool-approval-request',
  approvalId: 'approval-1',
  toolCallId: 'call-123'
}

// User responded (handled client-side, not streamed)
```

### Control Chunks

```typescript
// Stream starts
{
  type: 'start',
  messageId: 'msg-123',
  messageMetadata: { createdAt: 1234567890 }
}

// Stream finishes
{
  type: 'finish',
  finishReason: 'stop', // or 'length', 'tool-calls', 'content-filter'
  messageMetadata: { finishedAt: 1234567890 }
}

// Stream aborted
{ type: 'abort' }

// Error occurred
{ type: 'error', errorText: 'Something went wrong' }

// Metadata update
{
  type: 'message-metadata',
  messageMetadata: { updated: true }
}
```

### Step Chunks

```typescript
// New step starts (for multi-step reasoning)
{ type: 'start-step' }

// Step finishes
{ type: 'finish-step' }
```

### Data Chunks

```typescript
// Custom data part
{
  type: 'data-progress',
  id: 'progress-1',
  data: { percent: 50, status: 'Processing...' },
  transient: false // If true, not added to final message
}
```

### File Chunks

```typescript
{
  type: 'file',
  url: 'https://example.com/image.png',
  mediaType: 'image/png'
}
```

## SSE Protocol

### Format

```
event: message
data: {"type":"text-start","id":"text-1"}

event: message
data: {"type":"text-delta","id":"text-1","delta":"Hello"}

event: message
data: {"type":"text-delta","id":"text-1","delta":" world"}

event: message
data: {"type":"text-end","id":"text-1"}

event: message
data: {"type":"finish","finishReason":"stop"}
```

### Client-Side Parsing

The SDK handles parsing automatically, but for custom implementations:

```typescript
const eventSource = new EventSource('/api/chat');

eventSource.addEventListener('message', (event) => {
  const chunk: UIMessageChunk = JSON.parse(event.data);

  switch (chunk.type) {
    case 'text-delta':
      appendText(chunk.id, chunk.delta);
      break;

    case 'tool-output-available':
      updateToolOutput(chunk.toolCallId, chunk.output);
      break;

    case 'finish':
      console.log('Finished:', chunk.finishReason);
      eventSource.close();
      break;
  }
});
```

## Tool Execution Flow

### Server-Side Tools

```typescript
// 1. Client sends message
sendMessage({ text: 'What is the weather in SF?' });

// 2. Server streams tool invocation
{ type: 'tool-input-available', toolCallId: 'call-1', input: { city: 'San Francisco' } }

// 3. Server executes tool and streams output
{ type: 'tool-output-available', toolCallId: 'call-1', output: { temp: 72 } }

// 4. Server continues with model response
{ type: 'text-delta', delta: 'The weather is sunny...' }
```

### Client-Side Tools

```typescript
// 1. Client sends message
sendMessage({ text: 'Get my location' });

// 2. Server streams tool call (no execute)
{ type: 'tool-input-available', toolCallId: 'call-1', toolName: 'getLocation', input: {} }

// 3. Client handles tool call
onToolCall: async ({ toolCall }) => {
  const location = await getCurrentLocation();
  addToolOutput({
    toolCallId: toolCall.toolCallId,
    tool: 'getLocation',
    output: location
  });
}

// 4. Client sends tool output back to server
// 5. Server streams final response
```

### Preliminary Tool Outputs

For streaming tool results:

```typescript
// Tool yields intermediate result
{
  type: 'tool-output-available',
  toolCallId: 'call-1',
  output: { state: 'loading' },
  preliminary: true
}

// Tool yields final result
{
  type: 'tool-output-available',
  toolCallId: 'call-1',
  output: { state: 'complete', data: {...} },
  preliminary: false // or omitted
}
```

## Error Handling

### Server-Side Errors

```typescript
try {
  const result = streamText({
    model: openai('gpt-4'),
    messages: convertToModelMessages(uiMessages)
  });

  return result.toUIMessageStreamResponse();
} catch (error) {
  // Stream error chunk
  return new Response(
    new ReadableStream({
      start(controller) {
        const chunk: UIMessageChunk = {
          type: 'error',
          errorText: error.message
        };
        controller.enqueue(
          new TextEncoder().encode(
            `event: message\ndata: ${JSON.stringify(chunk)}\n\n`
          )
        );
        controller.close();
      }
    }),
    {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache'
      }
    }
  );
}
```

### Tool Execution Errors

```typescript
const weatherTool = tool({
  inputSchema: z.object({ city: z.string() }),
  async execute({ city }) {
    try {
      return await fetchWeather(city);
    } catch (error) {
      // Error is automatically converted to tool-output-error chunk
      throw new Error(`Failed to fetch weather: ${error.message}`);
    }
  }
});
```

### Client-Side Error Handling

```typescript
const { error } = useChat({
  onError: (error) => {
    console.error('Stream error:', error);
    toast.error(error.message);
  }
});
```

## Advanced Patterns

### Custom Data Streaming

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),

  onChunk({ chunk }) {
    // Stream custom progress updates
    if (chunk.type === 'text-delta') {
      // Calculate progress based on tokens
      const progress = calculateProgress(chunk);
      // Custom data will be sent via data-* chunk
    }
  }
});
```

### Resumable Streams

```typescript
import { createResumableStreamContext } from 'resumable-stream';

export async function POST(req: Request) {
  const { chatId } = await req.json();

  const result = streamText({
    model: openai('gpt-4'),
    messages: convertToModelMessages(uiMessages)
  });

  return result.toUIMessageStreamResponse({
    async consumeSseStream({ stream }) {
      const streamId = generateId();
      const streamContext = createResumableStreamContext();

      // Store stream for resumption
      await streamContext.createNewResumableStream(streamId, () => stream);

      // Save stream ID to database
      await saveActiveStreamId(chatId, streamId);
    }
  });
}
```

### Backpressure Handling

The SDK automatically handles backpressure, but for custom implementations:

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),

  // Throttle chunk processing
  onChunk: throttle(async ({ chunk }) => {
    await processChunk(chunk);
  }, 100)
});
```

### Conditional Streaming

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),

  onChunk({ chunk }) {
    // Only stream certain content
    if (shouldFilterChunk(chunk)) {
      return; // Skip this chunk
    }
  }
});
```

### Custom Transform

```typescript
import { processUIMessageStream } from 'ai';

const stream = await transport.sendMessages({...});

const transformedStream = processUIMessageStream({
  stream,
  onToolCall,
  onData,
  runUpdateMessageJob: async ({ state, write }) => {
    // Custom message update logic
    customTransform(state.message);
    write();
  }
});
```

## Performance Considerations

### Throttling

```typescript
// Client-side throttling
const { messages } = useChat({
  experimental_throttle: 100 // Max one update per 100ms
});

// Server-side throttling
const result = streamText({
  model: openai('gpt-4'),
  messages,
  onChunk: throttle(processChunk, 100)
});
```

### Batch Updates

```typescript
let pendingDeltas: string[] = [];

const result = streamText({
  model: openai('gpt-4'),
  messages,
  onChunk({ chunk }) {
    if (chunk.type === 'text-delta') {
      pendingDeltas.push(chunk.delta);

      // Flush every 10 deltas or 100ms
      if (pendingDeltas.length >= 10) {
        flushDeltas();
      }
    }
  }
});
```

### Memory Management

```typescript
// Clean up old messages to prevent memory leaks
const { messages, setMessages } = useChat();

useEffect(() => {
  if (messages.length > 100) {
    setMessages(messages.slice(-50)); // Keep last 50
  }
}, [messages]);
```

## Complete Example

```typescript
// Server route
export async function POST(req: Request) {
  const { messages, chatId } = await req.json();

  const result = streamText({
    model: openai('gpt-4'),
    messages: convertToModelMessages(messages),
    tools: {
      getWeather: tool({
        description: 'Get weather',
        inputSchema: z.object({ city: z.string() }),
        async *execute({ city }) {
          yield { state: 'loading' };
          const data = await fetchWeather(city);
          yield { state: 'complete', ...data };
        }
      })
    },
    stopWhen: stepCountIs(5),
    onStepFinish({ toolCalls }) {
      console.log('Tools called:', toolCalls);
    }
  });

  return result.toUIMessageStreamResponse({
    originalMessages: messages,
    messageMetadata: ({ part }) => {
      if (part.type === 'start') {
        return { createdAt: Date.now() };
      }
    },
    onFinish: async ({ messages }) => {
      await saveChat(chatId, messages);
    }
  });
}

// Client component
function Chat() {
  const { messages, sendMessage, status } = useChat({
    experimental_throttle: 100,
    onError: (error) => toast.error(error.message),
    onFinish: ({ finishReason }) => {
      console.log('Finished:', finishReason);
    }
  });

  return (
    <div>
      {messages.map(msg => (
        <Message key={msg.id} message={msg} />
      ))}
      <ChatInput
        disabled={status !== 'ready'}
        onSubmit={sendMessage}
      />
    </div>
  );
}
```
