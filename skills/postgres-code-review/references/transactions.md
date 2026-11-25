# Transactions

## Critical Anti-Patterns

### 1. Wrong Isolation Level for Read-Modify-Write

**Problem**: Default `READ COMMITTED` allows lost updates between a `SELECT` and subsequent `UPDATE`.

```python
# BAD: Race condition under READ COMMITTED
async with pool.acquire() as conn:
    async with conn.transaction():
        balance = await conn.fetchval(
            "SELECT balance FROM accounts WHERE id = $1", from_id
        )
        if balance < amount:
            raise ValueError("Insufficient funds")
        await conn.execute(
            "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
            amount, from_id,
        )

# GOOD: Lock row with SELECT ... FOR UPDATE (or use SERIALIZABLE with retry)
async with pool.acquire() as conn:
    async with conn.transaction():
        balance = await conn.fetchval(
            "SELECT balance FROM accounts WHERE id = $1 FOR UPDATE",
            from_id,
        )
        if balance < amount:
            raise ValueError("Insufficient funds")
        await conn.execute(
            "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
            amount, from_id,
        )
        await conn.execute(
            "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
            amount, to_id,
        )
```

**Isolation Levels**:
- `READ COMMITTED` (default): Prevents dirty reads; non-repeatable reads possible
- `REPEATABLE READ`: Snapshot isolation for the transaction
- `SERIALIZABLE`: Full serializability (requires retry on `SerializationError`)

### 2. Long-Running Transactions Holding Locks

**Problem**: Calling external APIs inside a transaction holds row locks, stalls other queries, and blocks autovacuum.

```python
# BAD: External API call inside transaction
async with pool.acquire() as conn:
    async with conn.transaction():
        orders = await conn.fetch("SELECT * FROM orders WHERE status = 'pending'")
        for order in orders:
            result = await external_api.process(order)  # Holds DB conn + locks!
            await conn.execute(
                "UPDATE orders SET status = 'processed', result = $1 WHERE id = $2",
                result, order["id"],
            )

# GOOD: Keep transactions short; perform external I/O outside transaction
async with pool.acquire() as conn:
    orders = await conn.fetch("SELECT * FROM orders WHERE status = 'pending'")

for order in orders:
    result = await external_api.process(order)
    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute(
                "UPDATE orders SET status = 'processed', result = $1 WHERE id = $2",
                result, order["id"],
            )
```

### 3. Deadlocks from Inconsistent Lock Order

**Problem**: Updating multiple rows in inconsistent order across concurrent transactions causes deadlocks.

```python
# GOOD: Always lock IDs in deterministic sorted order
async def transfer(from_id: int, to_id: int, amount: int):
    first_id, second_id = sorted([from_id, to_id])

    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute(
                "SELECT id FROM accounts WHERE id IN ($1, $2) ORDER BY id FOR UPDATE",
                first_id, second_id,
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
                amount, from_id,
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
                amount, to_id,
            )
```

### 4. Session-Level Advisory Locks Under Transaction Pooling

**Problem**: Session-level `pg_try_advisory_lock()` / `pg_advisory_unlock()` breaks under PgBouncer `pool_mode = transaction` (the unlock may execute on a different backend connection or leak if a connection resets).

```python
# BAD with PgBouncer transaction pooling: session-level advisory lock
locked = await conn.fetchval("SELECT pg_try_advisory_lock($1)", job_id)
# ... if pooled in transaction mode, pg_advisory_unlock may run on another backend!

# GOOD: Transaction-scoped advisory lock (auto-released at COMMIT/ROLLBACK)
async def process_unique_job(job_id: int):
    async with pool.acquire() as conn:
        async with conn.transaction():
            locked = await conn.fetchval(
                "SELECT pg_try_advisory_xact_lock($1)",
                job_id,
            )
            if not locked:
                return
            job = await conn.fetchrow("SELECT * FROM jobs WHERE id = $1", job_id)
            if job and job["status"] == "pending":
                # Keep work inside transaction fast (or transition status to 'running' first)
                await conn.execute(
                    "UPDATE jobs SET status = 'running' WHERE id = $1",
                    job_id,
                )
```

**Advisory Lock Functions**:
- `pg_advisory_xact_lock(key)` / `pg_try_advisory_xact_lock(key)`: Transaction-scoped, auto-released on commit/rollback (safe with PgBouncer transaction mode)
- `pg_advisory_lock(key)` / `pg_try_advisory_lock(key)` / `pg_advisory_unlock(key)`: Session-scoped (requires direct connection or PgBouncer `session` mode)

