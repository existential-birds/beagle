# PEP8 Style Guide

## Indentation

**Rule**: Use 4 spaces per indentation level. Never use tabs.

```python
# BAD - 2 spaces
def foo():
  return bar

# BAD - tabs (shown with → for visibility)
def foo():
→   return bar  # ← actual code would have tab here

# GOOD - 4 spaces
def foo():
    return bar
```

### Continuation Lines

```python
# GOOD - aligned with opening delimiter
result = function_name(arg_one, arg_two,
                       arg_three, arg_four)

# GOOD - hanging indent
result = function_name(
    arg_one, arg_two,
    arg_three, arg_four,
)

# BAD - no alignment
result = function_name(arg_one, arg_two,
    arg_three, arg_four)
```

## Line Length

**Rule**: Maximum 79 characters for code, 72 for docstrings/comments.

```python
# BAD - too long
result = some_function(argument_one, argument_two, argument_three, argument_four, argument_five)

# GOOD - broken across lines
result = some_function(
    argument_one,
    argument_two,
    argument_three,
    argument_four,
    argument_five,
)
```

## Blank Lines

**Rule**: Two blank lines around top-level definitions, one blank line around methods.

```python
# GOOD
import os


class MyClass:
    """Docstring."""

    def method_one(self):
        pass

    def method_two(self):
        pass


def top_level_function():
    pass


def another_function():
    pass
```

## Imports

**Rule**: Group imports in order: stdlib → third-party → local. One blank line between groups.

```python
# GOOD
import os
import sys
from pathlib import Path

import requests
from pydantic import BaseModel

from myapp.models import User
from myapp.utils import helper
```

**Rule**: Avoid wildcard imports.

```python
# BAD
from module import *

# GOOD
from module import specific_function, SpecificClass
```

## Whitespace

### Inside Brackets

```python
# BAD
spam( ham[ 1 ], { eggs: 2 } )

# GOOD
spam(ham[1], {eggs: 2})
```

### Before Colons and Commas

```python
# BAD
if x == 4 :
    print(x , y)

# GOOD
if x == 4:
    print(x, y)
```

### Around Operators

```python
# BAD
x=1
y = x+1
z = x +1

# GOOD
x = 1
y = x + 1

# Exception: indicate precedence
result = x*2 + y*3
```

### Function Arguments

```python
# BAD
def function(arg1 = None, arg2 = 0):
    pass

# GOOD
def function(arg1=None, arg2=0):
    pass
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Functions/variables | `snake_case` | `my_function`, `user_count` |
| Classes | `CamelCase` | `MyClass`, `HttpClient` |
| Constants | `UPPER_CASE` | `MAX_SIZE`, `DEFAULT_TIMEOUT` |
| Private | Leading underscore | `_internal_method` |
| "Protected" | Double underscore | `__name_mangled` |

```python
# BAD
def MyFunction():  # should be snake_case
    pass

class my_class:  # should be CamelCase
    maxSize = 100  # should be MAX_SIZE if constant

# GOOD
def my_function():
    pass

class MyClass:
    MAX_SIZE = 100
```

## Comments

### Inline Comments

**Rule**: Separate by at least two spaces. Use sparingly.

```python
# BAD
x = x + 1# increment

# GOOD
x = x + 1  # compensate for border
```

### Block Comments

```python
# GOOD - aligned with code, complete sentences
# This is a block comment explaining the
# following code section. Each sentence
# ends with a period.
result = complex_operation()
```

### Docstrings

```python
# GOOD
def fetch_users(limit: int = 100) -> list[User]:
    """Fetch users from the database.

    Args:
        limit: Maximum number of users to return.

    Returns:
        List of User objects.

    Raises:
        DatabaseError: If connection fails.
    """
    pass
```

## Review Questions

1. Is indentation consistently 4 spaces (no tabs)?
2. Are lines ≤79 characters (≤72 for docstrings)?
3. Are there two blank lines around top-level definitions?
4. Are imports grouped correctly with blank lines between groups?
5. Is there extraneous whitespace inside brackets or around operators?
6. Do names follow conventions (snake_case, CamelCase, UPPER_CASE)?
7. Are inline comments separated by at least two spaces?
