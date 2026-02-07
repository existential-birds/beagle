# Transaction Management in Go

## Why Service-Layer Transactions

Transactions should be managed at the **service layer**, not the store (repository) layer. The service layer knows which operations must be atomic. Individual store methods should not start their own transactions because:

- The caller cannot compose multiple store operations into a single transaction
- Each store method would commit independently, breaking atomicity
- Error handling becomes inconsistent -- some operations commit, others roll back

The pattern: the service begins a transaction, passes it to store methods, and commits or rolls back based on the outcome of all operations.

## Basic Transaction Pattern

```go
func transferFunds(ctx context.Context, db *sql.DB, from, to string, amount int64) error {
    tx, err := db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("beginning transaction: %w", err)
    }

    // Debit source account
    _, err = tx.ExecContext(ctx,
        "UPDATE accounts SET balance = balance - $1 WHERE id = $2 AND balance >= $1",
        amount, from,
    )
    if err != nil {
        tx.Rollback()
        return fmt.Errorf("debiting account: %w", err)
    }

    // Credit destination account
    _, err = tx.ExecContext(ctx,
        "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
        amount, to,
    )
    if err != nil {
        tx.Rollback()
        return fmt.Errorf("crediting account: %w", err)
    }

    return tx.Commit()
}
```

This works but has problems: repetitive rollback handling, and forgetting `tx.Rollback()` on any error path causes a connection leak.

## Transaction Helper Function

Encapsulate the begin/commit/rollback lifecycle in a helper:

```go
func WithTx(ctx context.Context, db *sql.DB, fn func(tx *sql.Tx) error) error {
    tx, err := db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("beginning transaction: %w", err)
    }

    if err := fn(tx); err != nil {
        if rbErr := tx.Rollback(); rbErr != nil {
            return fmt.Errorf("rollback failed: %v (original error: %w)", rbErr, err)
        }
        return err
    }

    return tx.Commit()
}
```

### With Custom Isolation Level

```go
func WithTxOptions(ctx context.Context, db *sql.DB, opts *sql.TxOptions, fn func(tx *sql.Tx) error) error {
    tx, err := db.BeginTx(ctx, opts)
    if err != nil {
        return fmt.Errorf("beginning transaction: %w", err)
    }

    if err := fn(tx); err != nil {
        if rbErr := tx.Rollback(); rbErr != nil {
            return fmt.Errorf("rollback failed: %v (original error: %w)", rbErr, err)
        }
        return err
    }

    return tx.Commit()
}

// Usage with serializable isolation
err := WithTxOptions(ctx, db, &sql.TxOptions{
    Isolation: sql.LevelSerializable,
}, func(tx *sql.Tx) error {
    // operations that require serializable isolation
    return nil
})
```

## Service-Layer Transactions

The service layer coordinates multiple store operations within a single transaction:

```go
type OrderService struct {
    db             *sql.DB
    orderStore     *OrderStore
    inventoryStore *InventoryStore
    paymentStore   *PaymentStore
}

func (s *OrderService) PlaceOrder(ctx context.Context, order *Order) error {
    return WithTx(ctx, s.db, func(tx *sql.Tx) error {
        // All operations share the same transaction
        if err := s.orderStore.CreateWithTx(ctx, tx, order); err != nil {
            return fmt.Errorf("creating order: %w", err)
        }

        if err := s.inventoryStore.DecrementWithTx(ctx, tx, order.Items); err != nil {
            return fmt.Errorf("updating inventory: %w", err)
        }

        if err := s.paymentStore.ChargeWithTx(ctx, tx, order.Payment); err != nil {
            return fmt.Errorf("charging payment: %w", err)
        }

        return nil
    })
}
```

## Store Pattern Accepting Transactions

Store methods should accept a transaction parameter so they can participate in caller-controlled transactions:

```go
type OrderStore struct{}

func (s *OrderStore) CreateWithTx(ctx context.Context, tx *sql.Tx, order *Order) error {
    _, err := tx.ExecContext(ctx,
        "INSERT INTO orders (id, user_id, total) VALUES ($1, $2, $3)",
        order.ID, order.UserID, order.Total,
    )
    return err
}
```

