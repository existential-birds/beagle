# Extractors

## Extractor Ordering

Body-consuming extractors (`Json`, `Form`, `Bytes`, `String`) must be the LAST parameter. The HTTP body can only be consumed once.

```rust
// BAD - Json consumes body before Path can extract
async fn handler(Json(body): Json<CreateUser>, Path(id): Path<u64>) { ... }

// GOOD - non-body extractors first, body extractor last
async fn handler(Path(id): Path<u64>, Json(body): Json<CreateUser>) { ... }
```

## Common Extractors

### State

Shared application state. The type must implement `Clone`.

```rust
#[derive(Clone)]
struct AppState {
    pool: PgPool,        // PgPool is Clone (it's an Arc internally)
    config: Arc<Config>, // wrap non-Clone types in Arc
}

async fn handler(State(state): State<AppState>) -> impl IntoResponse {
    let users = query_as!(User, "SELECT ...").fetch_all(&state.pool).await?;
    Json(users)
}
```

### Path

Extract path parameters. Type must implement `Deserialize`.

```rust
// Single parameter
async fn get_user(Path(id): Path<Uuid>) -> impl IntoResponse { ... }

// Multiple parameters
async fn get_comment(
    Path((post_id, comment_id)): Path<(Uuid, Uuid)>,
) -> impl IntoResponse { ... }

// Named parameters via struct
#[derive(Deserialize)]
struct CommentPath {
    post_id: Uuid,
    comment_id: Uuid,
}
async fn get_comment(Path(path): Path<CommentPath>) -> impl IntoResponse { ... }
```

### Query

Extract query string parameters.

```rust
#[derive(Deserialize)]
struct ListParams {
    #[serde(default = "default_page")]
    page: u32,
    #[serde(default = "default_per_page")]
    per_page: u32,
    search: Option<String>,
}

fn default_page() -> u32 { 1 }
fn default_per_page() -> u32 { 20 }

async fn list_users(Query(params): Query<ListParams>) -> impl IntoResponse { ... }
```

### Json

Deserializes JSON request body. Must be the last extractor.

```rust
#[derive(Deserialize)]
struct CreateUser {
    name: String,
    email: String,
}

async fn create_user(
    State(state): State<AppState>,
    Json(input): Json<CreateUser>,
) -> Result<impl IntoResponse, AppError> {
    let user = insert_user(&state.pool, &input).await?;
    Ok((StatusCode::CREATED, Json(user)))
}
```

### Extension

For request-scoped data injected by middleware (e.g., authenticated user).

```rust
// Middleware injects
req.extensions_mut().insert(AuthUser { id: user_id });

// Handler extracts
async fn handler(Extension(user): Extension<AuthUser>) -> impl IntoResponse { ... }
```

## Custom Extractors and `async fn` in Traits (Edition 2024)

Since Rust 1.75, `async fn` is stable in trait definitions and implementations. Custom extractors no longer need `#[async_trait]`.

```rust
// BAD (pre-1.75 / unnecessary dependency)
use async_trait::async_trait;

#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        // ...
    }
}

// GOOD (Rust 1.75+ / edition 2024)
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = parts.headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized)?;
        // validate token...
        Ok(AuthUser { id: user_id })
    }
}
```

Note: `#[async_trait]` is still needed when using `dyn Trait` with async extractors (trait objects require the indirection).

## RPIT Lifetime Capture in Handlers (Edition 2024)

In edition 2024, `-> impl Trait` captures ALL in-scope lifetimes by default. For axum handlers returning owned data, this usually doesn't matter. But when a helper function returns `impl IntoResponse` and has lifetime parameters, it may over-capture:

```rust
// Edition 2024: this captures 'a even though the return is fully owned
fn render_page<'a>(title: &'a str) -> impl IntoResponse {
    Html(format!("<h1>{title}</h1>"))
}

// If over-capture causes lifetime issues, use precise capture syntax
fn render_page<'a>(title: &'a str) -> impl IntoResponse + use<> {
    Html(format!("<h1>{title}</h1>"))
}
```

Most axum handlers take owned extractors and return owned data, so RPIT capture changes are low-impact. Watch for helper functions with reference parameters returning `impl IntoResponse`.

## Error Handling Pattern

Handlers should return `Result<impl IntoResponse, AppError>` where `AppError` implements `IntoResponse`.

```rust
#[derive(Debug)]
enum AppError {
    NotFound(String),
    Internal(anyhow::Error),
    Validation(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            Self::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            Self::Internal(err) => {
                tracing::error!(error = %err, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".to_string())
            }
            Self::Validation(msg) => (StatusCode::UNPROCESSABLE_ENTITY, msg),
        };
        (status, Json(json!({"error": message}))).into_response()
    }
}

// Automatic conversion from sqlx errors
impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        match err {
            sqlx::Error::RowNotFound => Self::NotFound("resource not found".into()),
            other => Self::Internal(other.into()),
        }
    }
}
```

## Review Questions

1. Are body-consuming extractors the last parameter?
2. Is `State<T>` used for shared resources (not per-request creation)?
3. Do handler errors implement `IntoResponse` with appropriate status codes?
4. Are internal error details hidden from clients?
5. Are `Path` types aligned with route parameter definitions?
6. Are `Query` fields optional where the query param is optional?
7. Are custom `FromRequest`/`FromRequestParts` impls using native `async fn` instead of `#[async_trait]`?
8. Do helper functions returning `impl IntoResponse` with lifetime params need `+ use<>` precise capture?
