# Safety Patterns

## Wrapping Unsafe FFI in Safe Rust

The goal of FFI bindings is a safe public API built on unsafe internals. The safe wrapper must enforce all invariants that the C library documents.

```rust
// Raw FFI (typically in a -sys crate)
unsafe extern "C" {
    fn widget_create() -> *mut Widget;
    fn widget_set_name(w: *mut Widget, name: *const c_char) -> c_int;
    fn widget_destroy(w: *mut Widget);
}

// Safe wrapper
pub struct Widget {
    ptr: NonNull<ffi::Widget>,
}

impl Widget {
    pub fn new() -> Result<Self, Error> {
        // SAFETY: widget_create returns null on failure, valid pointer otherwise
        let ptr = unsafe { ffi::widget_create() };
        NonNull::new(ptr).map(|p| Widget { ptr: p }).ok_or(Error::CreateFailed)
    }

    pub fn set_name(&mut self, name: &str) -> Result<(), Error> {
        let c_name = CString::new(name)?;
        // SAFETY: self.ptr is valid (maintained by construction),
        // c_name is null-terminated and lives through this call
        let ret = unsafe { ffi::widget_set_name(self.ptr.as_ptr(), c_name.as_ptr()) };
        if ret == 0 { Ok(()) } else { Err(Error::SetNameFailed) }
    }
}

impl Drop for Widget {
    fn drop(&mut self) {
        // SAFETY: self.ptr was allocated by widget_create
        // and has not been freed (we own it)
        unsafe { ffi::widget_destroy(self.ptr.as_ptr()) }
    }
}
```

### Key principles for safe wrappers:
- Capture `&` vs `&mut` accurately -- if C mutates behind a pointer, take `&mut self`
- Use Rust lifetimes to enforce C's lifetime requirements (e.g., `Device<'ctx>` borrows `Context`)
- Do not implement `Send`/`Sync` unless the C library documents thread safety
- Use `PhantomData<*const ()>` to suppress auto-`Send`/`Sync` for thread-unsafe types

## Ownership Transfer Patterns

### Rust-to-C (giving ownership)

```rust
// Give C a heap-allocated Rust object
#[unsafe(no_mangle)]
pub extern "C" fn create_config() -> *mut Config {
    Box::into_raw(Box::new(Config::default()))
}

// C must call this to free -- never free with C's free()
#[unsafe(no_mangle)]
pub extern "C" fn destroy_config(ptr: *mut Config) {
    if ptr.is_null() { return; }
    // SAFETY: ptr was created by create_config via Box::into_raw
    // and has not been freed yet (caller contract)
    unsafe { drop(Box::from_raw(ptr)) }
}
```

### C-to-Rust (borrowing C memory)

```rust
// C owns the buffer, Rust borrows it
pub fn process_buffer(ptr: *const u8, len: usize) -> Result<(), Error> {
    if ptr.is_null() { return Err(Error::NullPointer); }
    // SAFETY: caller guarantees ptr is valid for len bytes
    // and the memory won't be freed during this call
    let slice = unsafe { std::slice::from_raw_parts(ptr, len) };
    // ... use slice ...
    Ok(())
}
```

### The Golden Rule
Rust-allocated memory must be freed by Rust. C-allocated memory must be freed by C. Never mix allocators.

## CString Lifetime Pitfall

The most common FFI bug: dropping a `CString` while C still holds a pointer to it.

```rust
// BAD -- dangling pointer! CString is dropped at semicolon
let ptr = CString::new("hello").unwrap().as_ptr(); // DANGLING
unsafe { some_c_function(ptr) }; // undefined behavior

// GOOD -- CString lives long enough
let c_str = CString::new("hello").unwrap();
let ptr = c_str.as_ptr();
unsafe { some_c_function(ptr) }; // c_str still alive
// c_str dropped here, after use
```

## Callback Safety

### Preventing Panics Across FFI

A panic unwinding past an `extern "C"` function boundary is undefined behavior. Always catch panics in callbacks:

```rust
extern "C" fn my_callback(data: *mut c_void) -> c_int {
    let result = std::panic::catch_unwind(|| {
        // SAFETY: data was passed as our context pointer
        let ctx = unsafe { &mut *(data as *mut MyContext) };
        ctx.handle_event()
    });
    match result {
        Ok(Ok(())) => 0,
        Ok(Err(_)) => -1,   // application error
        Err(_) => -2,        // panic caught, turned into error code
    }
}
```

### Passing Context Through Callbacks

C callbacks often take a `void*` context parameter. Use `Box::into_raw` to pass Rust state:

```rust
let ctx = Box::new(MyContext::new());
let ctx_ptr = Box::into_raw(ctx) as *mut c_void;

// SAFETY: register_callback stores ctx_ptr and passes it to on_event
unsafe { ffi::register_callback(on_event, ctx_ptr) };

// Later, in cleanup:
// SAFETY: ctx_ptr was created by Box::into_raw above
unsafe { drop(Box::from_raw(ctx_ptr as *mut MyContext)) };
```

## Error Handling Across FFI

Map C error patterns (return codes, errno, out-parameters) to `Result` in safe wrappers:

```rust
pub fn open_file(path: &CStr) -> Result<FileHandle, Error> {
    let fd = unsafe { ffi::open(path.as_ptr(), ffi::O_RDONLY) };
    if fd < 0 { Err(Error::from_errno(std::io::Error::last_os_error())) }
    else { Ok(FileHandle(fd)) }
}
```

## Build.rs Patterns

```rust
// build.rs -- linking, bindgen, and C compilation
fn main() {
    // Link directives
    println!("cargo:rustc-link-lib=ssl");              // dynamic (default)
    println!("cargo:rustc-link-lib=static=mylib");     // static
    println!("cargo:rustc-link-search=native=/usr/local/lib");
    println!("cargo:rerun-if-changed=wrapper.h");

    // Bindgen: generate Rust bindings from C headers
    let bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate().expect("bindgen failed");
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings.write_to_file(out.join("bindings.rs")).unwrap();

    // cc crate: compile bundled C source
    cc::Build::new().file("src/native/helper.c").compile("helper");
}
```

Review bindgen output for: correct `#[repr(C)]`, pointer mutability matching headers, platform-aware types (`c_long` not `i64`), distinct opaque types, and excluded internal-only C functions.

## Testing FFI Code

Run tests with sanitizers to catch memory bugs invisible to the compiler:

```bash
RUSTFLAGS="-Z sanitizer=address" cargo +nightly test  # use-after-free, overflow
RUSTFLAGS="-Z sanitizer=memory" cargo +nightly test   # uninitialized reads
valgrind --leak-check=full ./target/debug/my_ffi_tests # leak detection
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Dangling `CString` pointer | Bind `CString` to a variable before `.as_ptr()` |
| Double free | One side allocates, same side frees |
| Use-after-free | Ensure wrapper's `Drop` runs at the right time |
| Missing `repr(C)` | Add `#[repr(C)]` to every type crossing FFI |
| Panic across FFI | Wrap callback bodies in `catch_unwind` |
| Thread-unsafe type across threads | Don't impl `Send`/`Sync` without proof |

## Review Questions

1. Is ownership transfer documented and paired (allocate/free)?
2. Do `CString` values outlive their derived pointers?
3. Are callbacks wrapped in `catch_unwind`?
4. Are `Send`/`Sync` deliberately not implemented for thread-unsafe FFI types?
