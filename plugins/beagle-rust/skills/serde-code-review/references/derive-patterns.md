# Derive Patterns

## Enum Tagging Strategies

Serde supports four enum representations. The choice affects wire format, readability, and compatibility.

### Externally Tagged (Default)

```rust
#[derive(Serialize, Deserialize)]
enum Message {
    Text(String),
    Image { url: String, alt: String },
}
// JSON: {"Text": "hello"} or {"Image": {"url": "...", "alt": "..."}}
```

Simple but produces awkward JSON for variants with data.

### Internally Tagged

```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
enum Message {
    Text { content: String },
    Image { url: String, alt: String },
}
// JSON: {"type": "Text", "content": "hello"}
```

Clean and common for API types. Requires all variants to be struct-like (no tuple variants). The tag field name must not collide with variant field names.

### Adjacently Tagged

```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
enum Message {
    Text(String),
    Image { url: String, alt: String },
}
// JSON: {"type": "Text", "data": "hello"}
```

Supports both tuple and struct variants. Good for message protocols where type and payload are separate.

### Untagged

```rust
#[derive(Serialize, Deserialize)]
#[serde(untagged)]
enum ApiResponse {
    Success { data: Value },
    Error { error: String, code: u32 },
}
// JSON: {"data": {...}} or {"error": "...", "code": 404}
```

Discriminated by structure, not a tag. Serde tries each variant in order until one succeeds. Watch for ambiguity — if two variants could match the same input, serde uses the first match.

## Field Attributes

### rename_all

Converts Rust's `snake_case` to the wire format's convention.

```rust
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApiResponse {
    user_name: String,      // → "userName"
    created_at: DateTime,   // → "createdAt"
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Status {
    InProgress,  // → "in_progress"
    Complete,    // → "complete"
}
```

Common values: `camelCase`, `snake_case`, `SCREAMING_SNAKE_CASE`, `kebab-case`, `lowercase`, `UPPERCASE`.

### skip_serializing_if

Omits fields from output when a condition is true. Essential for clean API responses.

```rust
#[derive(Serialize)]
struct User {
    name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    email: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    tags: Vec<String>,
}
// With email=None, tags=[]: {"name": "Alice"}
// Without skip: {"name": "Alice", "email": null, "tags": []}
```

### default

Provides fallback values during deserialization when a field is missing.

```rust
#[derive(Deserialize)]
struct Config {
    host: String,
    #[serde(default = "default_port")]
    port: u16,
    #[serde(default)]  // uses Default::default()
    debug: bool,
}

fn default_port() -> u16 { 8080 }
```

### flatten

Inlines a struct's fields into the parent. Useful for composition but can cause subtle issues.

```rust
#[derive(Serialize, Deserialize)]
struct Request {
    id: Uuid,
    #[serde(flatten)]
    metadata: Metadata,  // metadata fields appear at top level
}

#[derive(Serialize, Deserialize)]
struct Metadata {
    timestamp: DateTime<Utc>,
    source: String,
}
// JSON: {"id": "...", "timestamp": "...", "source": "..."}
```

**Pitfall:** If `Request` and `Metadata` have a field with the same name, one silently wins. Use `#[serde(flatten)]` only when field names are guaranteed not to collide.

## Database Type Alignment

When types are used with both serde and sqlx, keep representations consistent:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "varchar", rename_all = "snake_case")]
pub enum Status {
    Pending,
    InProgress,
    Complete,
}
```

Both serde and sqlx will use `"pending"`, `"in_progress"`, `"complete"`. Mismatched casing between the two causes bugs that are hard to trace.

## Review Questions

1. Is the enum tagging strategy explicit and appropriate for the wire format?
2. Is `rename_all` consistent across related types?
3. Are optional fields using `skip_serializing_if` for clean output?
4. Does `#[serde(flatten)]` risk field name collisions?
5. Do serde and sqlx enum representations match?
