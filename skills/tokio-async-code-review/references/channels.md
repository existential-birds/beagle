# Channels

## Choosing the Right Channel

| Pattern | Channel | Key Trait |
|---------|---------|-----------|
| Many producers → one consumer, back-pressure | `mpsc` | Bounded, async send blocks when full |
| One value, one time | `oneshot` | Request-response, task result |
| Every consumer gets every message | `broadcast` | Fan-out, event bus |
| Latest value, no queue | `watch` | Config changes, state snapshots |

## mpsc (Multi-Producer Single-Consumer)

The most common channel. Use bounded for back-pressure, unbounded only when you have external flow control.

```rust
// Bounded - preferred, provides back-pressure
let (tx, mut rx) = tokio::sync::mpsc::channel::<Event>(100);

// Unbounded - use with caution (OOM risk)
let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<Event>();
```

### Capacity Sizing

- Too small (1-10): senders block frequently, throughput suffers
- Too large (100K+): memory pressure, defeats back-pressure purpose
- Rule of thumb: 2-4x the expected burst size

### Graceful Shutdown via Drop

When all senders are dropped, `rx.recv()` returns `None`. This is the idiomatic way to signal "no more items."

```rust
// Producer side
drop(tx); // signals completion

// Consumer side
while let Some(item) = rx.recv().await {
    process(item);
}
// Loop exits when all senders dropped
```

### Common Mistakes

```rust
// BAD - holding tx clone prevents shutdown
let tx_clone = tx.clone();
drop(tx);
// rx.recv() will never return None because tx_clone still exists

// BAD - send without handling closed channel
tx.send(item).await.unwrap(); // panics if receiver dropped

// GOOD - handle send errors
if tx.send(item).await.is_err() {
    tracing::warn!("receiver dropped, stopping producer");
    break;
}
```

## broadcast

Every active subscriber receives every message. Messages are stored in a shared ring buffer.

```rust
let (tx, _rx) = tokio::sync::broadcast::channel::<Event>(16_384);

// Each subscriber gets their own receiver
let mut rx1 = tx.subscribe();
let mut rx2 = tx.subscribe();
```

### Handling Lag

When a receiver falls behind, older messages are overwritten. The receiver gets `RecvError::Lagged(n)` indicating how many messages were missed.

```rust
loop {
    match rx.recv().await {
        Ok(event) => handle(event),
        Err(broadcast::error::RecvError::Lagged(n)) => {
            tracing::warn!(missed = n, "receiver lagged, some events lost");
            // Continue processing — data may be stale
        }
        Err(broadcast::error::RecvError::Closed) => break,
    }
}
```

### Capacity Considerations

Broadcast stores messages until the slowest receiver consumes them (up to capacity). Size the buffer for the slowest expected consumer, not the average case.

## oneshot

Single value, single use. The sender can only send once, and the receiver can only receive once.

```rust
let (tx, rx) = tokio::sync::oneshot::channel::<Result<Response, Error>>();

// Responder
tokio::spawn(async move {
    let result = compute().await;
    let _ = tx.send(result); // receiver may have been dropped
});

// Requester
match rx.await {
    Ok(result) => handle(result),
    Err(_) => tracing::error!("responder dropped without sending"),
}
```

### Common Pattern: Request-Response

```rust
struct Request {
    data: InputData,
    reply: oneshot::Sender<Result<OutputData, Error>>,
}

// Client
let (tx, rx) = oneshot::channel();
request_tx.send(Request { data, reply: tx }).await?;
let response = rx.await??;

// Server
while let Some(req) = request_rx.recv().await {
    let result = process(req.data).await;
    let _ = req.reply.send(result);
}
```

## watch

Holds the latest value. Receivers see only the most recent value, not a queue. Good for config changes or state snapshots.

```rust
let (tx, rx) = tokio::sync::watch::channel(Config::default());

// Update
tx.send(new_config)?;

// Read latest (non-blocking)
let current = rx.borrow().clone();

// Wait for changes
let mut rx = rx.clone();
loop {
    rx.changed().await?;
    let config = rx.borrow().clone();
    apply_config(config);
}
```

## Dual-Channel Pattern (Event Bus)

For systems that need both real-time fan-out and durable persistence, combine broadcast (real-time) with mpsc (persistence):

```rust
struct EventBus {
    broadcast_tx: broadcast::Sender<Arc<Event>>,
    persist_tx: mpsc::Sender<Arc<Event>>,
}

impl EventBus {
    async fn emit(&self, event: Event) {
        let event = Arc::new(event);

        // Fan-out to all subscribers (best-effort)
        let _ = self.broadcast_tx.send(Arc::clone(&event));

        // Durable events go to persistence channel (back-pressure aware)
        if event.event_type.is_durable() {
            if let Err(e) = self.persist_tx.send(event).await {
                tracing::error!(error = %e, "persistence channel closed");
            }
        }
    }
}
```

## Review Questions

1. Is the channel type matched to the communication pattern?
2. Are bounded channels sized appropriately for the workload?
3. Are `SendError` / `RecvError` handled (not unwrapped)?
4. Is broadcast `Lagged` error handled gracefully?
5. Are all sender clones dropped to allow clean shutdown?
6. Is `watch` used instead of broadcast for latest-value-only patterns?