### Dual Interface Pattern

Some store methods need to work both with and without an explicit transaction. Use an interface that both `*sql.DB` and `*sql.Tx` satisfy:

```go
// DBTX is satisfied by both *sql.DB and *sql.Tx
type DBTX interface {
    ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
    QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
    QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

type UserStore struct {
    db DBTX
}

func NewUserStore(db DBTX) *UserStore {
    return &UserStore{db: db}
}

func (s *UserStore) GetUser(ctx context.Context, id string) (*User, error) {
    var u User
    err := s.db.QueryRowContext(ctx,
        "SELECT id, email, name FROM users WHERE id = $1", id,
    ).Scan(&u.ID, &u.Email, &u.Name)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, ErrNotFound
    }
    return &u, err
}

// Usage without transaction
store := NewUserStore(db)
user, err := store.GetUser(ctx, "123")

// Usage within transaction
WithTx(ctx, db, func(tx *sql.Tx) error {
    store := NewUserStore(tx)
    user, err := store.GetUser(ctx, "123")
    // ...
    return nil
})
```

## Context-Based Transaction Propagation

For deeply nested call chains, propagate the transaction through context:

```go
type ctxKey struct{}

// TxFromContext retrieves a transaction from context, if present.
func TxFromContext(ctx context.Context) *sql.Tx {
    tx, _ := ctx.Value(ctxKey{}).(*sql.Tx)
    return tx
}

// ContextWithTx stores a transaction in the context.
func ContextWithTx(ctx context.Context, tx *sql.Tx) context.Context {
    return context.WithValue(ctx, ctxKey{}, tx)
}

// Store uses transaction from context if available, otherwise uses db.
func (s *UserStore) GetUser(ctx context.Context, id string) (*User, error) {
    var querier DBTX = s.db
    if tx := TxFromContext(ctx); tx != nil {
        querier = tx
    }

    var u User
    err := querier.QueryRowContext(ctx,
        "SELECT id, email, name FROM users WHERE id = $1", id,
    ).Scan(&u.ID, &u.Email, &u.Name)
    return &u, err
}
```

Use this pattern sparingly. It makes the transaction boundary less visible in the code. Prefer explicit `*sql.Tx` parameters when the call chain is shallow.

## Isolation Levels

PostgreSQL supports four isolation levels. Choose based on your consistency requirements:

| Level | Dirty Reads | Non-Repeatable Reads | Phantom Reads | Use Case |
|-------|-------------|---------------------|---------------|----------|
| Read Uncommitted | Prevented* | Possible | Possible | Rarely used in PostgreSQL |
| Read Committed (default) | Prevented | Possible | Possible | Most CRUD operations |
| Repeatable Read | Prevented | Prevented | Prevented** | Reports, aggregations |
| Serializable | Prevented | Prevented | Prevented | Financial transactions |

*PostgreSQL treats Read Uncommitted as Read Committed.
**PostgreSQL's Repeatable Read also prevents phantom reads (unlike the SQL standard minimum).

### When to Change Isolation Level

**Read Committed** (default): Suitable for most web application queries. Each statement sees the latest committed data. Use this unless you have a specific reason not to.

**Repeatable Read**: Use when a transaction reads the same data multiple times and needs consistent results (e.g., generating a report where totals must be consistent across queries).

```go
tx, err := db.BeginTx(ctx, &sql.TxOptions{
    Isolation: sql.LevelRepeatableRead,
})
```

**Serializable**: Use for operations where concurrent transactions could produce inconsistent results (e.g., checking inventory and placing an order). Serializable transactions may fail with serialization errors and must be retried.

```go
func PlaceOrderSerializable(ctx context.Context, db *sql.DB, order *Order) error {
    for retries := 0; retries < 3; retries++ {
        err := WithTxOptions(ctx, db, &sql.TxOptions{
            Isolation: sql.LevelSerializable,
        }, func(tx *sql.Tx) error {
            // Check inventory, place order, etc.
            return nil
        })

        if err == nil {
            return nil
        }

        // Check for serialization failure (PostgreSQL error code 40001)
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) && pgErr.Code == "40001" {
            continue // Retry
        }

        return err // Non-retryable error
    }

    return fmt.Errorf("transaction failed after 3 retries")
}
```

