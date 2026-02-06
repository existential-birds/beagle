# sqlite-vec Setup

## Table of Contents
- [Installation](#installation)
- [Loading the Extension](#loading-the-extension)
- [Binary Serialization Helper](#binary-serialization-helper)
- [NumPy Integration](#numpy-integration)
- [Connection Setup Pattern](#connection-setup-pattern)
- [SQLite Version Requirements](#sqlite-version-requirements)
- [MacOS Considerations](#macos-considerations)

## Installation

### Python
```bash
pip install sqlite-vec
```

### Other Languages
- Node.js: `pnpm add sqlite-vec`
- Ruby: `gem install sqlite-vec`
- Go: `go get -u github.com/asg017/sqlite-vec/bindings/go`
- Rust: `cargo add sqlite-vec`

## Loading the Extension

### Python
```python
import sqlite3
import sqlite_vec

db = sqlite3.connect(":memory:")
db.enable_load_extension(True)
sqlite_vec.load(db)
db.enable_load_extension(False)

# Verify installation
vec_version, = db.execute("select vec_version()").fetchone()
print(f"vec_version={vec_version}")
```

### CLI
```sql
.load ./vec0
select vec_version();
```

## Binary Serialization Helper

### serialize_float32()
Converts a Python list of floats into the compact BLOB format sqlite-vec expects:

```python
from sqlite_vec import serialize_float32
import struct

embedding = [0.1, 0.2, 0.3, 0.4]

# Using the helper function
blob = serialize_float32(embedding)

# Equivalent to:
blob = struct.pack("%sf" % len(embedding), *embedding)

# Use in queries
db.execute(
    "INSERT INTO vec_items(rowid, embedding) VALUES (?, ?)",
    [1, serialize_float32(embedding)]
)
```

### serialize_int8()
For int8 vectors:

```python
from sqlite_vec import serialize_int8

int_vector = [1, 2, 3, 4]
blob = serialize_int8(int_vector)
```

## NumPy Integration

### Using NumPy Arrays
NumPy arrays can be passed directly as they implement the Buffer protocol. Cast to float32:

```python
import numpy as np

embedding = np.array([0.1, 0.2, 0.3, 0.4])

# Must cast to float32
db.execute(
    "SELECT vec_length(?)",
    [embedding.astype(np.float32)]
)
```

### register_numpy()
For advanced NumPy integration with static blobs:

```python
from sqlite_vec import register_numpy
import numpy as np

# Create a NumPy array of vectors
vectors = np.array([
    [1.0, 2.0, 3.0],
    [4.0, 5.0, 6.0],
    [7.0, 8.0, 9.0]
], dtype=np.float32)

# Register as a static blob table
register_numpy(db, "my_vectors", vectors)

# Query the static blob table
results = db.execute(
    "SELECT rowid, vector FROM my_vectors"
).fetchall()
```

## Connection Setup Pattern

Complete setup pattern for Python:

```python
import sqlite3
import sqlite_vec
from sqlite_vec import serialize_float32
import struct

# Create connection
db = sqlite3.connect(":memory:")  # or use a file path
db.enable_load_extension(True)
sqlite_vec.load(db)
db.enable_load_extension(False)

# Verify version
sqlite_version, vec_version = db.execute(
    "select sqlite_version(), vec_version()"
).fetchone()
print(f"sqlite_version={sqlite_version}, vec_version={vec_version}")

# Create vec0 table
db.execute("""
    CREATE VIRTUAL TABLE vec_items USING vec0(
        embedding float[4]
    )
""")

# Insert vectors
items = [
    (1, [0.1, 0.1, 0.1, 0.1]),
    (2, [0.2, 0.2, 0.2, 0.2]),
    (3, [0.3, 0.3, 0.3, 0.3])
]

with db:
    for rowid, vector in items:
        db.execute(
            "INSERT INTO vec_items(rowid, embedding) VALUES (?, ?)",
            [rowid, serialize_float32(vector)]
        )

# Query
query = [0.25, 0.25, 0.25, 0.25]
results = db.execute(
    """
    SELECT rowid, distance
    FROM vec_items
    WHERE embedding MATCH ?
      AND k = 2
    ORDER BY distance
    """,
    [serialize_float32(query)]
).fetchall()
```

## SQLite Version Requirements

sqlite-vec requires SQLite 3.41+ for full functionality. Check version:

```bash
python -c 'import sqlite3; print(sqlite3.sqlite_version)'
```

### Upgrade Options
1. Use `pysqlite3` package (bundles updated SQLite)
2. Compile custom SQLite with LD_PRELOAD/DYLD_LIBRARY_PATH
3. Upgrade Python version (3.12+ usually has recent SQLite)

## MacOS Considerations

Default MacOS Python doesn't support SQLite extensions. Solutions:

1. Use Homebrew Python: `brew install python`
2. Use `/opt/homebrew/bin/python3` instead of system Python
3. Install `pysqlite3` package

Error indicating this issue:
```
AttributeError: 'sqlite3.Connection' object has no attribute 'enable_load_extension'
```
