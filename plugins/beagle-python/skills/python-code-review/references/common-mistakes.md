# Common Mistakes

## Critical Anti-Patterns

### 1. Mutable Default Arguments

**Problem**: Default value is shared across all calls.

```python
# BAD - same list reused!
def add_item(item, items=[]):
    items.append(item)
    return items

add_item("a")  # ["a"]
add_item("b")  # ["a", "b"] - unexpected!

# GOOD
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items

# BETTER - using dataclass
from dataclasses import dataclass, field

@dataclass
class Container:
    items: list = field(default_factory=list)
```

### 2. Using print() for Logging

**Problem**: No log levels, no timestamps, hard to filter.

```python
# BAD
print(f"Processing {item}")
print(f"Error: {e}")

# GOOD
from loguru import logger

logger.info(f"Processing {item}")
logger.error(f"Error: {e}")
```

### 3. String Formatting Inconsistency

**Problem**: Mixing formats reduces readability.

```python
# BAD - mixed formats
msg = "Hello %s" % name
msg = "Hello {}".format(name)
msg = f"Hello {name}"

# GOOD - f-strings consistently
msg = f"Hello {name}"
total = f"Count: {count:,}"  # with formatting
path = f"{base}/{sub}/{file}"
```

### 4. Unused Variables

**Problem**: Dead code, confusing to readers.

```python
# BAD
result = process()  # never used

# GOOD - use underscore for intentionally ignored
_, second, _ = get_triple()

# Or just don't assign
process()  # if result not needed
```

### 5. Import Order

**Problem**: Hard to scan, may cause issues.

```python
# BAD - random order
from myapp.utils import helper
import os
from typing import Optional
import sys
from myapp.models import User

# GOOD - standard order
import os
import sys
from typing import Optional

from myapp.models import User
from myapp.utils import helper
```

### 6. Magic Numbers

**Problem**: Unclear intent, hard to maintain.

```python
# BAD
if len(items) > 100:
    paginate()
time.sleep(3600)

# GOOD
MAX_PAGE_SIZE = 100
CACHE_TTL_SECONDS = 3600

if len(items) > MAX_PAGE_SIZE:
    paginate()
time.sleep(CACHE_TTL_SECONDS)
```

### 7. Nested Conditionals

**Problem**: Hard to read and maintain.

```python
# BAD
def process(user):
    if user:
        if user.active:
            if user.verified:
                return do_work(user)
    return None

# GOOD - early returns
def process(user):
    if not user:
        return None
    if not user.active:
        return None
    if not user.verified:
        return None
    return do_work(user)
```

## Review Questions

1. Are there any mutable default arguments (list, dict, set)?
2. Is `print()` used instead of `logger`?
3. Are f-strings used consistently?
4. Are there magic numbers that should be constants?
5. Are deeply nested conditionals flattened with early returns?
