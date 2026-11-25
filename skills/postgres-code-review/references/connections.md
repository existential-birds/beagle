# Connections

## Critical Anti-Patterns

### 1. Not Using Connection Pooling

**Problem**: Opening a fresh TCP/TLS connection per request adds latency and exhausts PostgreSQL `max_connections`.

```python
# BAD: New connection every time
import psycopg

def get_user(user_id: int):
    with psycopg.connect("postgresql://user:pass@localhost/mydb") as conn:
        return conn.execute(
            "SELECT * FROM users WHERE id = %s", (user_id,)
        ).fetchone()

# GOOD: Use psycopg_pool ConnectionPool (psycopg 3)
from psycopg_pool import ConnectionPool

pool = ConnectionPool(
    conninfo="postgresql://user:pass@localhost/mydb",
    min_size=5,
    max_size=20,
    timeout=5.0,
)

def get_user(user_id: int):
    with pool.connection() as conn:
        return conn.execute(
            "SELECT * FROM users WHERE id = %s", (user_id,)
        ).fetchone()
```

### 2. Connection Leaks (Manual Checkout Without Context Manager)

**Problem**: Manually checking out connections without `with` / `try`/`finally` leaks connections on exceptions.

```python
# BAD: Connection leaked if query raises
conn = pool.getconn()
row = conn.execute("SELECT * FROM users WHERE id = %s", (user_id,)).fetchone()
pool.putconn(conn)

# GOOD: Context manager guarantees return to pool (sync or async)
from psycopg_pool import AsyncConnectionPool

async_pool = AsyncConnectionPool(
    conninfo="postgresql://user:pass@localhost/mydb",
    min_size=5,
    max_size=20,
    open=False,  # Open explicitly in app lifespan
)

async def get_user(user_id: int):
    async with async_pool.connection() as conn:
        cur = await conn.execute(
            "SELECT * FROM users WHERE id = %s", (user_id,)
        )
        return await cur.fetchone()
```

### 3. Wrong Pool Size

**Problem**: Oversized pools cause lock/CPU thrashing across app replicas; undersized pools starve requests.

```python
# BAD: Arbitrary huge pool across many app replicas
pool = ConnectionPool(conninfo=DSN, min_size=1, max_size=100)

# GOOD: Size total connections across all app workers < PostgreSQL max_connections
# Check PostgreSQL limit: SHOW max_connections;
pool = ConnectionPool(
    conninfo=DSN,
    min_size=5,
    max_size=20,
    timeout=5.0,
)
```

### 4. Missing Connection & Acquisition Timeouts

**Problem**: Unbounded connection acquisition hangs request workers indefinitely under pool exhaustion.

```python
# BAD: Default or infinite wait on pool exhaustion / connect
pool = await asyncpg.create_pool(dsn=DSN, min_size=5, max_size=20)
conn = await pool.acquire()  # No timeout!

# GOOD: Explicit acquire timeout and query command_timeout
import asyncpg
from psycopg_pool import PoolTimeout

async_pg_pool = await asyncpg.create_pool(
    dsn=DSN,
    min_size=5,
    max_size=20,
    timeout=5.0,          # Connect / acquire timeout
    command_timeout=30.0, # Per-query timeout
)

async def get_user(user_id: int):
    async with async_pg_pool.acquire(timeout=5.0) as conn:
        return await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)

# With psycopg_pool, catch PoolTimeout explicitly when pool is saturated
def fetch_safe(user_id: int):
    try:
        with pool.connection(timeout=5.0) as conn:
            return conn.execute("SELECT * FROM users WHERE id = %s", (user_id,)).fetchone()
    except PoolTimeout as exc:
        raise TimeoutError("Database connection pool exhausted") from exc
```

### 5. Not Setting Statement Timeout

**Problem**: Runaway queries hold connections, CPU, and table locks for minutes or hours.

