# Abstraction Criteria

Detailed detection criteria for over-engineering patterns commonly introduced by LLM coding agents.

## 1. Over-Abstraction

### What to Look For

Unnecessary abstraction layers that add complexity without providing value.

### Detection Patterns

**Wrapper Classes That Just Delegate**:
```python
# BAD - Wrapper adds nothing
class DatabaseWrapper:
    def __init__(self, db):
        self.db = db

    def query(self, sql):
        return self.db.query(sql)  # Just delegates!

    def execute(self, sql):
        return self.db.execute(sql)  # Just delegates!

# Usage
wrapper = DatabaseWrapper(actual_db)
wrapper.query(sql)  # Why not just use actual_db directly?
```

**Interfaces With Single Implementation**:
```python
# BAD - Abstract class with only one implementation
from abc import ABC, abstractmethod

class DataProcessor(ABC):
    @abstractmethod
    def process(self, data): ...

class ConcreteDataProcessor(DataProcessor):  # Only implementation!
    def process(self, data):
        return data.transform()

# No other implementations exist - why the abstraction?
```

**Protocol With One Implementer**:
```python
# BAD - Protocol nobody else implements
from typing import Protocol

class Fetcher(Protocol):
    def fetch(self, url: str) -> bytes: ...

class HttpFetcher:  # Only class implementing Fetcher
    def fetch(self, url: str) -> bytes:
        return requests.get(url).content

# The protocol adds no value if there's only one implementation
```

**Factory That Always Returns Same Type**:
```python
# BAD - Factory with no variation
def create_processor(config):
    # Always returns the same type!
    return DataProcessor(config)

# Could just be:
processor = DataProcessor(config)
```

**Unnecessary Indirection**:
```python
# BAD - Extra layers for no reason
class ServiceLocator:
    def get_user_service(self):
        return UserService()

class UserService:
    def get_user(self, id):
        return UserRepository().find(id)

class UserRepository:
    def find(self, id):
        return db.query(User).get(id)

# 3 layers when 1 would do
```

### Signs of Over-Abstraction

- Class/function just calls through to another
- Abstract class with exactly one concrete implementation
- Factory that always returns the same type
- Interface defined "for future extensibility" (YAGNI violation)
- Multiple layers that all have the same method signatures

---

## 2. Copy-Paste Drift

### What to Look For

Three or more similar code blocks that should be parameterized into a single function.

### Detection Patterns

**Nearly Identical Functions**:
```python
# BAD - Three similar functions
def process_users(users):
    results = []
    for user in users:
        validated = validate(user)
        transformed = transform(validated)
        results.append(transformed)
    return results

def process_orders(orders):
    results = []
    for order in orders:  # Same pattern!
        validated = validate(order)
        transformed = transform(validated)
        results.append(transformed)
    return results

def process_products(products):
    results = []
    for product in products:  # Same pattern!
        validated = validate(product)
        transformed = transform(validated)
        results.append(transformed)
    return results

# GOOD - Parameterized
def process_items(items):
    return [transform(validate(item)) for item in items]
```

**Repeated Patterns in Methods**:
```python
# BAD - Same error handling in multiple methods
class ApiClient:
    def get_users(self):
        try:
            response = self.session.get("/users")
            response.raise_for_status()
            return response.json()
        except RequestException as e:
            logger.error(f"Failed to get users: {e}")
            raise ApiError(f"Failed to get users: {e}")

    def get_orders(self):
        try:
            response = self.session.get("/orders")  # Same pattern!
            response.raise_for_status()
            return response.json()
        except RequestException as e:
            logger.error(f"Failed to get orders: {e}")
            raise ApiError(f"Failed to get orders: {e}")

# GOOD - Extract common pattern
def _request(self, endpoint):
    try:
        response = self.session.get(endpoint)
        response.raise_for_status()
        return response.json()
    except RequestException as e:
        logger.error(f"Failed to get {endpoint}: {e}")
        raise ApiError(f"Failed to get {endpoint}: {e}")

def get_users(self):
    return self._request("/users")
```

**Similar Class Structures**:
```python
# BAD - Multiple classes with same structure
class UserValidator:
    def validate(self, user):
        errors = []
        if not user.name:
            errors.append("name required")
        if not user.email:
            errors.append("email required")
        return errors

class OrderValidator:
    def validate(self, order):
        errors = []
        if not order.id:
            errors.append("id required")
        if not order.total:
            errors.append("total required")
        return errors

# GOOD - Generic validator
class RequiredFieldValidator:
    def __init__(self, required_fields):
        self.required_fields = required_fields

    def validate(self, obj):
        return [f"{f} required" for f in self.required_fields if not getattr(obj, f)]
```

### How to Identify

1. Search for similar function names (get_X, process_X, validate_X)
2. Look for identical control flow with different variables
3. Check for repeated try/except patterns
4. Find similar class methods across different classes

---

## 3. Over-Configuration

### What to Look For

Configuration and feature flags for things that don't actually vary.

### Detection Patterns

**Feature Flags Never Toggled**:
```python
# BAD - Flag always True
ENABLE_NEW_PARSER = True  # Never set to False anywhere

def parse(data):
    if ENABLE_NEW_PARSER:  # Always true!
        return new_parse(data)
    return old_parse(data)  # Dead code!
```

**Environment Variables With One Value**:
```python
# BAD - Always the same value
DATABASE_POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))
# But DB_POOL_SIZE is never set in any environment!

# BAD - Config that doesn't vary
config = {
    "retry_count": os.getenv("RETRY_COUNT", "3"),
    "timeout": os.getenv("TIMEOUT", "30"),
}
# All environments use the defaults
```

**Overly Generic Code for Single Use**:
```python
# BAD - Generic but only used once
class DataProcessor:
    def __init__(self,
                 input_format="json",
                 output_format="json",
                 encoding="utf-8",
                 validate=True,
                 transform=True):
        # Many options...
        pass

# Only ever called as:
processor = DataProcessor()  # All defaults, always!
```

**Unused Configuration Options**:
```python
# config.py
class Settings:
    database_url: str
    cache_ttl: int = 3600
    max_retries: int = 3
    enable_metrics: bool = True  # Never read!
    legacy_mode: bool = False  # Never read!
    debug_sql: bool = False  # Never read!
```

### Signs of Over-Configuration

- Config values that never change across environments
- Feature flags with only one state in production
- Options with defaults that are always used
- Configuration loaded but never accessed
- Environment variables with no variation

---

## Review Questions

1. Does this abstraction have multiple implementations?
2. Are there 3+ similar code blocks that could be parameterized?
3. Is this configuration actually configured differently anywhere?
4. Would removing this layer break anything meaningful?
5. Is this factory/wrapper adding value or just indirection?
