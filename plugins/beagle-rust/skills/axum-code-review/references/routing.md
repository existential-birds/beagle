# Routing

## Basic Routing

```rust
use axum::{routing::{get, post, put, delete}, Router};

let app = Router::new()
    .route("/users", get(list_users).post(create_user))
    .route("/users/{id}", get(get_user).put(update_user).delete(delete_user))
    .with_state(state);
```

Note: axum 0.7.x uses `{id}` path syntax. Earlier versions used `:id`.

## Nested Routers

Organize routes by domain. Each module can define its own router.

```rust
// users.rs
pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(list).post(create))
        .route("/{id}", get(show).put(update).delete(destroy))
}

// main.rs
let app = Router::new()
    .nest("/api/users", users::router())
    .nest("/api/orders", orders::router())
    .fallback(handle_404)
    .with_state(state);
```

### Nested Router State

Nested routers must use the same state type or a subset. Use `Router::with_state()` to provide different state to nested routers:

```rust
// Sub-router with different state
let admin_router = Router::new()
    .route("/stats", get(admin_stats))
    .with_state(admin_state); // different state type

let app = Router::new()
    .nest("/admin", admin_router)  // already has its state
    .with_state(app_state);        // main app state
```

## Fallback Handlers

```rust
async fn handle_404() -> impl IntoResponse {
    (StatusCode::NOT_FOUND, Json(json!({"error": "not found"})))
}

let app = Router::new()
    .route("/api/health", get(health))
    .fallback(handle_404);
```

## Route Conflicts

Routes conflict when two patterns can match the same path. axum panics at startup when this happens.

```rust
// CONFLICT - both match /users/123
.route("/users/{id}", get(get_user))
.route("/users/{name}", get(get_user_by_name))

// SOLUTION - differentiate by prefix or use query params
.route("/users/by-id/{id}", get(get_user))
.route("/users/by-name/{name}", get(get_user_by_name))
```

## Method Routing

```rust
// Explicit per-method routing (preferred)
.route("/items", get(list_items).post(create_item))

// Method router for custom handling
use axum::routing::MethodRouter;

fn items_router() -> MethodRouter<AppState> {
    get(list_items)
        .post(create_item)
        .options(preflight)
}
```

## LazyLock for Static Route Configuration (Edition 2024)

Static route tables or regex patterns previously initialized with `once_cell::sync::Lazy` or `lazy_static!` should use `std::sync::LazyLock` (stable since Rust 1.80):

```rust
// BAD (unnecessary dependency)
use once_cell::sync::Lazy;
static ROUTE_REGEX: Lazy<Regex> = Lazy::new(|| Regex::new(r"^/api/v\d+/").unwrap());

// GOOD (std library, no extra dependency)
use std::sync::LazyLock;
static ROUTE_REGEX: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^/api/v\d+/").unwrap());
```

## RPIT Capture in Router Functions (Edition 2024)

Functions returning `Router` are unaffected (concrete type). But helper functions returning `impl IntoResponse` used as fallback handlers or utility responses may over-capture lifetimes in edition 2024:

```rust
// Edition 2024: captures 'a even though response is owned
fn not_found_body<'a>(path: &'a str) -> impl IntoResponse {
    Json(json!({"error": format!("not found: {path}")}))
}

// Fix with precise capture if needed
fn not_found_body<'a>(path: &'a str) -> impl IntoResponse + use<> {
    Json(json!({"error": format!("not found: {path}")}))
}
```

## Review Questions

1. Are routes organized by domain using nested routers?
2. Is there a fallback handler for unmatched routes?
3. Are route methods explicit (`.get()`, `.post()`)?
4. Are there any route conflicts (overlapping path patterns)?
5. Is `with_state` called with the correct state type?
6. Are static route patterns using `std::sync::LazyLock` instead of `once_cell`/`lazy_static`?
7. Do helper functions returning `impl IntoResponse` with lifetime params need `+ use<>` precise capture?
