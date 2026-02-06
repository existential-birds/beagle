# Error Handling

## Critical Anti-Patterns

### 1. Bare Except Clause

**Problem**: Catches everything including KeyboardInterrupt, SystemExit.

```python
# BAD
try:
    process()
except:
    pass

# GOOD - specific exception
try:
    process()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise

# ACCEPTABLE - if you must catch all
try:
    process()
except Exception as e:  # Still allows KeyboardInterrupt
    logger.error(f"Unexpected error: {e}")
    raise
```

### 2. Swallowing Exceptions

**Problem**: Hides errors, makes debugging impossible.

```python
# BAD
try:
    result = risky_operation()
except Exception:
    pass  # Error silently ignored!

# GOOD - log and handle
try:
    result = risky_operation()
except OperationError as e:
    logger.warning(f"Operation failed: {e}")
    result = default_value
```

### 3. Losing Exception Context

**Problem**: Original stack trace lost.

```python
# BAD - loses original traceback
try:
    parse_config()
except ValueError:
    raise ConfigError("Invalid config")

# GOOD - preserves chain
try:
    parse_config()
except ValueError as e:
    raise ConfigError("Invalid config") from e
```

### 4. Missing Context in Error Messages

**Problem**: Can't diagnose issue from logs.

```python
# BAD
except KeyError:
    raise ValueError("Missing key")

# GOOD - include context
except KeyError as e:
    raise ValueError(f"Missing required key: {e.args[0]}") from e
```

### 5. Not Logging Before Re-raising

**Problem**: Exception might be caught elsewhere without logging.

```python
# BAD - no record if caught upstream
try:
    process(item)
except ProcessError:
    raise

# GOOD - log before re-raising
try:
    process(item)
except ProcessError as e:
    logger.error(f"Failed to process item {item.id}: {e}")
    raise
```

## Logging Best Practices

```python
from loguru import logger

# BAD
print(f"Processing {item}")
print(f"Error: {e}")

# GOOD
logger.debug(f"Processing item {item.id}")
logger.info(f"Completed batch of {count} items")
logger.warning(f"Retry {attempt}/3 for {operation}")
logger.error(f"Failed to process {item.id}: {e}")

# With exception info
logger.exception(f"Unexpected error processing {item.id}")
```

## Review Questions

1. Are there any bare `except:` clauses?
2. Is exception context preserved with `raise ... from e`?
3. Do error messages include enough context to diagnose?
4. Is logging used instead of print statements?
