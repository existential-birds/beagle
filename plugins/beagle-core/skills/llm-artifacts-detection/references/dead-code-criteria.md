# Dead Code Criteria

Detailed detection criteria for dead code and cleanup opportunities commonly left by LLM coding agents.

## 1. Unused Code

### What to Look For

Functions, classes, and variables with no references anywhere in the codebase.

### Detection Patterns

**Unused Functions**:
```python
# Function defined but never called
def helper_process_data(data):  # No callers!
    """Process data helper."""
    return data.strip().lower()

def unused_validation(value):  # No callers!
    """Validate value format."""
    return bool(re.match(r"^\d+$", value))
```

**Unused Classes**:
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

**Unused Variables**:
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

**Unreachable Code**:
```python
def calculate(x):
    if x > 0:
        return x * 2
    return x * -1

    # Unreachable!
    logger.info("Calculation complete")
    cleanup()
```

### How to Find

1. Use IDE "Find Usages" on suspected dead code
2. Run `vulture` or similar dead code detector
3. Search for function/class name across codebase
4. Check import statements for unused imports

---

## 2. TODO/FIXME Comments

### What to Look For

Comments indicating incomplete work, technical debt, or known issues.

### Detection Patterns

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

### Categories

| Marker | Meaning | Action |
|--------|---------|--------|
| TODO | Planned work | Complete or create ticket |
| FIXME | Known bug | Fix or document as known issue |
| HACK | Workaround | Refactor or document why needed |
| XXX | Needs attention | Review and address |
| NOTE | Information | Review if still relevant |

---

## 3. Backwards Compatibility Cruft

### What to Look For

Patterns suggesting removed features kept around "just in case" or for backwards compatibility that's no longer needed.

### Detection Patterns

**Unused Renames**:
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

**Re-exports for Compatibility**:
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

**Removal Comments**:
```python
# # removed - no longer used
# old_function = None

# # legacy - kept for backwards compatibility
# LegacyClass = NewClass

# # deprecated - use new_method instead
def old_method():
    return new_method()
```

**Empty Compatibility Stubs**:
```python
class LegacyAdapter:
    """Kept for backwards compatibility."""
    pass  # Empty!

def deprecated_function(*args, **kwargs):
    """Deprecated. Use new_function instead."""
    pass  # Does nothing!
```

### How to Evaluate

1. Check if the "legacy" code has any callers
2. Search for imports of deprecated names
3. Check if deprecation warnings are even triggered
4. Review git history - how long has it been "deprecated"?

---

## 4. Orphaned Tests

### What to Look For

Tests that reference code that no longer exists.

### Detection Patterns

**Test Files Without Source**:
```
tests/
  test_old_feature.py  # But old_feature.py doesn't exist!
  test_removed_module.py  # removed_module/ was deleted
```

**Tests Importing Deleted Code**:
```python
# This import fails or imports from wrong place
from myapp.deleted_module import RemovedClass  # Module deleted!

def test_removed_feature():
    obj = RemovedClass()  # Class doesn't exist!
    assert obj.method() == expected
```

**Tests for Renamed/Moved Code**:
```python
# Old test file testing moved functionality
# test_utils.py
def test_helper_function():
    from myapp.utils import helper  # Moved to myapp.helpers!
    assert helper(1) == 2
```

### How to Find

1. Run the test suite - import errors reveal orphans
2. Check test file names against source file names
3. Review test imports for deleted modules
4. Look for skipped tests with outdated skip reasons

---

## Review Questions

1. Are there functions with zero callers?
2. How old are the TODO/FIXME comments?
3. Is "deprecated" code actually deprecated (with timeline)?
4. Do all test files have corresponding source files?
5. Are there variables assigned but never read?
