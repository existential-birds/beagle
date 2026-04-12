# Pointer Types

## Thread Safety: Send and Sync

Rust tracks pointer safety through two marker traits:

- **`Send`** -- data can move across threads
- **`Sync`** -- data can be referenced from multiple threads simultaneously

A pointer is thread-safe only if the data behind it is.

## Quick Reference

| Type | Description | Send + Sync | Use When |
|------|-------------|-------------|----------|
| `&T` | Shared reference | Yes (if `T: Sync`) | Multiple readers, no mutation |
| `&mut T` | Exclusive mutable reference | Send (if `T: Send`), Sync (if `T: Sync`) | Single writer |
| `Box<T>` | Heap-allocated, single owner | Send (if `T: Send`), Sync (if `T: Sync`) | Recursive types, large data, trait objects |
| `Rc<T>` | Reference counted, single thread | Neither | Multiple owners, same thread |
| `Arc<T>` | Atomic reference counted | Yes (if `T: Send + Sync`) | Multiple owners, across threads |
| `Cell<T>` | Interior mutability, Copy types | Not Sync | Shared mutable state, single thread |
| `RefCell<T>` | Interior mutability, runtime checks | Not Sync | Shared mutable state, single thread |
| `Mutex<T>` | Thread-safe exclusive access | Yes (if `T: Send`) | Shared mutable state, across threads |
| `RwLock<T>` | Thread-safe read-many/write-one | Send (if `T: Send`), Sync (if `T: Send + Sync`) | Read-heavy shared state, across threads |
| `OnceCell<T>` | One-time init, single thread | Not Sync | Lazy initialization |
| `OnceLock<T>` | One-time init, thread-safe | Yes | Static lazy values (replaces `lazy_static!`) |
| `LazyCell<T>` | Deferred init with closure | Not Sync | Complex lazy init, single thread |
| `LazyLock<T>` | Deferred init with closure, thread-safe | Yes | Complex static initialization |
| `*const T` / `*mut T` | Raw pointers | Neither (manual) | FFI, raw memory |

## When to Use Each

### `&T` -- Shared Borrow

The most common type. Safe, no mutation, multiple readers:

```rust
fn print_len(s: &str) {
    println!("{}", s.len());
}
```

### `&mut T` -- Exclusive Borrow

Single writer, enforced at compile time:

```rust
fn append_suffix(s: &mut String) {
    s.push_str("_updated");
}
```

### `Box<T>` -- Heap Allocation

Single-owner heap data. Required for recursive types:

```rust
enum Tree<T> {
    Leaf(T),
    Branch(Box<Tree<T>>, Box<Tree<T>>),
}
```

### `Rc<T>` / `Arc<T>` -- Shared Ownership

`Rc` for single-threaded, `Arc` for multi-threaded:

```rust
// Multi-thread: Arc + Mutex for shared mutable state
let shared = Arc::new(Mutex::new(Vec::new()));
let clone = Arc::clone(&shared);
```

Common mistake: using `Arc<Mutex<T>>` when data is single-threaded. Use `Rc<RefCell<T>>` instead.

### `Cell<T>` / `RefCell<T>` -- Interior Mutability

Mutate data behind a shared reference. `Cell` for Copy types, `RefCell` for others:

```rust
use std::cell::Cell;

struct Counter {
    count: Cell<u32>,
}

impl Counter {
    fn increment(&self) { // note: &self, not &mut self
        self.count.set(self.count.get() + 1);
    }
}
```

`RefCell` panics on double borrow at runtime. Prefer compile-time borrowing when possible.

### `Mutex<T>` / `RwLock<T>` -- Thread-Safe Mutability

`Mutex` for exclusive access, `RwLock` when reads outnumber writes:

```rust
use std::sync::{Arc, Mutex};

let data = Arc::new(Mutex::new(HashMap::new()));

// In a thread:
let mut map = data.lock().unwrap();
map.insert("key", "value");
// Lock released when `map` drops
```

### `OnceLock<T>` / `LazyLock<T>` -- One-Time Initialization

Replace `lazy_static!` and `once_cell` with standard library types. `LazyLock` (stable since 1.80) and `OnceLock` make third-party lazy initialization crates unnecessary:

```rust
use std::sync::OnceLock;

static CONFIG: OnceLock<Config> = OnceLock::new();

fn get_config() -> &'static Config {
    CONFIG.get_or_init(|| load_config_from_disk())
}
```

```rust
use std::sync::LazyLock;

static REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\d{4}-\d{2}-\d{2}$").unwrap()
});
```

### Migrating from `lazy_static` / `once_cell`

```rust
// BAD -- third-party dependency no longer needed
lazy_static::lazy_static! {
    static ref CONFIG: Config = load_config();
}

// BAD -- once_cell also superseded
static CONFIG: once_cell::sync::Lazy<Config> = once_cell::sync::Lazy::new(|| load_config());

// GOOD -- standard library LazyLock
static CONFIG: LazyLock<Config> = LazyLock::new(|| load_config());
```

For single-threaded contexts, use `LazyCell` / `OnceCell` (from `std::cell`) instead of their `sync` counterparts:

```rust
use std::cell::LazyCell;

// Thread-local lazy value -- no atomic overhead
let lazy_value = LazyCell::new(|| expensive_computation());
```

Remove `lazy_static` and `once_cell` from `Cargo.toml` once all usages are migrated.

## Decision Guide

```text
Need heap allocation?
  -> Single owner: Box<T>
  -> Shared ownership, single thread: Rc<T>
  -> Shared ownership, multi-thread: Arc<T>

Need interior mutability?
  -> Copy type, single thread: Cell<T>
  -> Non-Copy, single thread: RefCell<T>
  -> Multi-thread, exclusive: Mutex<T>
  -> Multi-thread, read-heavy: RwLock<T>

Need lazy initialization?
  -> Single thread: OnceCell<T> / LazyCell<T>
  -> Multi-thread / static: OnceLock<T> / LazyLock<T>
```
