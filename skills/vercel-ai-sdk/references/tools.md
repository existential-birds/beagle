# Tools Reference

Complete reference for tool definition and execution in the Vercel AI SDK.

## Table of Contents

- [Tool Definition](#tool-definition)
- [Server-Side Tools](#server-side-tools)
- [Client-Side Tools](#client-side-tools)
- [Tool State Machine](#tool-state-machine)
- [Tool Approval Flow](#tool-approval-flow)
- [Rendering Tool States](#rendering-tool-states)
- [Type Safety](#type-safety)
- [Advanced Patterns](#advanced-patterns)

## Tool Definition

### Basic Tool

```typescript
import { tool } from 'ai';
import { z } from 'zod';

const getWeatherTool = tool({
  // Description for the AI model
  description: 'Get current weather for a city',

  // Input schema using Zod
  inputSchema: z.object({
    city: z.string().describe('The city name'),
    units: z.enum(['celsius', 'fahrenheit']).optional()
  }),

  // Optional output schema
  outputSchema: z.object({
    temperature: z.number(),
    weather: z.string(),
    humidity: z.number()
  }),

  // Execution function (server-side only)
  execute: async ({ city, units = 'celsius' }) => {
    const data = await fetchWeather(city);
    return {
      temperature: convertTemp(data.temp, units),
      weather: data.conditions,
      humidity: data.humidity
    };
  }
});
```

### Tool Without Execute (Client-Side)

```typescript
const askConfirmationTool = tool({
  description: 'Ask the user for confirmation',
  inputSchema: z.object({
    message: z.string()
  }),
  outputSchema: z.string()
  // No execute function - handled on client
});
```

## Server-Side Tools

Tools with `execute` functions run on the server during streaming.

### Simple Execution

```typescript
const searchTool = tool({
  description: 'Search the web',
  inputSchema: z.object({
    query: z.string()
  }),
  async execute({ query }) {
    const results = await searchWeb(query);
    return {
      results: results.slice(0, 5),
      count: results.length
    };
  }
});
```

### Streaming Tool Outputs

Use generator functions to stream intermediate results:

```typescript
const analysisTool = tool({
  description: 'Analyze data',
  inputSchema: z.object({
    data: z.array(z.number())
  }),

  async *execute({ data }) {
    // Yield preliminary status
    yield { state: 'processing', progress: 0 };

    // Perform analysis in stages
    const mean = calculateMean(data);
    yield { state: 'processing', progress: 33, mean };

    const median = calculateMedian(data);
    yield { state: 'processing', progress: 66, mean, median };

    const stdDev = calculateStdDev(data);

    // Yield final result
    yield {
      state: 'complete',
      progress: 100,
      mean,
      median,
      stdDev
    };
  }
});
```

### Tool Callbacks

```typescript
const verboseTool = tool({
  description: 'Tool with callbacks',
  inputSchema: z.object({ query: z.string() }),

  // Called when input streaming starts
  onInputStart: () => {
    console.log('Tool input starting');
  },

  // Called on each input delta (for large inputs)
  onInputDelta: ({ inputTextDelta }) => {
    console.log('Input delta:', inputTextDelta);
  },

  // Called when input is complete
  onInputAvailable: ({ input }) => {
    console.log('Input available:', input);
  },

  async execute({ query }) {
    return await search(query);
  }
});
```

### Error Handling

```typescript
const fallibleTool = tool({
  description: 'Tool that might fail',
  inputSchema: z.object({ id: z.string() }),

  async execute({ id }) {
    try {
      const data = await fetchData(id);
      if (!data) {
        throw new Error('Data not found');
      }
      return data;
    } catch (error) {
      // Error is automatically sent as tool-output-error chunk
      throw new Error(`Failed to fetch data: ${error.message}`);
    }
  }
});
```

### Multi-Step Tools

Tools can trigger additional model calls:

```typescript
import { streamText, stepCountIs } from 'ai';

const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),

  tools: {
    search: searchTool,
    analyze: analyzeTool,
    summarize: summarizeTool
  },

  // Allow up to 5 steps (model can call tools multiple times)
  stopWhen: stepCountIs(5),

  onStepFinish({ toolCalls, toolResults }) {
    console.log('Step finished');
    console.log('Called:', toolCalls.map(t => t.toolName));
    console.log('Results:', toolResults);
  }
});
```

## Client-Side Tools

Tools without `execute` are handled on the client via `onToolCall` and `addToolOutput`.

### Automatic Execution

```typescript
const { addToolOutput } = useChat({
  onToolCall: async ({ toolCall }) => {
    if (toolCall.toolName === 'getLocation') {
      try {
        const location = await getCurrentLocation();
        addToolOutput({
          tool: 'getLocation',
          toolCallId: toolCall.toolCallId,
          output: location
        });
      } catch (error) {
        addToolOutput({
          state: 'output-error',
          tool: 'getLocation',
          toolCallId: toolCall.toolCallId,
          errorText: error.message
        });
      }
    }
  }
});
```

### User Interaction

For tools that require user input, handle them in the render phase:

```typescript
function Message({ message, addToolOutput }) {
  return (
    <div>
      {message.parts.map(part => {
        if (part.type === 'tool-askConfirmation') {
          if (part.state === 'input-available') {
            return (
              <div>
                <p>{part.input.message}</p>
                <button
                  onClick={() =>
                    addToolOutput({
                      tool: 'askConfirmation',
                      toolCallId: part.toolCallId,
                      output: 'Yes, confirmed'
                    })
                  }
                >
                  Confirm
                </button>
                <button
                  onClick={() =>
                    addToolOutput({
                      state: 'output-error',
                      tool: 'askConfirmation',
                      toolCallId: part.toolCallId,
                      errorText: 'User declined'
                    })
                  }
                >
                  Cancel
                </button>
              </div>
            );
          }

          if (part.state === 'output-available') {
            return <div>User confirmed: {part.output}</div>;
          }
        }
      })}
    </div>
  );
}
```

### Automatic Resending

```typescript
import { lastAssistantMessageIsCompleteWithToolCalls } from 'ai';

const { messages } = useChat({
  // Automatically resend when all tool outputs are available
  sendAutomaticallyWhen: lastAssistantMessageIsCompleteWithToolCalls,

  onToolCall: async ({ toolCall }) => {
    // Execute client-side tools
    // Message will automatically be resent when all tools complete
  }
});
```

## Tool State Machine

Tool parts progress through states:

### State Flow

```
1. input-streaming (optional)
   ↓
2. input-available
   ↓
3a. [No approval needed] → output-available
   OR
3b. approval-requested → approval-responded → output-available/output-denied
   OR
   (at any point) → output-error
```

### State Definitions

```typescript
type ToolState =
  | 'input-streaming'     // Tool input streaming (large inputs)
  | 'input-available'     // Tool input complete
  | 'approval-requested'  // Waiting for user approval
  | 'approval-responded'  // User responded (approved/denied)
  | 'output-available'    // Tool execution complete
  | 'output-error'        // Tool execution failed
  | 'output-denied';      // User denied approval
```

### State Properties

```typescript
// input-streaming
{
  state: 'input-streaming',
  input: Partial<ToolInput> | undefined // Partial input while streaming
}

// input-available
{
  state: 'input-available',
  input: ToolInput, // Complete input
  callProviderMetadata?: ProviderMetadata
}

// approval-requested
{
  state: 'approval-requested',
  input: ToolInput,
  approval: {
    id: string // Approval ID for response
  }
}

// approval-responded
{
  state: 'approval-responded',
  input: ToolInput,
  approval: {
    id: string,
    approved: boolean,
    reason?: string
  }
}

// output-available
{
  state: 'output-available',
  input: ToolInput,
  output: ToolOutput,
  preliminary?: boolean, // True for intermediate streaming outputs
  approval?: {
    id: string,
    approved: true,
    reason?: string
  }
}

// output-error
{
  state: 'output-error',
  input: ToolInput | undefined,
  errorText: string,
  approval?: { ... } // If error after approval
}

// output-denied
{
  state: 'output-denied',
  input: ToolInput,
  approval: {
    id: string,
    approved: false,
    reason?: string
  }
}
```

## Tool Approval Flow

### Defining Approval Requirements

```typescript
const deleteTool = tool({
  description: 'Delete a file',
  inputSchema: z.object({
    filename: z.string()
  }),

  // Request approval before execution
  requiresApproval: true,

  async execute({ filename }) {
    await deleteFile(filename);
    return { deleted: filename };
  }
});
```

### Handling Approval Requests

```typescript
function ToolApproval({ part, addToolApprovalResponse }) {
  if (part.type === 'tool-deleteFile' && part.state === 'approval-requested') {
    return (
      <div>
        <p>Delete {part.input.filename}?</p>
        <button
          onClick={() =>
            addToolApprovalResponse({
              id: part.approval.id,
              approved: true,
              reason: 'User confirmed deletion'
            })
          }
        >
          Approve
        </button>
        <button
          onClick={() =>
            addToolApprovalResponse({
              id: part.approval.id,
              approved: false,
              reason: 'User cancelled'
            })
          }
        >
          Deny
        </button>
      </div>
    );
  }
}
```

### Automatic Resending After Approval

```typescript
const { addToolApprovalResponse } = useChat({
  sendAutomaticallyWhen: ({ messages }) => {
    const lastMsg = messages[messages.length - 1];
    return lastMsg.parts.every(part => {
      if (part.type.startsWith('tool-')) {
        // Resend when all tools are either:
        // - output-available
        // - output-error
        // - output-denied
        // - approval-responded (waiting for backend)
        return ['output-available', 'output-error', 'output-denied', 'approval-responded']
          .includes(part.state);
      }
      return true;
    });
  }
});
```

## Rendering Tool States

### Complete Tool Renderer

```typescript
function ToolPart({ part, addToolOutput, addToolApprovalResponse }) {
  // Type guard
  if (!part.type.startsWith('tool-')) return null;

  const toolName = part.type.replace('tool-', '');

  switch (part.state) {
    case 'input-streaming':
      return (
        <div className="tool-streaming">
          <Spinner />
          <span>Preparing {toolName}...</span>
          <pre>{JSON.stringify(part.input, null, 2)}</pre>
        </div>
      );

    case 'input-available':
      return (
        <div className="tool-executing">
          <Spinner />
          <span>Executing {toolName}...</span>
          {part.title && <h4>{part.title}</h4>}
        </div>
      );

    case 'approval-requested':
      return (
        <div className="tool-approval">
          <h4>Approval Required</h4>
          <p>Allow {toolName}?</p>
          <div className="tool-input">
            <pre>{JSON.stringify(part.input, null, 2)}</pre>
          </div>
          <button
            onClick={() =>
              addToolApprovalResponse({
                id: part.approval.id,
                approved: true
              })
            }
          >
            Approve
          </button>
          <button
            onClick={() =>
              addToolApprovalResponse({
                id: part.approval.id,
                approved: false,
                reason: 'User declined'
              })
            }
          >
            Deny
          </button>
        </div>
      );

    case 'approval-responded':
      return (
        <div className="tool-approval-responded">
          {part.approval.approved ? (
            <span>✓ Approved, executing...</span>
          ) : (
            <span>✗ Denied: {part.approval.reason}</span>
          )}
        </div>
      );

    case 'output-available':
      return (
        <div className="tool-output">
          <h4>{toolName} Result</h4>
          {part.preliminary && <Badge>Preliminary</Badge>}
          <ToolOutput toolName={toolName} output={part.output} />
        </div>
      );

    case 'output-error':
      return (
        <div className="tool-error">
          <h4>{toolName} Error</h4>
          <p className="error">{part.errorText}</p>
          {part.input && (
            <details>
              <summary>Input</summary>
              <pre>{JSON.stringify(part.input, null, 2)}</pre>
            </details>
          )}
        </div>
      );

    case 'output-denied':
      return (
        <div className="tool-denied">
          <span>✗ Tool execution denied</span>
          {part.approval.reason && <p>{part.approval.reason}</p>}
        </div>
      );

    default:
      return null;
  }
}
```

### Tool-Specific Renderers

```typescript
function WeatherToolOutput({ part }) {
  if (part.type !== 'tool-getWeather') return null;

  if (part.state === 'output-available') {
    const { weather, temperature } = part.output;
    return (
      <div className="weather-card">
        <WeatherIcon condition={weather} />
        <span>{temperature}°F</span>
        <span>{weather}</span>
      </div>
    );
  }

  if (part.state === 'input-available') {
    return <div>Fetching weather for {part.input.city}...</div>;
  }

  return null;
}
```

## Type Safety

### Typed Tools

```typescript
const tools = {
  getWeather: tool({
    inputSchema: z.object({ city: z.string() }),
    execute: async ({ city }) => ({ temp: 72, weather: 'sunny' })
  }),
  searchWeb: tool({
    inputSchema: z.object({ query: z.string() }),
    execute: async ({ query }) => ({ results: [] })
  })
} as const;

// Infer tool types
type MyTools = InferUITools<typeof tools>;
// {
//   getWeather: { input: { city: string }; output: { temp: number; weather: string } }
//   searchWeb: { input: { query: string }; output: { results: any[] } }
// }

// Use in message type
type MyMessage = UIMessage<unknown, UIDataTypes, MyTools>;
```

### Type-Safe Tool Rendering

```typescript
function renderToolPart(part: InferUIMessagePart<MyMessage>) {
  // TypeScript knows the exact tool types
  if (part.type === 'tool-getWeather') {
    if (part.state === 'output-available') {
      // part.output is typed as { temp: number; weather: string }
      return <div>{part.output.weather}: {part.output.temp}°F</div>;
    }
  }

  if (part.type === 'tool-searchWeb') {
    if (part.state === 'output-available') {
      // part.output is typed as { results: any[] }
      return <SearchResults results={part.output.results} />;
    }
  }
}
```

### Type-Safe addToolOutput

```typescript
const { addToolOutput } = useChat<MyMessage>();

// TypeScript enforces correct tool name and output type
addToolOutput({
  tool: 'getWeather', // Must be a key in MyTools
  toolCallId: 'call-123',
  output: { temp: 72, weather: 'sunny' } // Must match getWeather output type
});

// Error: Type '"invalid"' is not assignable to type '"getWeather" | "searchWeb"'
addToolOutput({
  tool: 'invalid',
  toolCallId: 'call-123',
  output: {}
});
```

## Advanced Patterns

### Conditional Tool Availability

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages: convertToModelMessages(uiMessages),
  tools: user.isPremium
    ? { search: searchTool, analyze: analyzeTool }
    : { search: searchTool }
});
```

### Tool Chaining

```typescript
const tools = {
  search: tool({
    description: 'Search for information',
    inputSchema: z.object({ query: z.string() }),
    async execute({ query }) {
      return await searchWeb(query);
    }
  }),
  analyze: tool({
    description: 'Analyze search results',
    inputSchema: z.object({ results: z.array(z.any()) }),
    async execute({ results }) {
      return await analyzeResults(results);
    }
  })
};

const result = streamText({
  model: openai('gpt-4'),
  messages,
  tools,
  stopWhen: stepCountIs(5) // Allow chaining
});
```

### Parallel Tool Execution

The AI model can invoke multiple tools in parallel:

```typescript
const result = streamText({
  model: openai('gpt-4'),
  messages,
  tools: {
    getWeather: weatherTool,
    getNews: newsTool,
    getStocks: stocksTool
  },
  maxToolRoundtrips: 1 // One round with multiple parallel tools
});
```

### Tool Metadata

```typescript
const enrichedTool = tool({
  description: 'Search with metadata',
  inputSchema: z.object({ query: z.string() }),

  async execute({ query }, { messages, abortSignal }) {
    // Access message history
    const context = extractContext(messages);

    // Support cancellation
    const results = await searchWithAbort(query, abortSignal);

    return {
      results,
      metadata: {
        searchTime: Date.now(),
        contextUsed: context
      }
    };
  }
});
```

### Custom Tool Validation

```typescript
const validatedTool = tool({
  description: 'Tool with validation',
  inputSchema: z.object({
    amount: z.number().min(0).max(1000)
  }),

  async execute({ amount }) {
    // Additional runtime validation
    if (amount > 500) {
      throw new Error('Amount requires additional approval');
    }

    return await processPayment(amount);
  }
});
```

## Complete Example

```typescript
// Server route
const tools = {
  // Server-side tool
  getWeather: tool({
    description: 'Get weather for a city',
    inputSchema: z.object({ city: z.string() }),
    async *execute({ city }) {
      yield { state: 'loading' };
      const data = await fetchWeather(city);
      yield { state: 'complete', ...data };
    }
  }),

  // Client-side tool with approval
  getLocation: tool({
    description: 'Get user location (requires permission)',
    inputSchema: z.object({}),
    outputSchema: z.string(),
    requiresApproval: true
  })
};

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4'),
    messages: convertToModelMessages(messages),
    tools
  });

  return result.toUIMessageStreamResponse();
}

// Client component
type MyMessage = UIMessage<unknown, UIDataTypes, InferUITools<typeof tools>>;

function Chat() {
  const { messages, addToolOutput, addToolApprovalResponse } = useChat<MyMessage>({
    // Handle client-side tool automatically
    onToolCall: async ({ toolCall }) => {
      if (toolCall.toolName === 'getLocation') {
        const location = await getCurrentLocation();
        addToolOutput({
          tool: 'getLocation',
          toolCallId: toolCall.toolCallId,
          output: location
        });
      }
    },

    // Resend when all tools complete
    sendAutomaticallyWhen: lastAssistantMessageIsCompleteWithToolCalls
  });

  return (
    <div>
      {messages.map(msg => (
        <div key={msg.id}>
          {msg.parts.map((part, i) => (
            <ToolPart
              key={i}
              part={part}
              addToolOutput={addToolOutput}
              addToolApprovalResponse={addToolApprovalResponse}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
```
