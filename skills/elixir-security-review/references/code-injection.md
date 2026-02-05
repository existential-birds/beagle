# Code Injection

## Code.eval_string

### The Danger

```elixir
# CRITICAL VULNERABILITY
def calculate(user_expression) do
  {result, _} = Code.eval_string(user_expression)
  result
end

# Attacker input: "System.cmd(\"rm\", [\"-rf\", \"/\"])"
```

### Safe Alternatives

**1. Parse and validate expressions:**

```elixir
# Safe math expression parser
defmodule SafeMath do
  def evaluate(expr) when is_binary(expr) do
    with {:ok, tokens} <- tokenize(expr),
         {:ok, ast} <- parse(tokens),
         :ok <- validate_ast(ast) do
      {:ok, eval_ast(ast)}
    end
  end

  defp validate_ast({op, _, _}) when op in [:+, :-, :*, :/], do: :ok
  defp validate_ast(n) when is_number(n), do: :ok
  defp validate_ast(_), do: {:error, :invalid_expression}
end
```

**2. Whitelist allowed operations:**

```elixir
@allowed_ops %{
  "add" => &Kernel.+/2,
  "subtract" => &Kernel.-/2,
  "multiply" => &Kernel.*/2
}

def calculate(op, a, b) when is_map_key(@allowed_ops, op) do
  @allowed_ops[op].(a, b)
end
```

## :erlang.binary_to_term

### The Danger

```elixir
# CRITICAL VULNERABILITY
def deserialize(data) do
  :erlang.binary_to_term(data)  # Can create atoms and function references; dangerous if later invoked
end
```

Malicious binary can:
- Create unlimited atoms (DoS)
- Reference functions that get called
- Contain malicious data structures

### Safe Alternative

```elixir
# SAFE - only allows existing atoms, no function references
def deserialize(data) do
  :erlang.binary_to_term(data, [:safe])
rescue
  ArgumentError -> {:error, :invalid_term}
end
```

**Note:** The `[:safe]` option does NOT prevent DoS from:
- Huge terms consuming memory
- Deeply nested structures causing stack overflow
- Decompression bombs (compressed binaries expand to massive size)

**Mitigations:**
- Enforce input size limits before decoding
- Use `[:safe, :used]` for stream parsing to detect unconsumed bytes
- Consider timeout wrappers for untrusted input

### Prefer JSON for External Data

```elixir
# External API data - use JSON
def parse_api_response(body) do
  Jason.decode(body)
end

# Internal Erlang-to-Erlang - binary_to_term with :safe may be ok
def parse_internal_message(data) do
  :erlang.binary_to_term(data, [:safe])
end
```

## Dynamic Module Creation

### The Danger

```elixir
# DANGEROUS
def load_handler(module_name) do
  module = String.to_existing_atom("Elixir.Handlers.#{module_name}")
  module.handle()
end

# Attacker: "../../System" -> calls System.handle() if exists
```

### Safe Pattern

```elixir
@handlers %{
  "email" => Handlers.Email,
  "sms" => Handlers.SMS
}

def load_handler(name) do
  case Map.fetch(@handlers, name) do
    {:ok, module} -> module.handle()
    :error -> {:error, :unknown_handler}
  end
end
```

## Review Questions

1. Is Code.eval_string used on any external input?
2. Is binary_to_term used without :safe option?
3. Are modules loaded dynamically from user input?
4. Is there a whitelist for dynamic operations?
