# Style Criteria

Detailed detection criteria for verbose LLM-style patterns that reduce code clarity.

## 1. Obvious Comments

### What to Look For

Comments that restate what the code clearly expresses.

### Detection Patterns

**Restating the Operation**:
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

**Describing Simple Control Flow**:
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

**Docstrings That Repeat the Name**:
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

**Loop Comments**:
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

---

## 2. Over-Documentation

### What to Look For

Excessive documentation on code that doesn't need it.

### Detection Patterns

**Full Docstrings on Trivial Functions**:
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

**Parameter Descriptions for Obvious Args**:
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

**Return Value Docs for Obvious Returns**:
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

---

## 3. Defensive Overkill

### What to Look For

Unnecessary defensive programming that can't actually prevent failures.

### Detection Patterns

**Try/Except Around Non-Failing Code**:
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

**Null Checks on Non-Nullable Values**:
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

**Type Checks After Type Hints**:
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

**Re-Validating Already-Validated Input**:
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

---

## 4. Unnecessary Type Hints

### What to Look For

Type hints that add no information value.

### Detection Patterns

**Type Hints on Obvious Literals**:
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

**Redundant Hints on Clear Context**:
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

**Over-Annotated Internal Variables**:
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

### When Type Hints Add Value

- Function parameters and return types
- Class attributes (especially in dataclasses)
- Variables where type isn't obvious from assignment
- Collection types where element type matters
- Optional/Union types

---

## Review Questions

1. Does this comment tell me something the code doesn't?
2. Would a new developer need this docstring?
3. Can this exception actually be raised?
4. Is this null check protecting against a real possibility?
5. Would the code be equally clear without this type hint?
