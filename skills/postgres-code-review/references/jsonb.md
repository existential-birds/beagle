# JSONB

## Critical Anti-Patterns

### 1. Using `JSON` Instead of `JSONB`

**Problem**: `JSON` stores raw text, re-parses on every access, and does not support GIN indexing.

```sql
-- BAD: Using JSON type
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    metadata JSON
);

-- GOOD: Use JSONB for querying and indexing
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    metadata JSONB
);
```

**Rule**: Always use `JSONB` unless preserving exact key ordering/whitespace is strictly required.

### 2. Wrong JSONB Operator

**Problem**: `->` returns `JSONB`, `->>` returns `text`. Comparing types without casting fails or misses indexes.

```sql
-- BAD: Comparing JSONB to text
SELECT * FROM users WHERE metadata->'age' = '25';  -- Fails!

-- GOOD: Use ->> for text comparison
SELECT * FROM users WHERE metadata->>'age' = '25';

-- GOOD: Use -> for JSONB comparison
SELECT * FROM users WHERE metadata->'age' = '25'::jsonb;

-- GOOD: Cast extracted text to numeric type
SELECT * FROM users WHERE (metadata->>'age')::int = 25;
```

**Operators**:
- `->` extracts as JSONB: `metadata->'address'` → `{"city": "NYC"}`
- `->>` extracts as text: `metadata->>'name'` → `"Alice"`
- `@>` contains: `metadata @> '{"role": "admin"}'`
- `?` key exists: `metadata ? 'email'`

### 3. Missing GIN Index on JSONB

**Problem**: JSONB containment/key queries perform sequential scans without a GIN index.

```sql
-- BAD: Querying JSONB without index
SELECT * FROM users WHERE metadata @> '{"role": "admin"}';  -- Seq Scan

-- GOOD: Create GIN index (or jsonb_path_ops for smaller @>-only indexes)
CREATE INDEX idx_users_metadata ON users USING gin(metadata);
CREATE INDEX idx_users_metadata_path ON users USING gin(metadata jsonb_path_ops);
```

### 4. Extracting Fields Instead of Using `@>` Containment

**Problem**: Extracting keys with `->>` bypasses a standard JSONB GIN index.

```sql
-- BAD: Bypasses table-level GIN index on metadata
SELECT * FROM events
WHERE metadata->>'type' = 'click' AND metadata->>'source' = 'mobile';

-- GOOD: Containment operator uses GIN index
SELECT * FROM events
WHERE metadata @> '{"type": "click", "source": "mobile"}';
```

### 5. Storing Flat String Lists as JSON Instead of `TEXT[]`

**Problem**: Cannot leverage native PostgreSQL array operators or simpler storage.

```python
# BAD: Storing simple tag list as JSON string
conn.execute(
    "INSERT INTO users (tags) VALUES (%s)",
    (json.dumps(["python", "postgres"]),),
)

# GOOD: Use native PostgreSQL TEXT[] for flat scalar arrays
conn.execute(
    "INSERT INTO users (tags) VALUES (%s)",
    (["python", "postgres"],),
)
conn.execute("SELECT * FROM users WHERE %s = ANY(tags)", ("python",))
```

### 6. Deep Path Lookups Without Expression Indexes

**Problem**: Equality queries on nested `->>` paths scan all rows without a B-tree expression index.

```sql
-- BAD: Querying deep path without index
SELECT * FROM events
WHERE metadata->'user'->'profile'->>'country' = 'US';

-- GOOD: Create expression index
CREATE INDEX idx_events_country ON events(
    (metadata->'user'->'profile'->>'country')
);
```

### 7. Not Validating JSONB Structure (or Relying on `assert`)

**Problem**: Unvalidated payloads corrupt downstream queries; using Python `assert` for runtime input validation fails silently when Python runs with `-O`!

```python
# BAD: assert is stripped under `python -O`!
def validate_user_metadata(metadata: dict) -> dict:
    assert isinstance(metadata.get("age"), int)
    return metadata

# GOOD: Explicit runtime validation (or Pydantic model) + DB CHECK constraint
def validate_user_metadata(metadata: dict) -> dict:
    if not isinstance(metadata.get("age"), int) or isinstance(metadata.get("age"), bool):
        raise ValueError("age must be an integer")
    if not isinstance(metadata.get("email"), str):
        raise ValueError("email must be a string")
    return metadata
```

```sql
-- ALSO GOOD: Database-level CHECK constraints
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    metadata JSONB NOT NULL,
    CHECK (jsonb_typeof(metadata->'age') = 'number'),
    CHECK (jsonb_typeof(metadata->'email') = 'string')
);
```

### 8. Using JSONB for Core Relational Columns

**Problem**: Storing foreign keys or structured entities in JSONB forfeits FK constraints, joins, and statistics.

```sql
-- BAD: Core relational keys buried in JSONB
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    data JSONB  -- Contains user_id, product_id, quantity
);

-- GOOD: Relational columns + FKs, JSONB only for genuinely dynamic attributes
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL,
    metadata JSONB
);
```

### 9. Inefficient Application-Side JSON Aggregation

**Problem**: Fetching rows and assembling nested JSON payloads in Python loops.

```python
# GOOD: Aggregate directly in PostgreSQL
cur = conn.execute(
    """
    SELECT jsonb_build_object(
        'products',
        COALESCE(jsonb_agg(jsonb_build_object('id', id, 'name', name)), '[]'::jsonb)
    )
    FROM products
    WHERE category_id = %s
    """,
    (cat_id,),
)
result = cur.fetchone()[0]
```

## Review Questions

1. Is `JSONB` used instead of `JSON`?
2. Are `->` vs `->>` and `@>` operators used correctly and backed by GIN or expression indexes?
3. Is JSONB input validated explicitly (without `assert`) and constrained at the DB level where needed?
4. Are relational columns and foreign keys modeled as proper columns rather than stuffed into JSONB?
