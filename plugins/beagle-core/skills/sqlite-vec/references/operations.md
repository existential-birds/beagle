# sqlite-vec Vector Operations

## Table of Contents
- [Constructor Functions](#constructor-functions)
- [Vector Metadata](#vector-metadata)
- [Arithmetic Operations](#arithmetic-operations)
- [Transformations](#transformations)
- [Quantization](#quantization)
- [Iteration](#iteration)
- [Batch Operations](#batch-operations)

## Constructor Functions

### vec_f32() - Float32 Vectors
Creates a float32 vector from JSON or BLOB:

```sql
-- From JSON
SELECT vec_f32('[.1, .2, .3, 4]');
-- Returns: X'CDCCCC3DCDCC4C3E9A99993E00008040'

-- From BLOB
SELECT vec_f32(X'AABBCCDD');
-- Returns: X'AABBCCDD' (with subtype 223)

-- Check subtype
SELECT subtype(vec_f32('[.1, .2, .3, 4]'));
-- Returns: 223

-- Convert back to JSON
SELECT vec_to_json(vec_f32(X'AABBCCDD'));
-- Returns: '[-1844071490169864000.000000]'
```

Python usage:
```python
from sqlite_vec import serialize_float32

vector = [0.1, 0.2, 0.3, 0.4]
blob = serialize_float32(vector)

# Or manually
import struct
blob = struct.pack("%sf" % len(vector), *vector)
```

### vec_int8() - Int8 Vectors
Creates an 8-bit integer vector:

```sql
-- From JSON
SELECT vec_int8('[1, 2, 3, 4]');
-- Returns: X'01020304' (subtype 225)

-- Valid range: -128 to 127
SELECT vec_int8('[127, -128, 0, 64]');
-- Returns: X'7F800040'

-- Out of range error
SELECT vec_int8('[999]');
-- ERROR: value out of range for int8
```

Python usage:
```python
from sqlite_vec import serialize_int8

vector = [1, 2, 3, 4]
blob = serialize_int8(vector)

# Or manually
import struct
blob = struct.pack("%sb" % len(vector), *vector)
```

### vec_bit() - Binary Vectors
Creates a bit vector from BLOB:

```sql
-- From BLOB (8 bits per byte)
SELECT vec_bit(X'F0');
-- Returns: X'F0' (subtype 224)

SELECT vec_to_json(vec_bit(X'F0'));
-- Returns: '[0,0,0,0,1,1,1,1]'

-- Multiple bytes
SELECT vec_to_json(vec_bit(X'FF00'));
-- Returns: '[0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1]'
```

## Vector Metadata

### vec_length() - Get Dimension
```sql
-- Float32 (default)
SELECT vec_length('[.1, .2]');
-- Returns: 2

SELECT vec_length(X'AABBCCDD');
-- Returns: 1 (one 4-byte float)

SELECT vec_length(vec_int8(X'AABBCCDD'));
-- Returns: 4 (four 1-byte ints)

SELECT vec_length(vec_bit(X'AABBCCDD'));
-- Returns: 32 (32 bits)
```

### vec_type() - Get Element Type
```sql
SELECT vec_type('[.1, .2]');
-- Returns: 'float32'

SELECT vec_type(vec_int8('[1, 2]'));
-- Returns: 'int8'

SELECT vec_type(vec_bit(X'FF'));
-- Returns: 'bit'
```

### vec_to_json() - Convert to JSON
```sql
SELECT vec_to_json(X'AABBCCDD');
-- Returns: '[-1844071490169864000.000000]'

SELECT vec_to_json(vec_int8(X'AABBCCDD'));
-- Returns: '[-86,-69,-52,-35]'

SELECT vec_to_json(vec_bit(X'F0'));
-- Returns: '[0,0,0,0,1,1,1,1]'
```

## Arithmetic Operations

### vec_add() - Vector Addition
Add corresponding elements of two vectors:

```sql
SELECT vec_to_json(
  vec_add('[.1, .2, .3]', '[.4, .5, .6]')
);
-- Returns: '[0.500000,0.700000,0.900000]'

-- Int8 vectors
SELECT vec_to_json(
  vec_add(vec_int8('[1, 2, 3]'), vec_int8('[4, 5, 6]'))
);
-- Returns: '[5,7,9]'

-- Type mismatch error
SELECT vec_add('[.1]', vec_int8('[1]'));
-- ERROR: Vector type mismatch
```

### vec_sub() - Vector Subtraction
Subtract corresponding elements:

```sql
SELECT vec_to_json(
  vec_sub('[.1, .2, .3]', '[.4, .5, .6]')
);
-- Returns: '[-0.300000,-0.300000,-0.300000]'

-- Int8 vectors
SELECT vec_to_json(
  vec_sub(vec_int8('[10, 20, 30]'), vec_int8('[1, 2, 3]'))
);
-- Returns: '[9,18,27]'
```

## Transformations

### vec_normalize() - L2 Normalization
Normalize vector to unit length (L2 norm):

```sql
SELECT vec_to_json(
  vec_normalize('[2, 3, 1, -4]')
);
-- Returns: '[0.365148,0.547723,0.182574,-0.730297]'

-- Only supports float32
SELECT vec_normalize(vec_int8('[1, 2, 3]'));
-- ERROR: Only float32 vectors supported
```

Python usage for Matryoshka embeddings:
```python
# Normalize after slicing for adaptive-length embeddings
db.execute("""
    SELECT vec_to_json(
      vec_normalize(
        vec_slice(embedding, 0, 256)
      )
    )
    FROM vec_items
""")
```

### vec_slice() - Extract Subvector
Extract elements from start (inclusive) to end (exclusive):

```sql
-- Extract first 2 elements
SELECT vec_to_json(
  vec_slice('[1, 2, 3, 4]', 0, 2)
);
-- Returns: '[1.000000,2.000000]'

-- Extract last 2 elements
SELECT vec_to_json(
  vec_slice('[1, 2, 3, 4]', 2, 4)
);
-- Returns: '[3.000000,4.000000]'

-- Matryoshka pattern: slice then normalize
SELECT vec_to_json(
  vec_normalize(
    vec_slice('[2, 3, 1, -4]', 0, 2)
  )
);
-- Returns: '[0.554700,0.832050]'
```

Constraints:
- `start >= 0`
- `end > start`
- `end <= vec_length(vector)`
- For bit vectors, start and end must be divisible by 8

## Quantization

### vec_quantize_binary() - Binary Quantization
Convert float32/int8 to bit vector (positive→1, negative→0):

```sql
SELECT vec_quantize_binary('[1, 2, 3, 4, 5, 6, 7, 8]');
-- Returns: X'FF' (all positive)

SELECT vec_quantize_binary('[1, 2, 3, 4, -5, -6, -7, -8]');
-- Returns: X'0F' (first 4 positive, last 4 negative)

SELECT vec_quantize_binary('[-1, -2, -3, -4, -5, -6, -7, -8]');
-- Returns: X'00' (all negative)

-- Visualize
SELECT vec_to_json(
  vec_quantize_binary('[1, 2, 3, 4, -5, -6, -7, -8]')
);
-- Returns: '[0,0,0,0,1,1,1,1]'
```

Requirements:
- Vector length must be divisible by 8
- Only float32 or int8 vectors

### vec_quantize_int8() - Int8 Quantization
Quantize float32 to int8 using the specified method:

```sql
SELECT vec_quantize_int8('[1.5, 2.7, -3.2, 4.9]', 'unit');
-- Quantizes to int8 range [-128, 127]
-- Second parameter specifies quantization method (e.g., 'unit')
```

## Iteration

### vec_each() - Iterate Elements
Table function returning one row per vector element:

```sql
SELECT rowid, value
FROM vec_each('[1, 2, 3, 4]');
/*
┌───────┬───────┐
│ rowid │ value │
├───────┼───────┤
│ 0     │ 1     │
│ 1     │ 2     │
│ 2     │ 3     │
│ 3     │ 4     │
└───────┴───────┘
*/

-- Int8 vector
SELECT rowid, value
FROM vec_each(vec_int8('[10, 20, 30]'));
/*
┌───────┬───────┐
│ rowid │ value │
├───────┼───────┤
│ 0     │ 10    │
│ 1     │ 20    │
│ 2     │ 30    │
└───────┴───────┘
*/

-- Bit vector
SELECT rowid, value
FROM vec_each(vec_bit(X'F0'));
/*
┌───────┬───────┐
│ rowid │ value │
├───────┼───────┤
│ 0     │ 1     │
│ 1     │ 1     │
│ 2     │ 1     │
│ 3     │ 1     │
│ 4     │ 0     │
│ 5     │ 0     │
│ 6     │ 0     │
│ 7     │ 0     │
└───────┴───────┘
*/
```

Use cases:
- Debugging vectors
- Computing custom statistics
- Element-wise operations

## Batch Operations

### Batch Insert
```python
from sqlite_vec import serialize_float32

vectors = [
    (1, [0.1, 0.2, 0.3, 0.4]),
    (2, [0.5, 0.6, 0.7, 0.8]),
    (3, [0.9, 1.0, 1.1, 1.2])
]

with db:
    for rowid, vector in vectors:
        db.execute(
            "INSERT INTO vec_items(rowid, embedding) VALUES (?, ?)",
            [rowid, serialize_float32(vector)]
        )
```

### Batch Insert from Query
```sql
-- From embeddings table
INSERT INTO vec_items(rowid, embedding)
SELECT id, embedding
FROM source_embeddings;

-- With transformation
INSERT INTO vec_items(rowid, embedding)
SELECT id, vec_normalize(embedding)
FROM source_embeddings;
```

### Bulk Update
```python
# Update multiple vectors
updates = [
    (serialize_float32([1.1, 1.2, 1.3, 1.4]), 1),
    (serialize_float32([2.1, 2.2, 2.3, 2.4]), 2),
    (serialize_float32([3.1, 3.2, 3.3, 3.4]), 3)
]

with db:
    for embedding, rowid in updates:
        db.execute(
            "UPDATE vec_items SET embedding = ? WHERE rowid = ?",
            [embedding, rowid]
        )
```

### Batch Delete
```sql
-- Delete by rowid list
DELETE FROM vec_items
WHERE rowid IN (1, 2, 3, 4, 5);

-- Delete by metadata condition
DELETE FROM vec_movies
WHERE year < 1950;
```

### Batch Operations Best Practices

1. Use transactions for bulk operations:
```python
with db:  # Automatic transaction
    for item in large_batch:
        db.execute(...)
```

2. Prepare statements for repeated operations:
```python
stmt = db.execute("INSERT INTO vec_items VALUES (?, ?)")
with db:
    for item in items:
        stmt.execute([item.id, serialize_float32(item.vector)])
```

3. Batch size recommendations:
- Small batches (100-1000): Better memory usage
- Large batches (10000+): Fewer transactions, faster overall
- Balance based on available memory

4. Monitor performance:
```python
import time

start = time.time()
with db:
    for i, vector in enumerate(vectors):
        db.execute(...)
        if i % 1000 == 0:
            print(f"Inserted {i} vectors in {time.time() - start:.2f}s")
```
