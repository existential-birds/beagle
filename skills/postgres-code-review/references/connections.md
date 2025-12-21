# Connections

## Critical Anti-Patterns

### 1. Not Using Connection Pooling

**Problem**: Creating new connection per request is slow and exhausts database connections.

```python
# BAD: New connection every time
def get_user(user_id: int):
    conn = psycopg2.connect(
        host='localhost',
        database='mydb',
        user='user',
        password='password'
    )
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    result = cursor.fetchone()
    conn.close()
    return result

# GOOD: Use connection pool
from psycopg2.pool import ThreadedConnectionPool

pool = ThreadedConnectionPool(
    minconn=5,
    maxconn=20,
    host='localhost',
    database='mydb',
    user='user',
    password='password'
)

def get_user(user_id: int):
    conn = pool.getconn()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        return cursor.fetchone()
    finally:
        pool.putconn(conn)
```

### 2. Connection Leaks

**Problem**: Not releasing connections back to pool causes starvation.

```python
# BAD: Connection leaked on error
def get_user(user_id: int):
    conn = pool.getconn()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    result = cursor.fetchone()
    pool.putconn(conn)  # Not called if error occurs!
    return result

# GOOD: Always release in finally block
def get_user(user_id: int):
    conn = pool.getconn()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        return cursor.fetchone()
    finally:
        pool.putconn(conn)

# BETTER: Use context manager
from contextlib import contextmanager

@contextmanager
def get_db_connection():
    conn = pool.getconn()
    try:
        yield conn
    finally:
        pool.putconn(conn)

def get_user(user_id: int):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        return cursor.fetchone()
```

### 3. Wrong Pool Size

**Problem**: Pool too small (connection starvation) or too large (resource waste).

```python
# BAD: Pool size not based on workload
pool = ThreadedConnectionPool(minconn=1, maxconn=100)

# GOOD: Size based on concurrent requests and database limits
# Rule of thumb: (num_cores * 2) + effective_spindle_count
# For web server: match number of worker threads/processes
pool = ThreadedConnectionPool(
    minconn=5,   # Keep warm connections
    maxconn=20,  # Max concurrent requests
    host='localhost',
    database='mydb'
)

# Check PostgreSQL connection limit
# SHOW max_connections;  -- Default 100
# Ensure pool max < max_connections across all app instances
```

### 4. No Connection Timeout

**Problem**: Application hangs waiting for connections.

```python
# BAD: No timeout, hangs indefinitely
pool = ThreadedConnectionPool(minconn=5, maxconn=20)
conn = pool.getconn()  # Blocks forever if pool exhausted

# GOOD: Use timeout
pool = ThreadedConnectionPool(minconn=5, maxconn=20)
conn = pool.getconn(timeout=5)  # Raises error after 5 seconds
if conn is None:
    raise Exception("Could not get database connection")

# BETTER: Use asyncpg with async/await
import asyncpg

pool = await asyncpg.create_pool(
    host='localhost',
    database='mydb',
    min_size=5,
    max_size=20,
    timeout=5,
    command_timeout=30  # Query timeout
)

async def get_user(user_id: int):
    async with pool.acquire() as conn:
        return await conn.fetchrow(
            "SELECT * FROM users WHERE id = $1",
            user_id
        )
```

### 5. Not Setting Statement Timeout

**Problem**: Long-running queries hold connections and locks.

```python
# BAD: No query timeout
async def expensive_query():
    async with pool.acquire() as conn:
        # Could run for hours, holding connection
        return await conn.fetch("SELECT * FROM huge_table")

# GOOD: Set statement timeout
async def expensive_query():
    async with pool.acquire() as conn:
        await conn.execute("SET statement_timeout = '30s'")
        try:
            return await conn.fetch("SELECT * FROM huge_table")
        except asyncpg.QueryCanceledError:
            raise TimeoutError("Query took too long")

# BETTER: Set at connection level
pool = await asyncpg.create_pool(
    host='localhost',
    database='mydb',
    command_timeout=30,  # 30 second timeout for all queries
    server_settings={'statement_timeout': '30000'}  # milliseconds
)
```

### 6. Not Using PgBouncer

**Problem**: Application connection pool doesn't reduce database connections.

```yaml
# BAD: Each app instance has its own pool
# 3 app servers * 20 connections = 60 database connections

# GOOD: Use PgBouncer for connection pooling
# pgbouncer.ini
[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_addr = *
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction  # or session
max_client_conn = 1000   # Application connections
default_pool_size = 20   # Database connections
reserve_pool_size = 5
```

```python
# Application connects to PgBouncer instead of PostgreSQL
pool = await asyncpg.create_pool(
    host='localhost',
    port=6432,  # PgBouncer port
    database='mydb'
)
# Now 3 app servers * 20 connections = 60 app connections
# But only 20 database connections via PgBouncer
```

### 7. Holding Connections During I/O

**Problem**: Holding database connection while doing network/file I/O.

```python
# BAD: Holding connection during API call
async def process_user(user_id: int):
    async with pool.acquire() as conn:
        user = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)

        # Holding connection during external API call!
        async with httpx.AsyncClient() as client:
            response = await client.get(f"https://api.example.com/users/{user_id}")

        await conn.execute(
            "UPDATE users SET api_data = $1 WHERE id = $2",
            response.json(), user_id
        )

# GOOD: Release connection during I/O
async def process_user(user_id: int):
    async with pool.acquire() as conn:
        user = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)

    # Connection released during API call
    async with httpx.AsyncClient() as client:
        response = await client.get(f"https://api.example.com/users/{user_id}")

    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET api_data = $1 WHERE id = $2",
            response.json(), user_id
        )
```

### 8. Not Monitoring Connection Pool

**Problem**: Can't diagnose connection starvation or leaks.

```python
# BAD: No visibility into pool state
pool = ThreadedConnectionPool(minconn=5, maxconn=20)

# GOOD: Monitor pool metrics
import logging

logger = logging.getLogger(__name__)

@contextmanager
def get_db_connection():
    logger.info(f"Pool: {pool._used}/{pool._maxconn} connections used")
    conn = pool.getconn()
    try:
        yield conn
    finally:
        pool.putconn(conn)

# BETTER: Use metrics library
from prometheus_client import Gauge

db_connections_used = Gauge('db_connections_used', 'Database connections in use')
db_connections_max = Gauge('db_connections_max', 'Max database connections')

@contextmanager
def get_db_connection():
    conn = pool.getconn()
    db_connections_used.inc()
    try:
        yield conn
    finally:
        pool.putconn(conn)
        db_connections_used.dec()

db_connections_max.set(pool._maxconn)
```

## Review Questions

1. Is connection pooling used?
2. Are connections always released (try/finally or context manager)?
3. Is pool size appropriate for workload?
4. Are connection and statement timeouts configured?
5. Would PgBouncer help reduce database connections?
6. Are connections released during I/O operations?
7. Is connection pool health monitored?
8. Are connection errors handled and logged?
