# Middleware

## Tower Layer Pattern

Axum uses Tower for middleware. Layers wrap services to add cross-cutting concerns.

```rust
use tower_http::{
    cors::CorsLayer,
    compression::CompressionLayer,
    timeout::TimeoutLayer,
    trace::TraceLayer,
};

let app = Router::new()
    .route("/api/health", get(health))
    .nest("/api/users", users::router())
    .layer(
        ServiceBuilder::new()
            .layer(TraceLayer::new_for_http())
            .layer(TimeoutLayer::new(Duration::from_secs(30)))
            .layer(CompressionLayer::new())
            .layer(CorsLayer::permissive()) // configure properly for production
    )
    .with_state(state);
```

### Layer Ordering

Layers execute in **reverse order** of how they're added. The last `.layer()` call runs first on the request and last on the response.

```rust
Router::new()
    .layer(A)  // runs 3rd on request, 1st on response
    .layer(B)  // runs 2nd on request, 2nd on response
    .layer(C)  // runs 1st on request, 3rd on response
```

With `ServiceBuilder`, the order is top-to-bottom (more intuitive):

```rust
ServiceBuilder::new()
    .layer(C)  // runs 1st on request
    .layer(B)  // runs 2nd on request
    .layer(A)  // runs 3rd on request
```

## Common tower-http Layers

| Layer | Purpose |
|-------|---------|
| `TraceLayer` | Request/response logging with tracing spans |
| `TimeoutLayer` | Request timeout (returns 408 on timeout) |
| `CorsLayer` | CORS headers |
| `CompressionLayer` | Response compression (gzip, br, etc.) |
| `RequestBodyLimitLayer` | Limit request body size |
| `SetRequestHeaderLayer` | Add/override request headers |
| `PropagateHeaderLayer` | Copy request headers to response |

## Custom Middleware with axum::middleware

For request/response transformation with access to axum extractors:

```rust
use axum::middleware::{self, Next};

async fn auth_middleware(
    State(state): State<AppState>,
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = req.headers()
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or(AppError::Unauthorized)?;

    let user = validate_token(&state.pool, token).await?;
    req.extensions_mut().insert(user);

    Ok(next.run(req).await)
}

// Apply to specific routes
let protected = Router::new()
    .route("/profile", get(profile))
    .route_layer(middleware::from_fn_with_state(state.clone(), auth_middleware));

let app = Router::new()
    .route("/health", get(health))  // unprotected
    .merge(protected)
    .with_state(state);
```

## Graceful Shutdown

```rust
let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;

axum::serve(listener, app)
    .with_graceful_shutdown(shutdown_signal())
    .await?;

async fn shutdown_signal() {
    tokio::signal::ctrl_c().await.expect("failed to listen for ctrl+c");
    tracing::info!("shutdown signal received");
}
```

## Review Questions

1. Are layers ordered correctly (especially auth before business logic)?
2. Is `tower-http` used for standard concerns (CORS, compression, tracing)?
3. Is request timeout configured for production?
4. Does custom middleware use `from_fn_with_state` for state access?
5. Is graceful shutdown implemented?
