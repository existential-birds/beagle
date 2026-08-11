# Dead Code — Python examples

Worked examples for [../../dead-code-criteria.md](../../dead-code-criteria.md). Load only when reviewing Python. The criteria file is the authority; these illustrate it.

## 1. Unused Code

**Unused functions**:
```python
# Function defined but never called
def helper_process_data(data):  # No callers!
    """Process data helper."""
    return data.strip().lower()

def unused_validation(value):  # No callers!
    """Validate value format."""
    return bool(re.match(r"^\d+$", value))
```

**Unused classes**:
```python
# Class defined but never instantiated
class DataTransformer:  # Never used!
    """Transform data between formats."""
    def transform(self, data):
        return data

class LegacyProcessor:  # Never used!
    """Old processor implementation."""
    pass
```

**Unused variables**:
```python
# Module-level variables never read
DEFAULT_TIMEOUT = 30  # Never referenced
CACHE_SIZE = 1000  # Never referenced

# Assigned but never used
def process():
    result = compute()  # 'result' never used
    intermediate = transform()  # Never used
    return other_compute()
```

**Unreachable code**:
```python
def calculate(x):
    if x > 0:
        return x * 2
    return x * -1

    # Unreachable!
    logger.info("Calculation complete")
    cleanup()
```

**Python-specific tooling:** `vulture` for dead code, `ruff`/`flake8` F401 for unused imports, F841 for unused locals.

## 2. TODO/FIXME Comments

```python
# TODO: implement caching  <-- Incomplete feature
def get_user(id):
    return db.query(User).get(id)

# FIXME: this breaks with unicode  <-- Known bug
def parse_name(name):
    return name.split()[0]

# HACK: temporary workaround for issue #123  <-- Tech debt
result = data.replace("\x00", "")

# XXX: this needs to be refactored  <-- Acknowledged mess
def complex_function():
    # 200 lines of spaghetti
    pass

# NOTE: remove after migration  <-- Scheduled for deletion
old_format = convert_legacy(data)
```

## 3. Backwards Compatibility Cruft

**Unused renames**:
```python
# Variables renamed to indicate unused
_unused_config = old_config  # Why keep it?
_old_handler = legacy_handler  # Delete it!
_deprecated_cache = cache_v1  # Remove!

# Functions with "old" or "legacy" suffixes
def process_old(data):  # Is this still needed?
    pass

def validate_legacy(value):  # Who calls this?
    pass
```

**Re-exports for compatibility**:
```python
# In __init__.py - re-exporting moved code
from .new_location import Thing  # noqa: F401
from .new_module import OldName as OldName  # Backwards compat

# Explicit compatibility exports
__all__ = [
    "NewThing",
    "OldThing",  # Deprecated, remove in v3.0
]
```

**Removal comments**:
```python
# # removed - no longer used
# old_function = None

# # legacy - kept for backwards compatibility
# LegacyClass = NewClass

# # deprecated - use new_method instead
def old_method():
    return new_method()
```

**Empty compatibility stubs**:
```python
class LegacyAdapter:
    """Kept for backwards compatibility."""
    pass  # Empty!

def deprecated_function(*args, **kwargs):
    """Deprecated. Use new_function instead."""
    pass  # Does nothing!
```

**Python-specific public-API check:** before confirming an export is dead, check `__all__` and the package `__init__.py`, plus any consuming repos.

## 4. Orphaned Tests

**Test files without source**:
```
tests/
  test_old_feature.py  # But old_feature.py doesn't exist!
  test_removed_module.py  # removed_module/ was deleted
```

**Tests importing deleted code**:
```python
# This import fails or imports from wrong place
from myapp.deleted_module import RemovedClass  # Module deleted!

def test_removed_feature():
    obj = RemovedClass()  # Class doesn't exist!
    assert obj.method() == expected
```

**Tests for renamed/moved code**:
```python
# Old test file testing moved functionality
# test_utils.py
def test_helper_function():
    from myapp.utils import helper  # Moved to myapp.helpers!
    assert helper(1) == 2
```
