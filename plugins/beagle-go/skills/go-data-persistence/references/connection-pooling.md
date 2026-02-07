# Connection Pooling in Go

## How database/sql Pooling Works

Go's `database/sql` package manages a pool of connections internally. When you call `db.QueryContext()` or `db.ExecContext()`, the pool:

1. Checks for an available idle connection
2. If none available and under `MaxOpenConns`, creates a new connection
3. If at `MaxOpenConns`, blocks until a connection is returned to the pool
4. After the query completes, returns the connection to the idle pool
5. If the idle pool is full (`MaxIdleConns`), closes the connection instead

This means `sql.Open()` does not actually open a connection -- it only validates the DSN and prepares the pool. The first real connection happens on the first query or `Ping()`.

### Pool Lifecycle

```
Request arrives
    |
    v
Pool has idle conn? --yes--> Use it --> Return to idle pool
    |                                        |
    no                                  Idle pool full?
    |                                   /          \
    v                                 yes           no
Under MaxOpenConns?                Close conn    Keep idle
    |          |
   yes         no
    |          |
    v          v
Open new     Block until
connection   one is returned
```

## Sizing Guidelines

### Formula

```
MaxOpenConns = (DB max_connections - reserved_connections) / app_instances
```

Where:
- `max_connections` is the database server's maximum connection limit (check with `SHOW max_connections` in PostgreSQL)
- `reserved_connections` are connections reserved for superuser access, replication, monitoring, and migrations (typically 10-20)
- `app_instances` is the number of running application replicas

### Workload-Based Sizing

| Workload Type | MaxOpenConns | MaxIdleConns | Notes |
|---------------|-------------|-------------|-------|
| Low-traffic API (< 100 rps) | 10 | 5 | Minimal resources |
| Typical web app (100-1000 rps) | 25 | 10 | Good default |
| High-traffic service (1000+ rps) | 50-100 | 20-40 | Monitor DB CPU |
| Background worker | 5-10 | 2-5 | Few concurrent queries |
| Batch processing | 10-25 | 5-10 | Depends on parallelism |

### Important Considerations

- More connections does not mean more throughput. PostgreSQL performance degrades significantly above ~100 active connections due to lock contention and context switching.
- If your app needs more than ~50 connections per instance, consider using PgBouncer or a similar connection pooler between your app and the database.
- Monitor actual connection usage before tuning. Use `db.Stats()` to check pool utilization.

## pgx Native Pooling

For PostgreSQL-only applications, use `pgxpool.Pool` instead of `database/sql`. It provides better performance, native PostgreSQL protocol support, and additional features like health checks.

```go
import (
    "context"
    "fmt"
    "os"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
)

func NewPool(ctx context.Context) (*pgxpool.Pool, error) {
    config, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
    if err != nil {
        return nil, fmt.Errorf("parsing db config: %w", err)
    }

    config.MaxConns = 25
    config.MinConns = 5
    config.MaxConnLifetime = 5 * time.Minute
    config.MaxConnIdleTime = 1 * time.Minute
    config.HealthCheckPeriod = 30 * time.Second

    pool, err := pgxpool.NewWithConfig(ctx, config)
    if err != nil {
        return nil, fmt.Errorf("creating pool: %w", err)
    }

    return pool, nil
}
```

### pgxpool vs database/sql

| Feature | pgxpool.Pool | database/sql |
|---------|-------------|-------------|
| Protocol | Native PostgreSQL | Generic driver interface |
| Performance | Faster (no interface overhead) | Slightly slower |
| MinConns | Supported | Not available |
| Health checks | Built-in periodic | Manual via Ping |
| COPY protocol | Native support | Not available |
| LISTEN/NOTIFY | Native support | Driver-dependent |
| Multi-database | PostgreSQL only | Any database |
| Ecosystem | pgx-specific | Universal Go packages |

### pgx with database/sql Compatibility

If you need `database/sql` compatibility (for libraries that require it) but still want pgx as the driver:

```go
import (
    "database/sql"

    _ "github.com/jackc/pgx/v5/stdlib"
)

func NewDB(connStr string) (*sql.DB, error) {
    db, err := sql.Open("pgx", connStr)
    if err != nil {
        return nil, fmt.Errorf("opening db: %w", err)
    }

    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(10)
    db.SetConnMaxLifetime(5 * time.Minute)
    db.SetConnMaxIdleTime(1 * time.Minute)

    return db, nil
}
```

## Health Checks and Connection Validation

### pgxpool Health Checks

`pgxpool` performs automatic health checks on idle connections at the interval set by `HealthCheckPeriod`. This detects broken connections (network failures, database restarts) before they are used for a real query.

```go
config.HealthCheckPeriod = 30 * time.Second
```

If a health check fails, the connection is removed from the pool and a new one is created on demand.

### Manual Health Check Endpoint

Expose a health check endpoint that verifies database connectivity:

```go
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
    defer cancel()

    if err := s.db.PingContext(ctx); err != nil {
        http.Error(w, "database unreachable", http.StatusServiceUnavailable)
        return
    }

    w.WriteHeader(http.StatusOK)
    w.Write([]byte("ok"))
}
```

