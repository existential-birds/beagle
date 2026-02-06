# Transactions

## Critical Anti-Patterns

### 1. Wrong Isolation Level

**Problem**: Using default isolation level when stronger guarantees needed.

```python
# BAD: Default READ COMMITTED allows non-repeatable reads
async def transfer_money(from_id: int, to_id: int, amount: int):
    async with pool.acquire() as conn:
        async with conn.transaction():
            balance = await conn.fetchval(
                "SELECT balance FROM accounts WHERE id = $1", from_id
            )
            if balance < amount:
                raise ValueError("Insufficient funds")

            # Another transaction could modify balance here!
            await conn.execute(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
                amount, from_id
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
                amount, to_id
            )

# GOOD: Use SERIALIZABLE for critical operations
async def transfer_money(from_id: int, to_id: int, amount: int):
    async with pool.acquire() as conn:
        async with conn.transaction(isolation='serializable'):
            balance = await conn.fetchval(
                "SELECT balance FROM accounts WHERE id = $1", from_id
            )
            if balance < amount:
                raise ValueError("Insufficient funds")

            await conn.execute(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
                amount, from_id
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
                amount, to_id
            )

# BETTER: Use SELECT FOR UPDATE to lock row
async def transfer_money(from_id: int, to_id: int, amount: int):
    async with pool.acquire() as conn:
        async with conn.transaction():
            balance = await conn.fetchval(
                "SELECT balance FROM accounts WHERE id = $1 FOR UPDATE",
                from_id
            )
            if balance < amount:
                raise ValueError("Insufficient funds")

            await conn.execute(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
                amount, from_id
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
                amount, to_id
            )
```

**Isolation Levels**:
- `READ COMMITTED` (default): Prevents dirty reads, allows non-repeatable reads
- `REPEATABLE READ`: Prevents dirty and non-repeatable reads
- `SERIALIZABLE`: Full isolation, prevents all anomalies

### 2. Long-Running Transactions

**Problem**: Holds locks, blocks other queries, bloats WAL.

```python
# BAD: Long transaction holding locks
async def process_orders():
    async with pool.acquire() as conn:
        async with conn.transaction():
            orders = await conn.fetch("SELECT * FROM orders WHERE status = 'pending'")

            for order in orders:
                # External API call inside transaction!
                result = await external_api.process(order)

                await conn.execute(
                    "UPDATE orders SET status = $1, result = $2 WHERE id = $3",
                    'processed', result, order['id']
                )

# GOOD: Keep transactions short
async def process_orders():
    async with pool.acquire() as conn:
        orders = await conn.fetch("SELECT * FROM orders WHERE status = 'pending'")

    # Process outside transaction
    for order in orders:
        result = await external_api.process(order)

        async with pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute(
                    "UPDATE orders SET status = $1, result = $2 WHERE id = $3",
                    'processed', result, order['id']
                )
```

### 3. Deadlocks from Lock Order

**Problem**: Different transactions acquire locks in different orders.

```python
# BAD: Different lock order causes deadlocks
# Transaction 1
async with conn.transaction():
    await conn.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
    await conn.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")

# Transaction 2 (at same time)
async with conn.transaction():
    await conn.execute("UPDATE accounts SET balance = balance - 50 WHERE id = 2")
    await conn.execute("UPDATE accounts SET balance = balance + 50 WHERE id = 1")
# DEADLOCK: T1 locks account 1, T2 locks account 2, both wait for each other

# GOOD: Always acquire locks in same order
async def transfer(from_id: int, to_id: int, amount: int):
    # Always lock lower ID first
    first_id, second_id = sorted([from_id, to_id])

    async with conn.transaction():
        # Lock in consistent order
        await conn.execute(
            "SELECT id FROM accounts WHERE id IN ($1, $2) ORDER BY id FOR UPDATE",
            first_id, second_id
        )

        if from_id < to_id:
            await conn.execute(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
                amount, from_id
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
                amount, to_id
            )
        else:
            await conn.execute(
                "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
                amount, to_id
            )
            await conn.execute(
                "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
                amount, from_id
            )
```

### 4. Not Using Advisory Locks

**Problem**: Application-level coordination requires database support.

```python
# BAD: Race condition on external resource
async def process_unique_job(job_id: int):
    async with pool.acquire() as conn:
        job = await conn.fetchrow("SELECT * FROM jobs WHERE id = $1", job_id)

        if job['status'] == 'pending':
            # Another process could process same job!
            result = await expensive_operation(job)

            await conn.execute(
                "UPDATE jobs SET status = 'complete', result = $1 WHERE id = $2",
                result, job_id
            )

# GOOD: Use advisory lock
async def process_unique_job(job_id: int):
    async with pool.acquire() as conn:
        # Try to acquire advisory lock (non-blocking)
        locked = await conn.fetchval(
            "SELECT pg_try_advisory_lock($1)",
            job_id
        )

        if not locked:
            return  # Another process is handling this job

        try:
            job = await conn.fetchrow("SELECT * FROM jobs WHERE id = $1", job_id)

            if job['status'] == 'pending':
                result = await expensive_operation(job)

                await conn.execute(
                    "UPDATE jobs SET status = 'complete', result = $1 WHERE id = $2",
                    result, job_id
                )
        finally:
            # Release advisory lock
            await conn.execute("SELECT pg_advisory_unlock($1)", job_id)
```