## Deadlock Prevention

Deadlocks occur when two transactions wait for each other to release locks. PostgreSQL detects deadlocks and aborts one of the transactions.

### Consistent Lock Ordering

The primary strategy for preventing deadlocks is to always acquire locks in the same order:

```go
// BAD -- Transaction A locks user then order, Transaction B locks order then user
// This can deadlock

// GOOD -- Always lock in the same order (e.g., alphabetical by table, ascending by ID)
func (s *OrderService) PlaceOrder(ctx context.Context, order *Order) error {
    return WithTx(ctx, s.db, func(tx *sql.Tx) error {
        // Sort items by ID to ensure consistent lock ordering
        sort.Slice(order.Items, func(i, j int) bool {
            return order.Items[i].ProductID < order.Items[j].ProductID
        })

        for _, item := range order.Items {
            _, err := tx.ExecContext(ctx,
                "UPDATE inventory SET quantity = quantity - $1 WHERE product_id = $2",
                item.Quantity, item.ProductID,
            )
            if err != nil {
                return err
            }
        }

        return nil
    })
}
```

### Advisory Locks

For application-level locking (e.g., ensuring only one instance processes a job):

```go
func withAdvisoryLock(ctx context.Context, tx *sql.Tx, lockID int64, fn func() error) error {
    // Acquire lock (released when transaction ends)
    _, err := tx.ExecContext(ctx, "SELECT pg_advisory_xact_lock($1)", lockID)
    if err != nil {
        return fmt.Errorf("acquiring advisory lock: %w", err)
    }

    return fn()
}
```

## Long-Running Transactions

Long-running transactions hold connections from the pool and can cause problems:

- **Connection starvation**: Other requests wait for a connection while the transaction holds one
- **Lock contention**: Rows locked by the transaction block other writes
- **WAL bloat**: PostgreSQL retains WAL segments until long transactions complete
- **Vacuum blocking**: `VACUUM` cannot clean up rows visible to the long transaction

### Mitigation

1. **Set a statement timeout** to prevent runaway queries within a transaction:

```go
tx, err := db.BeginTx(ctx, nil)
if err != nil {
    return err
}

// Set a 30-second timeout for this transaction
_, err = tx.ExecContext(ctx, "SET LOCAL statement_timeout = '30s'")
if err != nil {
    tx.Rollback()
    return err
}
```

2. **Use context with timeout** so the entire transaction is bounded:

```go
ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
defer cancel()

err := WithTx(ctx, db, func(tx *sql.Tx) error {
    // If context expires, the transaction is automatically rolled back
    return nil
})
```

3. **Break large operations into batches** instead of processing everything in one transaction:

```go
// BAD -- single transaction updating millions of rows
WithTx(ctx, db, func(tx *sql.Tx) error {
    _, err := tx.ExecContext(ctx, "UPDATE users SET status = 'active'")
    return err
})

// GOOD -- batch processing
for {
    result, err := db.ExecContext(ctx,
        "UPDATE users SET status = 'active' WHERE status = 'pending' LIMIT 1000",
    )
    if err != nil {
        return err
    }
    rows, _ := result.RowsAffected()
    if rows == 0 {
        break
    }
}
```

4. **Never call external APIs** inside a transaction. If you need to coordinate with an external service, use the saga pattern or outbox pattern instead.

## Testing Transactions

### Test with Real Database

Use a test database and roll back after each test:

```go
func TestPlaceOrder(t *testing.T) {
    db := setupTestDB(t)

    // Start a transaction for the test
    tx, err := db.BeginTx(context.Background(), nil)
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() {
        tx.Rollback() // Undo all changes after the test
    })

    // Create store using the test transaction
    store := NewOrderStore(tx)

    // ... run test assertions ...
}
```

### Test Helper with Savepoints

