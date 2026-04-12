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

## Tower Service Trait and `async fn` in Traits (Edition 2024)

Custom Tower `Service` implementations that previously required `#[async_trait]` can now use native `async fn`. However, the Tower `Service` trait itself uses `poll_ready`/`call` (not async fn), so this primarily applies to higher-level abstractions built on top of Tower.

For axum middleware specifically, `axum::middleware::from_fn` already uses plain async functions and is unaffected. The benefit appears when implementing custom `FromRequestParts` extractors used within middleware:

```rust
// GOOD (edition 2024) - no #[async_trait] needed
impl<S> FromRequestParts<S> for RateLimitInfo
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let ip = parts.headers
            .get("x-forwarded-for")
            .and_then(|v| v.to_str().ok())
            .unwrap_or("unknown");
        Ok(RateLimitInfo { client_ip: ip.to_string() })
    }
}
```

## FFI and `unsafe extern` (Edition 2024)

If middleware integrates with C libraries (e.g., custom TLS, hardware security modules), edition 2024 requires `unsafe extern`:

```rust
// BAD (edition 2024 — won't compile)
extern "C" {
    fn custom_tls_init() -> i32;
}

// GOOD (edition 2024)
unsafe extern "C" {
    fn custom_tls_init() -> i32;
}
```

Also, `#[no_mangle]` on exported FFI functions must become `#[unsafe(no_mangle)]`.

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
6. Are extractors used in middleware using native `async fn` instead of `#[async_trait]`?
7. Are FFI blocks in middleware written as `unsafe extern "C"` (edition 2024)?
8. Are `#[no_mangle]` attributes on exported functions written as `#[unsafe(no_mangle)]` (edition 2024)?