**Advisory Lock Functions**:
- `pg_advisory_lock(key)`: Blocking lock
- `pg_try_advisory_lock(key)`: Non-blocking, returns true/false
- `pg_advisory_unlock(key)`: Release lock
- `pg_advisory_xact_lock(key)`: Auto-released at transaction end

### 5. Not Handling Serialization Failures

**Problem**: SERIALIZABLE transactions can fail and need retry.

```python
# BAD: No retry on serialization failure
async def increment_counter(counter_id: int):
    async with pool.acquire() as conn:
        async with conn.transaction(isolation='serializable'):
            count = await conn.fetchval(
                "SELECT count FROM counters WHERE id = $1", counter_id
            )
            await conn.execute(
                "UPDATE counters SET count = $1 WHERE id = $2",
                count + 1, counter_id
            )
    # Raises SerializationError under contention

# GOOD: Retry on serialization failure
import asyncpg

async def increment_counter(counter_id: int, max_retries: int = 3):
    for attempt in range(max_retries):
        try:
            async with pool.acquire() as conn:
                async with conn.transaction(isolation='serializable'):
                    count = await conn.fetchval(
                        "SELECT count FROM counters WHERE id = $1", counter_id
                    )
                    await conn.execute(
                        "UPDATE counters SET count = $1 WHERE id = $2",
                        count + 1, counter_id
                    )
            return  # Success
        except asyncpg.SerializationError:
            if attempt == max_retries - 1:
                raise
            # Retry with exponential backoff
            await asyncio.sleep(0.1 * (2 ** attempt))
```

### 6. Missing ROLLBACK on Error

**Problem**: Transaction left open on error, holds locks.

```python
# BAD: Transaction not rolled back on error
conn = pool.getconn()
cursor = conn.cursor()
cursor.execute("BEGIN")
try:
    cursor.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
    # Error here leaves transaction open!
    cursor.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
    conn.commit()
finally:
    pool.putconn(conn)

# GOOD: Use context manager (auto rollback)
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        await conn.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
    # Automatically rolls back on exception

# GOOD: Explicit rollback
conn = pool.getconn()
try:
    cursor = conn.cursor()
    cursor.execute("BEGIN")
    try:
        cursor.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
        cursor.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
finally:
    pool.putconn(conn)
```

### 7. Nested Transactions Without Savepoints

**Problem**: Inner "transaction" doesn't actually create nested transaction.

```python
# BAD: Nested transaction blocks don't work as expected
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("INSERT INTO logs (message) VALUES ('start')")

        try:
            async with conn.transaction():  # This doesn't create nested transaction!
                await conn.execute("INSERT INTO data (value) VALUES (123)")
                raise ValueError("Error")
        except ValueError:
            pass  # Expect outer transaction to continue

        await conn.execute("INSERT INTO logs (message) VALUES ('end')")
# Entire transaction is rolled back, including 'start' log

# GOOD: Use savepoints for nested transactions
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("INSERT INTO logs (message) VALUES ('start')")

        try:
            # Create savepoint
            await conn.execute("SAVEPOINT inner")
            await conn.execute("INSERT INTO data (value) VALUES (123)")
            raise ValueError("Error")
        except ValueError:
            # Rollback to savepoint
            await conn.execute("ROLLBACK TO SAVEPOINT inner")

        await conn.execute("INSERT INTO logs (message) VALUES ('end')")
# Both logs are committed, data insert is rolled back
```

### 8. Not Using FOR UPDATE SKIP LOCKED

**Problem**: Queue processing blocked by locked rows.

```python
# BAD: Workers block on locked rows
async def process_next_job():
    async with pool.acquire() as conn:
        async with conn.transaction():
            # Blocks if another worker locked this row
            job = await conn.fetchrow("""
                SELECT * FROM jobs
                WHERE status = 'pending'
                ORDER BY created_at
                LIMIT 1
                FOR UPDATE
            """)

            if job:
                await process_job(job)
                await conn.execute(
                    "UPDATE jobs SET status = 'complete' WHERE id = $1",
                    job['id']
                )

# GOOD: Skip locked rows
async def process_next_job():
    async with pool.acquire() as conn:
        async with conn.transaction():
            # Skip rows locked by other workers
            job = await conn.fetchrow("""
                SELECT * FROM jobs
                WHERE status = 'pending'
                ORDER BY created_at
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            """)

            if job:
                await process_job(job)
                await conn.execute(
                    "UPDATE jobs SET status = 'complete' WHERE id = $1",
                    job['id']
                )
```

## Review Questions

1. Is the isolation level appropriate for the operation?
2. Are transactions kept short (no I/O inside)?
3. Are locks always acquired in consistent order to prevent deadlocks?
4. Would advisory locks help with application-level coordination?
5. Are serialization failures caught and retried?
6. Are transactions properly rolled back on error (context managers)?
7. Are savepoints used for nested transaction semantics?
8. Is `FOR UPDATE SKIP LOCKED` used for queue processing?
