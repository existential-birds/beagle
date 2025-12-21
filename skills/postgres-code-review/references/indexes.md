# Indexes

## Critical Anti-Patterns

### 1. Missing Index on WHERE Clause

**Problem**: Sequential scan on large tables causes slow queries.

```sql
-- BAD: No index on email
SELECT * FROM users WHERE email = 'user@example.com';

-- GOOD: Create index
CREATE INDEX idx_users_email ON users(email);
SELECT * FROM users WHERE email = 'user@example.com';
```

```python
# Check query plan
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'user@example.com';
# Look for "Seq Scan" (bad) vs "Index Scan" (good)
```

### 2. Wrong Column Order in Composite Index

**Problem**: Index not used if query doesn't match leftmost columns.

```sql
-- BAD: Index doesn't match query pattern
CREATE INDEX idx_orders_wrong ON orders(status, user_id);
SELECT * FROM orders WHERE user_id = 123;  -- Won't use index!

-- GOOD: Match query pattern
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
SELECT * FROM orders WHERE user_id = 123;  -- Uses index
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';  -- Uses index
```

**Rule**: Put high-selectivity columns first, match WHERE clause order.

### 3. Not Using Partial Indexes

**Problem**: Indexing entire table when only subset is queried.

```sql
-- BAD: Index includes all rows
CREATE INDEX idx_orders_status ON orders(status);

-- GOOD: Only index active orders
CREATE INDEX idx_orders_active ON orders(user_id, created_at)
WHERE status = 'active';

SELECT * FROM orders
WHERE status = 'active' AND user_id = 123
ORDER BY created_at DESC;  -- Uses partial index
```

### 4. Missing Index on Foreign Keys

**Problem**: Slow JOINs and cascading deletes.

```sql
-- BAD: No index on foreign key
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id)
);

-- GOOD: Index foreign keys
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id)
);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

### 5. Not Using EXPLAIN ANALYZE

**Problem**: Guessing instead of measuring query performance.

```python
# BAD: Assuming query is fast
cursor.execute("SELECT * FROM orders WHERE user_id = %s", (user_id,))

# GOOD: Verify with EXPLAIN
cursor.execute("""
    EXPLAIN ANALYZE
    SELECT * FROM orders WHERE user_id = %s
""", (user_id,))
print(cursor.fetchall())
# Check: Index Scan vs Seq Scan, actual time, rows

# Then run actual query
cursor.execute("SELECT * FROM orders WHERE user_id = %s", (user_id,))
```

### 6. Over-Indexing

**Problem**: Slows down writes, wastes space.

```sql
-- BAD: Too many indexes on rarely-queried columns
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_updated_at ON users(updated_at);
CREATE INDEX idx_users_last_login ON users(last_login);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- GOOD: Only index frequently-queried columns
CREATE INDEX idx_users_email ON users(email);  -- Used for login
CREATE INDEX idx_users_username ON users(username);  -- Used for lookup
-- Skip indexes on created_at, updated_at, last_login if rarely queried
```

### 7. Not Using Covering Indexes

**Problem**: Index scan followed by table lookup (heap fetch).

```sql
-- BAD: Index on id only, must fetch name from table
CREATE INDEX idx_users_email ON users(email);
SELECT id, name FROM users WHERE email = 'user@example.com';

-- GOOD: Include name in index (covering index)
CREATE INDEX idx_users_email_covering ON users(email) INCLUDE (name);
SELECT id, name FROM users WHERE email = 'user@example.com';
-- "Index Only Scan" - no heap fetch needed
```

### 8. String Pattern Matching Without Index

**Problem**: LIKE with leading wildcard can't use B-tree index.

```sql
-- BAD: Can't use standard index
CREATE INDEX idx_users_email ON users(email);
SELECT * FROM users WHERE email LIKE '%@example.com';  -- Seq Scan

-- GOOD: Use trigram index for pattern matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_users_email_trgm ON users USING gin(email gin_trgm_ops);
SELECT * FROM users WHERE email LIKE '%@example.com';  -- Uses GIN index
```

## Review Questions

1. Do all WHERE and JOIN columns have indexes?
2. Are composite index column orders optimized for queries?
3. Would partial indexes reduce index size and improve performance?
4. Are foreign keys indexed?
5. Has EXPLAIN ANALYZE been used to verify query plans?
6. Are there redundant or unused indexes?
7. Would covering indexes eliminate heap fetches?
8. Are pattern matching queries using appropriate index types (GIN, trigram)?
