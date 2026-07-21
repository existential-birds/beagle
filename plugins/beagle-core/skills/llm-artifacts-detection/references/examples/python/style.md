# Style — Python examples

Worked examples for [../../style-criteria.md](../../style-criteria.md). Load only when reviewing Python. The criteria file is the authority; these illustrate it — including its "before flagging" caveats, which apply to every example here.

## 1. Obvious Comments

**Restating the operation**:
```python
# BAD - Comment restates code
counter += 1  # increment counter
items.append(item)  # add item to list
return result  # return the result
user = None  # set user to None

# GOOD - No comment needed, code is clear
counter += 1
items.append(item)
return result
user = None
```

**Describing simple control flow**:
```python
# BAD - Obvious conditionals
# check if user exists
if user:
    # process the user
    process(user)
else:
    # handle missing user
    handle_error()

# GOOD - Code is self-documenting
if user:
    process(user)
else:
    handle_error()
```

**Docstrings that repeat the name**:
```python
# BAD - Docstring restates function name
def get_user_by_id(id: int) -> User:
    """Get a user by their ID."""
    return db.query(User).get(id)

def validate_email(email: str) -> bool:
    """Validates the email."""
    return bool(re.match(EMAIL_REGEX, email))

# GOOD - Add value or omit
def get_user_by_id(id: int) -> User:
    """Raises UserNotFound if ID doesn't exist."""
    return db.query(User).get(id)

# Or just no docstring for trivial functions
def validate_email(email: str) -> bool:
    return bool(re.match(EMAIL_REGEX, email))
```

**Loop comments**:
```python
# BAD
# iterate over users
for user in users:
    # process each user
    process(user)

# GOOD
for user in users:
    process(user)
```

## 2. Over-Documentation

**Full docstrings on trivial functions**:
```python
# BAD - Overkill for simple getter
def get_name(self) -> str:
    """Get the name of this object.

    Returns:
        str: The name of the object.
    """
    return self._name

# GOOD - Simple is better
def get_name(self) -> str:
    return self._name
```

**Parameter descriptions for obvious args**:
```python
# BAD - Parameters are self-evident
def send_email(
    to: str,
    subject: str,
    body: str,
) -> None:
    """Send an email.

    Args:
        to: The email address to send to.
        subject: The subject of the email.
        body: The body of the email.
    """
    ...

# GOOD - Only document non-obvious aspects
def send_email(
    to: str,
    subject: str,
    body: str,
    priority: int = 3,
) -> None:
    """Send an email.

    Args:
        priority: 1-5, where 1 is highest. Affects delivery order.
    """
    ...
```

**Return value docs for obvious returns**:
```python
# BAD
def is_valid(self) -> bool:
    """Check if valid.

    Returns:
        bool: True if valid, False otherwise.
    """
    return self._valid

# GOOD - Return is obvious from type hint
def is_valid(self) -> bool:
    return self._valid
```

**Python caveat:** if the project runs `pydocstyle`, `ruff`'s `D` rules, or generates Sphinx API docs from these docstrings, full parameter and return sections may be required. Check `pyproject.toml` first.

## 3. Defensive Overkill

**Try/except around non-failing code**:
```python
# BAD - These operations can't fail
try:
    x = 1 + 1
except Exception:
    x = 0

try:
    result = {"key": "value"}
except Exception:
    result = {}

# BAD - Already validated input
def process(data: ValidatedData):
    try:
        # ValidatedData guarantees these exist
        name = data.name
        email = data.email
    except AttributeError:
        raise ValueError("Invalid data")  # Can't happen!
```

**Null checks on non-nullable values**:
```python
# BAD - Type hint says it's not None
def process(user: User) -> str:
    if user is None:  # Can't be None per type hint!
        raise ValueError("User required")
    return user.name

# BAD - Just assigned, can't be None
config = load_config()
if config is None:  # load_config() never returns None
    config = {}
```

**Type checks after type hints**:
```python
# BAD - Type is already guaranteed
def process(items: list[str]) -> None:
    if not isinstance(items, list):  # Already typed!
        raise TypeError("Expected list")
    for item in items:
        if not isinstance(item, str):  # Already typed!
            raise TypeError("Expected str")
        print(item)
```

**Re-validating already-validated input**:
```python
# BAD - Pydantic already validated
class Request(BaseModel):
    email: EmailStr
    age: int = Field(ge=0, le=150)

def handle(request: Request):
    # Pydantic already validated these!
    if not is_valid_email(request.email):
        raise ValueError("Invalid email")
    if request.age < 0 or request.age > 150:
        raise ValueError("Invalid age")
```

**Python caveat — the big one:** Python type hints are **not enforced at runtime**. A `None` check on a parameter annotated `User` is correct defensive code when the caller is untrusted — a request handler, a deserializer, a plugin entry point, an FFI boundary. Confirm the value does not cross a trust boundary before flagging. The Pydantic example above is safe to flag precisely because Pydantic *does* enforce at runtime.

## 4. Unnecessary Type Hints

**Type hints on obvious literals**:
```python
# BAD - Type is obvious from value
name: str = "Alice"
count: int = 0
enabled: bool = True
items: list = []

# GOOD - Let inference work
name = "Alice"
count = 0
enabled = True
items: list[str] = []  # Only hint if element type matters
```

**Redundant hints in clear context**:
```python
# BAD - Context makes type obvious
user: User = User(name="Alice")
result: dict = json.loads(data)  # json.loads returns dict
items: list = list(range(10))

# GOOD
user = User(name="Alice")
result = json.loads(data)
items = list(range(10))
```

**Over-annotated internal variables**:
```python
# BAD - Too many internal annotations
def process(data: str) -> dict:
    lines: list[str] = data.split("\n")
    result: dict[str, int] = {}
    count: int = 0
    for line in lines:
        key: str = line.strip()
        result[key] = count
        count += 1
    return result

# GOOD - Annotate function signature, not internals
def process(data: str) -> dict[str, int]:
    lines = data.split("\n")
    result = {}
    for count, line in enumerate(lines):
        result[line.strip()] = count
    return result
```

**Python caveat:** an empty collection literal often *needs* its annotation for mypy to infer an element type — `items: list[str] = []` is not redundant. Check whether the project runs mypy in strict mode before flagging a local annotation.