### 5. Not Retrying Serialization Failures

**Problem**: `REPEATABLE READ` / `SERIALIZABLE` transactions can fail with `40001` (`SerializationError`) under contention and must be retried.

```python
import asyncio
import asyncpg

async def increment_counter(counter_id: int, max_retries: int = 3):
    for attempt in range(max_retries):
        try:
            async with pool.acquire() as conn:
                async with conn.transaction(isolation="serializable"):
                    count = await conn.fetchval(
                        "SELECT count FROM counters WHERE id = $1", counter_id
                    )
                    await conn.execute(
                        "UPDATE counters SET count = $1 WHERE id = $2",
                        count + 1, counter_id,
                    )
            return
        except asyncpg.SerializationError:
            if attempt == max_retries - 1:
                raise
            await asyncio.sleep(0.1 * (2 ** attempt))
```

### 6. Missing ROLLBACK on Error

**Problem**: Manual `BEGIN` / `COMMIT` without `try`/`except` rollback leaves aborted or uncommitted transactions holding locks on pooled connections.

```python
# BAD: Unhandled exception leaves transaction open on connection
conn.execute("BEGIN")
conn.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
conn.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
conn.commit()

# GOOD: Context manager automatically commits or rolls back
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        await conn.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

# GOOD (psycopg 3 sync/async):
with pool.connection() as conn:
    with conn.transaction():
        conn.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        conn.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
```

### 7. Handling Partial Failures Without Savepoints

**Problem**: Catching an exception from a failed SQL statement inside a PostgreSQL transaction without a `SAVEPOINT` leaves the entire transaction in an aborted state (`current transaction is aborted, commands ignored until end of transaction block`).

```python
# BAD: Raw SQL inside outer transaction without SAVEPOINT aborts the whole transaction
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("INSERT INTO logs (message) VALUES ('start')")
        try:
            await conn.execute("INSERT INTO data (value) VALUES ('bad')")  # SQL error!
        except asyncpg.PostgresError:
            pass  # Outer transaction is now ABORTED! Next query fails!
        await conn.execute("INSERT INTO logs (message) VALUES ('end')")  # InFailedSQLTransactionError!

# GOOD: Nested conn.transaction() in asyncpg (and psycopg 3) automatically creates a SAVEPOINT
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("INSERT INTO logs (message) VALUES ('start')")
        try:
            async with conn.transaction():  # Automatically issues SAVEPOINT / ROLLBACK TO SAVEPOINT!
                await conn.execute("INSERT INTO data (value) VALUES ('bad')")
        except asyncpg.PostgresError:
            pass  # Rolled back to savepoint; outer transaction remains healthy
        await conn.execute("INSERT INTO logs (message) VALUES ('end')")
```

*(Note: Both `asyncpg`'s nested `async with conn.transaction():` and `psycopg` 3's nested `with conn.transaction():` automatically manage PostgreSQL `SAVEPOINT`s. If using raw DB-API cursors without `conn.transaction()`, issue `SAVEPOINT` / `ROLLBACK TO SAVEPOINT` explicitly.)*

### 8. Not Using `FOR UPDATE SKIP LOCKED` for Job Queues

**Problem**: `FOR UPDATE` without `SKIP LOCKED` serializes queue workers behind locked rows.

```python
# BAD: Workers block waiting on the same top row
job = await conn.fetchrow("""
    SELECT * FROM jobs WHERE status = 'pending'
    ORDER BY created_at LIMIT 1 FOR UPDATE
""")

# GOOD: Workers skip locked rows and claim distinct jobs concurrently
async with pool.acquire() as conn:
    async with conn.transaction():
        job = await conn.fetchrow("""
            SELECT * FROM jobs
            WHERE status = 'pending'
            ORDER BY created_at
            LIMIT 1
            FOR UPDATE SKIP LOCKED
        """)
        if job:
            await conn.execute(
                "UPDATE jobs SET status = 'processing' WHERE id = $1",
                job["id"],
            )
```

## Review Questions

1. Is the transaction isolation level (and `FOR UPDATE` / retry logic) appropriate for concurrent writes?
2. Are transactions kept short without external I/O inside them?
3. Are multi-row locks acquired in a consistent deterministic order?
4. Are advisory locks using `pg_*_xact_lock` when running behind PgBouncer transaction pooling?
5. Are partial-failure sub-blocks wrapped in nested `conn.transaction()` / `SAVEPOINT`s?
6. Are queue consumers using `FOR UPDATE SKIP LOCKED`?
