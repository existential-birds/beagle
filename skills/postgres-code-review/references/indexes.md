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

```sql
-- Check query plan
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM users WHERE email = 'user@example.com';
-- Look for "Seq Scan" (bad on large tables) vs "Index Scan" / "Index Only Scan" (good)
```

### 2. Wrong Column Order in Composite Index

**Problem**: B-tree index cannot be used efficiently if query omits the leftmost columns.

```sql
-- BAD: Index doesn't match query pattern
CREATE INDEX idx_orders_wrong ON orders(status, user_id);
SELECT * FROM orders WHERE user_id = 123;  -- Cannot use leftmost prefix!

-- GOOD: Match query pattern (equality columns first, range/sort columns after)
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
SELECT * FROM orders WHERE user_id = 123;
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
```

### 3. Not Using Partial Indexes

**Problem**: Indexing entire table when only a small filtered subset is queried.

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

**Problem**: Slow JOINs and full table scans on parent deletes/updates (`ON DELETE CASCADE`).

```sql
-- BAD: No index on foreign key
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id)
);

-- GOOD: Index foreign keys
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

### 5. Guessing Instead of Checking `EXPLAIN (ANALYZE, BUFFERS)`

**Problem**: Assuming an index is used when planner chooses a sequential scan due to selectivity, casts, or stale stats.

```python
# GOOD: Verify query plan in tests/diagnostics
cur = conn.execute(
    "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE user_id = %s",
    (user_id,),
)
plan = "\n".join(row[0] for row in cur.fetchall())
```

### 6. Over-Indexing

**Problem**: Redundant indexes slow down `INSERT`/`UPDATE`/`DELETE` writes and bloat storage/WAL.

```sql
-- BAD: Indexing columns that are never queried
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_updated_at ON users(updated_at);
CREATE INDEX idx_users_last_login ON users(last_login);

-- GOOD: Index only columns driven by actual query patterns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

### 7. Not Using Covering Indexes (`INCLUDE`)

**Problem**: Index scan followed by heap fetches when selecting extra non-indexed columns.

```sql
-- BAD: Must visit heap table to fetch name
CREATE INDEX idx_users_email ON users(email);
SELECT id, name FROM users WHERE email = 'user@example.com';

-- GOOD: Covering index enables Index Only Scan
CREATE INDEX idx_users_email_covering ON users(email) INCLUDE (name);
SELECT id, name FROM users WHERE email = 'user@example.com';
```

### 8. Leading-Wildcard `LIKE` Without Trigram Index

**Problem**: `LIKE '%...%'` cannot use a standard B-tree index.

```sql
-- BAD: Standard B-tree index unused for leading wildcard
CREATE INDEX idx_users_email ON users(email);
SELECT * FROM users WHERE email LIKE '%@example.com';  -- Seq Scan

-- GOOD: pg_trgm GIN index
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_users_email_trgm ON users USING gin(email gin_trgm_ops);
SELECT * FROM users WHERE email LIKE '%@example.com';  -- Uses GIN index
```

## Review Questions

1. Do WHERE and JOIN columns have indexes matching query selectivity and column order?
2. Are foreign key columns indexed?
3. Would partial indexes or `INCLUDE` covering indexes reduce index size or heap fetches?
4. Are there redundant or unused indexes hurting write throughput?
5. Do leading-wildcard `LIKE` / `ILIKE` queries have `pg_trgm` GIN indexes?
