# Type Safety

## Critical Anti-Patterns

### 1. Missing Return Type

**Problem**: Callers don't know what to expect.

```python
# BAD
def get_user(id: int):
    return User.query.get(id)

# GOOD
def get_user(id: int) -> User | None:
    return User.query.get(id)
```

### 2. Using Any Without Justification

**Problem**: Defeats the purpose of type checking.

```python
# BAD
def process(data: Any) -> Any:
    return data

# GOOD - with justification
def process(data: Any) -> dict:  # Any: accepts JSON from external API
    return json.loads(data)

# BETTER - use proper types
def process(data: str | bytes) -> dict:
    return json.loads(data)
```

### 3. Optional vs Union Syntax

**Problem**: Inconsistent syntax, less readable.

```python
# OLD (pre-3.10)
from typing import Optional, Union
def find(id: int) -> Optional[User]: ...
def parse(val: Union[str, int]) -> str: ...

# GOOD (3.10+)
def find(id: int) -> User | None: ...
def parse(val: str | int) -> str: ...
```

### 4. Missing Generic Types

**Problem**: Loses type information in collections.

```python
# BAD
def get_items() -> list:
    return [Item(...)]

# GOOD
def get_items() -> list[Item]:
    return [Item(...)]

# BAD
def get_config() -> dict:
    return {"key": "value"}

# GOOD
def get_config() -> dict[str, str]:
    return {"key": "value"}
```

### 5. TypedDict for Structured Dicts

**Problem**: Plain dict loses key/value type information.

```python
# BAD
def get_user_data() -> dict:
    return {"name": "Alice", "age": 30}

# GOOD
from typing import TypedDict

class UserData(TypedDict):
    name: str
    age: int

def get_user_data() -> UserData:
    return {"name": "Alice", "age": 30}
```

## Review Questions

1. Are all function parameters typed?
2. Are all return types specified?
3. Is `Any` used only when necessary with a comment?
4. Are collection types generic (`list[T]`, `dict[K, V]`)?
5. Is `T | None` used instead of `Optional[T]`?