Use a short timeout (1-2 seconds) for health check pings. If the database does not respond within that window, the instance should be marked unhealthy.

## Monitoring Pool Metrics

### database/sql Stats

```go
func (s *Server) handleDBStats(w http.ResponseWriter, r *http.Request) {
    stats := s.db.Stats()

    fmt.Fprintf(w, "Open connections: %d\n", stats.OpenConnections)
    fmt.Fprintf(w, "In use: %d\n", stats.InUse)
    fmt.Fprintf(w, "Idle: %d\n", stats.Idle)
    fmt.Fprintf(w, "Wait count: %d\n", stats.WaitCount)
    fmt.Fprintf(w, "Wait duration: %s\n", stats.WaitDuration)
    fmt.Fprintf(w, "Max idle closed: %d\n", stats.MaxIdleClosed)
    fmt.Fprintf(w, "Max lifetime closed: %d\n", stats.MaxLifetimeClosed)
}
```

### Key Metrics to Watch

| Metric | Healthy | Warning |
|--------|---------|---------|
| `WaitCount` | Low/zero | Increasing over time |
| `WaitDuration` | < 10ms avg | > 100ms avg |
| `InUse` | < 80% of MaxOpenConns | Consistently near max |
| `MaxIdleClosed` | Low | Very high (raise MaxIdleConns) |
| `MaxLifetimeClosed` | Proportional to traffic | Unexpectedly high |

If `WaitCount` is steadily increasing, your application is running out of connections. Either increase `MaxOpenConns` (if the database can handle it) or reduce query duration.

### Prometheus Integration

```go
import "github.com/prometheus/client_golang/prometheus"

func registerDBMetrics(db *sql.DB) {
    prometheus.MustRegister(prometheus.NewGaugeFunc(
        prometheus.GaugeOpts{
            Name: "db_open_connections",
            Help: "Number of open database connections",
        },
        func() float64 { return float64(db.Stats().OpenConnections) },
    ))

    prometheus.MustRegister(prometheus.NewGaugeFunc(
        prometheus.GaugeOpts{
            Name: "db_in_use_connections",
            Help: "Number of in-use database connections",
        },
        func() float64 { return float64(db.Stats().InUse) },
    ))

    prometheus.MustRegister(prometheus.NewGaugeFunc(
        prometheus.GaugeOpts{
            Name: "db_idle_connections",
            Help: "Number of idle database connections",
        },
        func() float64 { return float64(db.Stats().Idle) },
    ))

    prometheus.MustRegister(prometheus.NewCounterFunc(
        prometheus.CounterOpts{
            Name: "db_wait_count_total",
            Help: "Total number of connections waited for",
        },
        func() float64 { return float64(db.Stats().WaitCount) },
    ))
}
```

### pgxpool Stats

```go
func logPoolStats(pool *pgxpool.Pool) {
    stat := pool.Stat()

    slog.Info("pool stats",
        "total_conns", stat.TotalConns(),
        "acquired_conns", stat.AcquiredConns(),
        "idle_conns", stat.IdleConns(),
        "constructing_conns", stat.ConstructingConns(),
        "max_conns", stat.MaxConns(),
        "new_conns_count", stat.NewConnsCount(),
        "max_lifetime_destroy_count", stat.MaxLifetimeDestroyCount(),
        "max_idle_destroy_count", stat.MaxIdleDestroyCount(),
    )
}
```

## Cloud Database Considerations

### Connection Limits by Provider

| Provider | Free/Dev Tier | Standard | Notes |
|----------|-------------|----------|-------|
| AWS RDS (db.t3.micro) | 87 | Scales with instance | Based on instance memory |
| Google Cloud SQL | 25 (basic) | Up to 4000 | Depends on tier |
| Supabase | 60 (free) | 200-500 | Uses PgBouncer |
| Neon | 100 (free) | 300-500 | Serverless, auto-scales |
| Railway | Varies | Varies | Shared resources on free |

### PgBouncer

When using PgBouncer (common in managed PostgreSQL services like Supabase), adjust your application settings:

```go
// With PgBouncer in transaction mode
db.SetMaxOpenConns(50)  // Can be higher -- PgBouncer multiplexes
db.SetMaxIdleConns(5)   // Keep low -- PgBouncer handles idle
db.SetConnMaxLifetime(0) // Disable -- PgBouncer manages lifetime
```

Important PgBouncer considerations:
- **Transaction pooling mode** (most common): connections are assigned per transaction, not per session. Prepared statements do not work across transactions.
- **Session pooling mode**: connections are assigned per session. Prepared statements work normally but you get less multiplexing benefit.
- If using pgx with PgBouncer in transaction mode, disable prepared statements:

```go
config, _ := pgxpool.ParseConfig(connStr)
config.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
```

### DNS-Based Failover

Cloud databases often use DNS to point to the current primary. Set `ConnMaxLifetime` to a short value so your application picks up DNS changes after failover:

```go
db.SetConnMaxLifetime(1 * time.Minute) // Short lifetime for fast failover
```

Without this, long-lived connections may keep pointing to the old primary after a failover event, causing errors.