```python
# BAD: Unbounded query execution
async with async_pg_pool.acquire() as conn:
    return await conn.fetch("SELECT * FROM huge_table")

# GOOD: Set statement_timeout at pool/connection level
async_pg_pool = await asyncpg.create_pool(
    dsn=DSN,
    command_timeout=30.0,
    server_settings={"statement_timeout": "30000"},  # milliseconds
)

# Or per transaction with SET LOCAL (safe with transaction pooling!)
async with async_pg_pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute("SET LOCAL statement_timeout = '30s'")
        return await conn.fetch("SELECT * FROM huge_table")
```

### 6. PgBouncer Configuration & Prepared Statement Conflicts

**Problem**: Direct per-instance pools exhaust PostgreSQL `max_connections` at scale; PgBouncer `pool_mode = transaction` breaks session-bound prepared statements unless disabled (or using PgBouncer 1.22+ protocol support) and `md5` auth is deprecated in favor of `scram-sha-256`.

```ini
# GOOD: PgBouncer with scram-sha-256 and transaction pooling
[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_addr = *
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
reserve_pool_size = 5
```

```python
# IMPORTANT for PgBouncer transaction pooling (especially PgBouncer < 1.22):
# Disable client-side automatic prepared statements to avoid "prepared statement does not exist"

# psycopg 3: set prepare_threshold=None (default is 5)
pg_pool = AsyncConnectionPool(
    conninfo="postgresql://user:pass@localhost:6432/mydb",
    kwargs={"prepare_threshold": None},
    min_size=5,
    max_size=20,
    open=False,
)

# asyncpg: set statement_cache_size=0
asyncpg_pool = await asyncpg.create_pool(
    host="localhost",
    port=6432,
    database="mydb",
    statement_cache_size=0,
)
```

### 7. Holding Connections During External I/O

**Problem**: Keeping a DB connection checked out across HTTP/file I/O starves the pool.

```python
# BAD: Holding connection during external HTTP call
async def process_user(user_id: int):
    async with asyncpg_pool.acquire() as conn:
        user = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"https://api.example.com/users/{user_id}")
        await conn.execute(
            "UPDATE users SET api_data = $1 WHERE id = $2",
            response.json(),
            user_id,
        )

# GOOD: Release connection before external I/O, reacquire to persist
async def process_user(user_id: int):
    async with asyncpg_pool.acquire() as conn:
        user = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(f"https://api.example.com/users/{user_id}")

    async with asyncpg_pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET api_data = $1 WHERE id = $2",
            response.json(),
            user_id,
        )
```

### 8. Not Monitoring Connection Pool Health

**Problem**: Relying on private attributes (`_used`, `_maxconn`) or having zero pool visibility masks pool saturation.

```python
# BAD: Accessing private attributes on legacy pools
# logger.info(f"{pool._used}/{pool._maxconn}")

# GOOD: Use psycopg_pool public get_stats() and ConnectionPool.check_connection
import logging
from psycopg_pool import ConnectionPool

logger = logging.getLogger(__name__)

pool = ConnectionPool(
    conninfo=DSN,
    min_size=5,
    max_size=20,
    check=ConnectionPool.check_connection,
)

def log_pool_stats() -> None:
    stats = pool.get_stats()
    logger.info(
        "DB pool stats: size=%s available=%s waiting=%s",
        stats.get("pool_size", 0),
        stats.get("pool_available", 0),
        stats.get("requests_waiting", 0),
    )
```

## Review Questions

1. Is connection pooling (`psycopg_pool` or `asyncpg.create_pool`) used instead of per-request connections?
2. Are connections always released via `with` / `async with`?
3. Are connection acquisition and statement timeouts configured (`timeout`, `command_timeout`, `SET LOCAL statement_timeout`)?
4. When using PgBouncer in `transaction` mode, is `auth_type = scram-sha-256` used and are prepared statements handled (`prepare_threshold=None` / `statement_cache_size=0`)?
5. Are connections released during external HTTP/file I/O?
6. Is pool health monitored via public APIs (`pool.get_stats()`)?