For tests that need to verify transaction behavior:

```go
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()

    db, err := sql.Open("postgres", os.Getenv("TEST_DATABASE_URL"))
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { db.Close() })

    return db
}

func withTestTx(t *testing.T, db *sql.DB, fn func(tx *sql.Tx)) {
    t.Helper()

    tx, err := db.BeginTx(context.Background(), nil)
    if err != nil {
        t.Fatal(err)
    }
    defer tx.Rollback()

    fn(tx)
    // Transaction is always rolled back -- test data is never committed
}
```

### Testing Transaction Rollback

```go
func TestPlaceOrder_RollsBackOnPaymentFailure(t *testing.T) {
    db := setupTestDB(t)

    withTestTx(t, db, func(tx *sql.Tx) {
        // Setup: create a user and product
        _, err := tx.ExecContext(context.Background(),
            "INSERT INTO users (id, email, name) VALUES ($1, $2, $3)",
            "user-1", "test@example.com", "Test",
        )
        if err != nil {
            t.Fatal(err)
        }

        // Create a service that will fail on payment
        svc := &OrderService{
            db:         db,
            orderStore: NewOrderStore(),
            paymentStore: &FailingPaymentStore{}, // Always returns error
        }

        err = svc.PlaceOrder(context.Background(), &Order{
            UserID: "user-1",
            Total:  1000,
        })

        // Verify the error
        if err == nil {
            t.Fatal("expected error from failing payment")
        }

        // Verify the order was NOT created (transaction rolled back)
        var count int
        tx.QueryRowContext(context.Background(),
            "SELECT COUNT(*) FROM orders WHERE user_id = $1", "user-1",
        ).Scan(&count)

        if count != 0 {
            t.Errorf("expected 0 orders after rollback, got %d", count)
        }
    })
}
```

## Anti-Patterns

### Starting transactions in store methods

```go
// BAD -- store controls transaction, caller cannot compose
func (s *UserStore) CreateUser(ctx context.Context, u *User) error {
    tx, _ := s.db.BeginTx(ctx, nil)
    _, err := tx.ExecContext(ctx, "INSERT INTO users ...", ...)
    if err != nil {
        tx.Rollback()
        return err
    }
    return tx.Commit()
}
```

The caller cannot add this operation to a larger transaction. Move transaction management to the service layer.

### Forgetting to handle rollback errors

```go
// BAD -- rollback error is silently ignored
if err := fn(tx); err != nil {
    tx.Rollback() // What if this fails?
    return err
}
```

Log or wrap the rollback error so you know if cleanup failed.

### Holding transactions open during external API calls

```go
// BAD -- holds a connection and locks while waiting for HTTP response
WithTx(ctx, db, func(tx *sql.Tx) error {
    order, _ := orderStore.CreateWithTx(ctx, tx, order)

    // This HTTP call might take seconds or time out
    paymentResult, err := paymentAPI.Charge(order.Total)
    if err != nil {
        return err // Transaction held open the entire time
    }

    return orderStore.UpdateStatusWithTx(ctx, tx, order.ID, "paid")
})
```

Make external calls outside the transaction. Use an outbox pattern if you need to coordinate:

```go
// GOOD -- transaction is short, external call is outside
var order *Order

err := WithTx(ctx, db, func(tx *sql.Tx) error {
    var err error
    order, err = orderStore.CreateWithTx(ctx, tx, newOrder)
    return err
})
if err != nil {
    return err
}

// External call outside the transaction
paymentResult, err := paymentAPI.Charge(order.Total)
if err != nil {
    // Mark order as failed in a separate transaction
    return orderStore.UpdateStatus(ctx, order.ID, "payment_failed")
}

return orderStore.UpdateStatus(ctx, order.ID, "paid")
```

### Not passing context to transaction operations

```go
// BAD -- query is not cancellable
_, err := tx.Exec("SELECT * FROM large_table")

// GOOD -- respects context cancellation
_, err := tx.ExecContext(ctx, "SELECT * FROM large_table")
```

Always use the `Context` variants so queries are cancelled when the request context is done.
