# JSONB

## Critical Anti-Patterns

### 1. Using JSON Instead of JSONB

**Problem**: JSON is stored as text, slower to query, no indexing.

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

**Rule**: Always use JSONB unless you need to preserve exact formatting/whitespace.

### 2. Wrong JSONB Operator

**Problem**: `->` returns JSONB, `->>` returns text. Using wrong one breaks queries.

```sql
-- BAD: Comparing JSONB to text
SELECT * FROM users WHERE metadata->'age' = '25';  -- Won't work

-- GOOD: Use ->> for text comparison
SELECT * FROM users WHERE metadata->>'age' = '25';

-- GOOD: Use -> for JSONB comparison
SELECT * FROM users WHERE metadata->'age' = '25'::jsonb;

-- GOOD: Cast to integer for numeric comparison
SELECT * FROM users WHERE (metadata->>'age')::int = 25;
```

**Operators**:
- `->` extracts as JSONB: `metadata->'address'` → `{"city": "NYC"}`
- `->>` extracts as text: `metadata->>'name'` → `"Alice"`
- `@>` contains: `metadata @> '{"role": "admin"}'`
- `?` key exists: `metadata ? 'email'`

### 3. Missing GIN Index on JSONB

**Problem**: JSONB queries without indexes perform sequential scans.

```sql
-- BAD: Querying JSONB without index
SELECT * FROM users WHERE metadata @> '{"role": "admin"}';  -- Seq Scan

-- GOOD: Create GIN index
CREATE INDEX idx_users_metadata ON users USING gin(metadata);
SELECT * FROM users WHERE metadata @> '{"role": "admin"}';  -- Uses index

-- GOOD: GIN index on specific path
CREATE INDEX idx_users_metadata_role ON users USING gin((metadata->'role'));
```

### 4. Not Using Containment Operator

**Problem**: Extracting and comparing is slower than using `@>`.

```sql
-- BAD: Extracting then comparing
SELECT * FROM events
WHERE metadata->>'type' = 'click' AND metadata->>'source' = 'mobile';

-- GOOD: Use containment operator
SELECT * FROM events
WHERE metadata @> '{"type": "click", "source": "mobile"}';
-- Much faster with GIN index
```

### 5. Storing Arrays as JSON Strings

**Problem**: Can't use array operators, must parse JSON every time.

```python
# BAD: Storing array as JSON string
cursor.execute("""
    INSERT INTO users (tags) VALUES (%s)
""", (json.dumps(['python', 'postgres']),))

cursor.execute("""
    SELECT * FROM users WHERE tags::jsonb @> '"python"'
""")

# GOOD: Use PostgreSQL array type for simple arrays
cursor.execute("""
    INSERT INTO users (tags) VALUES (%s)
""", (['python', 'postgres'],))

cursor.execute("""
    SELECT * FROM users WHERE 'python' = ANY(tags)
""")

# Use JSONB only for complex nested structures
```

### 6. Deep Nesting Without Indexes

**Problem**: Querying deep paths is slow without expression indexes.

```sql
-- BAD: Querying deep path without index
SELECT * FROM events
WHERE metadata->'user'->'profile'->>'country' = 'US';

-- GOOD: Create expression index
CREATE INDEX idx_events_country ON events(
    (metadata->'user'->'profile'->>'country')
);
SELECT * FROM events
WHERE metadata->'user'->'profile'->>'country' = 'US';
```

### 7. Not Validating JSONB Structure

**Problem**: No schema validation leads to inconsistent data.

```python
# BAD: No validation
cursor.execute("""
    INSERT INTO users (metadata) VALUES (%s)
""", (json.dumps({'age': 'twenty-five'}),))  # Should be integer!

# GOOD: Validate before insert
def validate_user_metadata(metadata: dict) -> dict:
    assert isinstance(metadata.get('age'), int), "age must be integer"
    assert isinstance(metadata.get('email'), str), "email must be string"
    return metadata

metadata = validate_user_metadata({'age': 25, 'email': 'user@example.com'})
cursor.execute("""
    INSERT INTO users (metadata) VALUES (%s)
""", (json.dumps(metadata),))

# BETTER: Use CHECK constraint
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    metadata JSONB,
    CHECK (jsonb_typeof(metadata->'age') = 'number'),
    CHECK (jsonb_typeof(metadata->'email') = 'string')
);
```

### 8. JSONB for Relational Data

**Problem**: Using JSONB when proper columns/foreign keys are better.

```sql
-- BAD: Storing relational data in JSONB
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    data JSONB  -- Contains user_id, product_id, quantity
);

-- GOOD: Use proper columns and foreign keys
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER,
    metadata JSONB  -- Only for truly unstructured data
);
```

**Rule**: Use JSONB for truly dynamic/unstructured data, not for avoiding schema design.

### 9. Inefficient JSONB Aggregation

**Problem**: Not using jsonb_agg or jsonb_object_agg.

```python
# BAD: Fetching and building JSON in application code
cursor.execute("SELECT id, name FROM products WHERE category_id = %s", (cat_id,))
products = [{'id': row[0], 'name': row[1]} for row in cursor.fetchall()]
result = {'products': products}

# GOOD: Build JSON in database
cursor.execute("""
    SELECT jsonb_build_object(
        'products', jsonb_agg(jsonb_build_object('id', id, 'name', name))
    )
    FROM products
    WHERE category_id = %s
""", (cat_id,))
result = cursor.fetchone()[0]
```

## Review Questions

1. Is JSONB used instead of JSON?
2. Are the correct operators used (`->` vs `->>`, `@>` for containment)?
3. Do JSONB columns have GIN indexes?
4. Are containment operators (`@>`) used instead of extracting and comparing?
5. Is JSONB used appropriately (not for relational data)?
6. Are deep paths indexed with expression indexes?
7. Is JSONB structure validated?
8. Are JSONB aggregation functions used instead of application-side building?
