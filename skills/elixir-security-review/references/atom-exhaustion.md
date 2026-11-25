# Atom Exhaustion

## The Problem

Atoms are never garbage collected. The Erlang VM has a fixed atom table limit (default ~1,048,576 atoms). Creating atoms from external input lets an attacker crash the node.

```elixir
# VULNERABILITY - DoS via atom exhaustion
def process_field(field_name) do
  key = String.to_atom(field_name)  # Each unique input creates new atom
  Map.get(data, key)
end
```

## Dangerous Functions and Syntax

```elixir
# NEVER use on external/untrusted input:
String.to_atom(user_input)
List.to_atom(user_input)
:erlang.binary_to_atom(user_input, :utf8)
:erlang.list_to_atom(user_input)
Module.concat([MyApp, user_input])       # Creates new module atoms!
:"prefix_#{user_input}"                  # Dynamic atom interpolation creates new atoms!
~w[#{user_input}]a                       # Sigil with 'a' modifier creates atoms!
```

## Safe Alternatives

### `String.to_existing_atom/1` and `Module.safe_concat/1,2`

```elixir
# Only converts to atoms that already exist
def process_field(field_name) do
  key = String.to_existing_atom(field_name)
  {:ok, Map.get(data, key)}
rescue
  ArgumentError -> {:error, :invalid_field}
end

# Safe dynamic module lookup (prefer an explicit map allowlist; see code-injection.md)
def resolve_plugin(name) do
  Module.safe_concat([MyApp, Plugins, name])
rescue
  ArgumentError -> {:error, :unknown_plugin}
end
```

### Explicit Allowlist Approach

```elixir
@valid_fields %{
  "name" => :name,
  "email" => :email,
  "phone" => :phone
}

def process_field(data, field_name) do
  case Map.fetch(@valid_fields, field_name) do
    {:ok, atom} -> {:ok, Map.get(data, atom)}
    :error -> {:error, :invalid_field}
  end
end
```

### Use Strings as Keys

```elixir
# SAFE - no atom creation
def process_json(json_map) do
  name = Map.get(json_map, "name")
  email = Map.get(json_map, "email")
  %{name: name, email: email}
end
```

## Safe Contexts

Atom creation is safe when:
- Input is a compile-time constant
- Input comes from a trusted internal source with bounded cardinality
- Input is validated against an explicit allowlist map first

```elixir
# SAFE - compile-time
@fields [:name, :email]

# SAFE - internal message
def handle_info({:internal, action}, state) when is_atom(action) do
  {:noreply, handle_action(action, state)}
end
```

## Review Questions

1. Are `String.to_atom/1`, `Module.concat/1,2`, or dynamic `:"...#{x}"` / `~w[...]a` used on external input?
2. Is there an explicit map/allowlist for dynamic atom or module resolution?
3. Could string keys be used instead of converting JSON/params keys to atoms?
