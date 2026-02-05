# Atom Exhaustion

## The Problem

Atoms are never garbage collected. The VM has a limit (default ~1M atoms). Creating atoms from user input can crash the system.

```elixir
# VULNERABILITY - DoS via atom exhaustion
def process_field(field_name) do
  key = String.to_atom(field_name)  # Each unique input creates new atom
  Map.get(data, key)
end

# Attacker sends: field_1, field_2, ... field_1000000 -> VM crash
```

## Dangerous Functions

```elixir
# NEVER use on external input:
String.to_atom(user_input)
List.to_atom(user_input)
:erlang.binary_to_atom(user_input, :utf8)
:erlang.list_to_atom(user_input)
```

## Safe Alternatives

### String.to_existing_atom

```elixir
# Only converts to atoms that already exist
def process_field(field_name) do
  try do
    key = String.to_existing_atom(field_name)
    Map.get(data, key)
  rescue
    ArgumentError -> {:error, :invalid_field}
  end
end
```

### Whitelist Approach

```elixir
@valid_fields ~w(name email phone)a

def process_field(field_name) do
  atom = String.to_existing_atom(field_name)

  if atom in @valid_fields do
    {:ok, Map.get(data, atom)}
  else
    {:error, :invalid_field}
  end
rescue
  ArgumentError -> {:error, :invalid_field}
end
```

### Use Strings as Keys

```elixir
# SAFE - no atom creation
def process_json(json_map) do
  # JSON keys are already strings
  name = Map.get(json_map, "name")
  email = Map.get(json_map, "email")
  %{name: name, email: email}
end
```

### Atom Whitelist in Module Attribute

```elixir
defmodule API do
  @allowed_actions [:create, :read, :update, :delete]

  def dispatch(action_string) do
    action = String.to_existing_atom(action_string)

    if action in @allowed_actions do
      perform(action)
    else
      {:error, :unauthorized_action}
    end
  rescue
    ArgumentError -> {:error, :invalid_action}
  end
end
```

## Safe Contexts

Atom creation is safe when:
- Input is compile-time constant
- Input comes from trusted internal source
- Input is validated against whitelist first

```elixir
# SAFE - compile-time
@fields [:name, :email]

# SAFE - internal message
def handle_info({:internal, action}, state) when is_atom(action) do
  # action is already an atom from trusted code
end
```

## Review Questions

1. Is String.to_atom used on any external input?
2. Is there a whitelist for dynamic atom conversion?
3. Could String.to_existing_atom be used instead?
4. Would using strings as keys work instead?
