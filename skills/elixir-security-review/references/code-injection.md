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

## Deserialization (`binary_to_term` vs `Plug.Crypto` vs JSON)

### The Danger

```elixir
# CRITICAL VULNERABILITY
def deserialize(data) do
  :erlang.binary_to_term(data)  # Can create atoms and deserialize executable funs!
end
```

Even `:erlang.binary_to_term(data, [:safe])` only prevents creating **new** atoms — per the Erlang Ecosystem Foundation Security WG, it still allows deserializing function references to existing modules (e.g. `&System.cmd/2`).

### Safe Alternatives

For untrusted Erlang External Term Format (ETF) binaries, use `Plug.Crypto.non_executable_binary_to_term/2` with `[:safe]`:

```elixir
# SAFE for untrusted ETF payloads - blocks new atoms AND executable funs/pids/ports/refs
def deserialize(data) do
  {:ok, Plug.Crypto.non_executable_binary_to_term(data, [:safe])}
rescue
  ArgumentError -> {:error, :invalid_term}
end
```

### Prefer JSON for External Data

```elixir
# External API data - use JSON (built-in JSON in Elixir 1.18+, or Jason)
def parse_api_response(body) do
  JSON.decode(body)
end
```

## Dynamic Module Dispatch

### The Danger

```elixir
# DANGEROUS - allows calling any loaded module that happens to export handle/0
# (e.g., if module_name resolves to an unintended existing atom/module)
def load_handler(module_name) do
  module = String.to_existing_atom("Elixir.Handlers.#{module_name}")
  module.handle()
end
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

## Ecto `fragment/1` SQL Injection

Ecto parameterized queries prevent SQL injection automatically, **except** when string interpolation is embedded inside `fragment/1` (or raw `Ecto.Adapters.SQL.query/3` strings):

```elixir
# CRITICAL VULNERABILITY - SQL injection via interpolation inside fragment
from u in User, where: fragment("lower(email) = '#{input}'")

# GOOD - use positional ? placeholders inside fragment
from u in User, where: fragment("lower(email) = ?", ^input)
```

## Review Questions

1. Is `Code.eval_string/1` used on any external input?
2. Is `binary_to_term` used without `[:safe]`, or on untrusted data without `Plug.Crypto.non_executable_binary_to_term(data, [:safe])`?
3. Are modules dispatched dynamically without an explicit allowlist map?
4. Does any Ecto `fragment/1` or raw SQL query interpolate user input instead of using `?` / `$1` parameters?
