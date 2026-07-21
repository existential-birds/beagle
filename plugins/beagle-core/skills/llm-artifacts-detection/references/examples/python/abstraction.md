# Abstraction — Python examples

Worked examples for [../../abstraction-criteria.md](../../abstraction-criteria.md). Load only when reviewing Python. The criteria file is the authority; these illustrate it.

## 1. Over-Abstraction

**Wrapper classes that just delegate**:
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

**Interfaces with a single implementation**:
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

**Protocol with one implementer**:
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

**Factory that always returns the same type**:
```python
# BAD - Factory with no variation
def create_processor(config):
    # Always returns the same type!
    return DataProcessor(config)

# Could just be:
processor = DataProcessor(config)
```

**Unnecessary indirection**:
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

## 2. Copy-Paste Drift

**Nearly identical functions**:
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

**Repeated patterns in methods**:
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

**Similar class structures**:
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

## 3. Over-Configuration

**Feature flags never toggled**:
```python
# BAD - Flag always True
ENABLE_NEW_PARSER = True  # Never set to False anywhere

def parse(data):
    if ENABLE_NEW_PARSER:  # Always true!
        return new_parse(data)
    return old_parse(data)  # Dead code!
```

**Environment variables with one value**:
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

**Overly generic code for a single use**:
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

**Unused configuration options**:
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
