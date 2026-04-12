# Type Mapping

## C-to-Rust Primitive Type Table

Always use `std::ffi` or `std::os::raw` types for C interop. Never assume `int` is `i32` on all platforms.

| C Type | Rust Type | Notes |
|--------|-----------|-------|
| `int` | `c_int` | Platform-dependent width |
| `unsigned int` | `c_uint` | Platform-dependent width |
| `char` | `c_char` | Signed or unsigned depending on platform |
| `short` | `c_short` | |
| `long` | `c_long` | 32-bit on Windows, 64-bit on LP64 Unix |
| `long long` | `c_longlong` | |
| `float` | `c_float` / `f32` | |
| `double` | `c_double` / `f64` | |
| `size_t` | `usize` | |
| `ssize_t` | `isize` | |
| `void` | `()` (return) / `c_void` (pointer) | |
| `void*` | `*mut c_void` | |
| `const void*` | `*const c_void` | |
| `char*` | `*mut c_char` | |
| `const char*` | `*const c_char` | |
| `bool` / `_Bool` | `bool` | Only with `#[repr(C)]`; C99+ |
| `int8_t` | `i8` | Fixed-width, always safe |
| `uint8_t` | `u8` | Fixed-width, always safe |
| `int32_t` | `i32` | Fixed-width, always safe |
| `uint64_t` | `u64` | Fixed-width, always safe |
| `__be32` | `[u8; 4]` | Big-endian; don't use `i32` |

## String Types

```rust
use std::ffi::{CStr, CString, c_char};

// Borrowing a C string (incoming from C, null-terminated)
// SAFETY: ptr is a valid null-terminated C string
let c_str: &CStr = unsafe { CStr::from_ptr(ptr) };
let rust_str: &str = c_str.to_str()?; // Fails if not UTF-8

// Creating a C string to pass to C
let c_string = CString::new("hello")?; // Err if contains \0
let ptr: *const c_char = c_string.as_ptr();
// c_string MUST outlive ptr -- dropping c_string invalidates ptr
```

For OS-native paths, use `OsStr`/`OsString` which handle platform encoding.

## Struct Layout with repr(C)

`#[repr(C)]` guarantees field ordering, padding, and alignment match the C ABI.

```rust
// C definition:
// struct Point { int32_t x; int32_t y; };

#[repr(C)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

// C definition with padding:
// struct Mixed { char tag; int32_t value; };
// Has 3 bytes of padding between tag and value

#[repr(C)]
pub struct Mixed {
    pub tag: c_char,
    // 3 bytes padding inserted by repr(C) to align value
    pub value: i32,
}
```

### Size and Alignment Verification

Always verify layout matches at compile time or in tests:

```rust
// Compile-time assertions
const _: () = assert!(std::mem::size_of::<Point>() == 8);
const _: () = assert!(std::mem::align_of::<Point>() == 4);

// In tests, compare against C sizeof/alignof if available
#[test]
fn layout_matches_c() {
    assert_eq!(std::mem::size_of::<Mixed>(), 8); // 1 + 3pad + 4
    assert_eq!(std::mem::align_of::<Mixed>(), 4);
}
```

## Enum Representation

### Fieldless Enums (C-style)

```rust
// Maps to: enum Status { OK = 0, ERR = 1, BUSY = 2 };
#[repr(C)]
pub enum Status {
    Ok = 0,
    Err = 1,
    Busy = 2,
}
```

Use `#[repr(u32)]` or `#[repr(i32)]` when C specifies an exact underlying type.

### Bitflag Enums -- Do NOT Use Rust Enums

C enums used as bitflags produce combined values that are invalid Rust enum discriminants. Use a newtype or `bitflags`:

```rust
// BAD -- value 3 (READ | WRITE) is undefined behavior
#[repr(C)]
enum Permission { Read = 1, Write = 2, Execute = 4 }

// GOOD -- newtype with constants
#[repr(transparent)]
pub struct Permission(pub u32);
impl Permission {
    pub const READ: Self = Self(1);
    pub const WRITE: Self = Self(2);
    pub const EXECUTE: Self = Self(4);
}
```

### Data-Carrying Enums (Tagged Unions)

With `#[repr(C)]`, a data-carrying enum becomes a struct with a discriminant field and a union of variant data:

```rust
#[repr(C)]
pub enum Event {
    Click(i32, i32),       // tag=0, data=(i32, i32)
    KeyPress(c_char),      // tag=1, data=c_char
}
// Equivalent C: struct { uint32_t tag; union { ... } data; }
```

## Opaque Types

When C exposes a type whose internals Rust should not access, create a distinct empty type:

```rust
// Instead of bare *mut c_void everywhere:
#[non_exhaustive]
#[repr(transparent)]
pub struct DatabaseHandle(c_void);

#[non_exhaustive]
#[repr(transparent)]
pub struct ConnectionHandle(c_void);

unsafe extern "C" {
    fn db_open() -> *mut DatabaseHandle;
    fn db_connect(db: *mut DatabaseHandle) -> *mut ConnectionHandle;
    fn db_close(db: *mut DatabaseHandle);
}
// Now db_connect(conn) is a compile error -- types are distinct
```

The `#[non_exhaustive]` prevents construction outside the defining crate.

## Nullable Pointers and Option

Rust guarantees that `Option<NonNull<T>>`, `Option<&T>`, `Option<&mut T>`, and `Option<extern "C" fn(...)>` have the same layout as a raw pointer (niche optimization). `None` is null.

```rust
use std::ptr::NonNull;

// Nullable pointer from C -- zero overhead
fn from_c(ptr: *mut Foo) -> Option<NonNull<Foo>> {
    NonNull::new(ptr)
}

// Nullable callback
type Callback = Option<extern "C" fn(c_int) -> c_int>;

unsafe extern "C" {
    // C signature: void register(int (*cb)(int));
    // cb can be NULL
    fn register(cb: Callback);
}
```

## Function Pointers

Function pointers across FFI must use `extern "C"` calling convention. Rust closures cannot cross FFI.

```rust
type CCallback = extern "C" fn(data: *mut c_void, status: c_int); // Correct
type BadCallback = fn(data: *mut c_void, status: c_int);          // Wrong ABI
// Closures (Fn/FnMut/FnOnce) cannot cross FFI -- unknown size and calling convention
```

A function pointer's calling convention is part of its type: `extern "C" fn()` and `fn()` are different types.
