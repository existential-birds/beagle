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

## Atomics and Shared State Across FFI

### AtomicXxx vs C `_Atomic` ABI compatibility

Rust's `AtomicU32` has the same in-memory representation as C11's `_Atomic uint32_t` on every platform Rust currently targets, but **neither language spec formally guarantees this**. The compatibility relies on (a) matching layout and alignment, and (b) the C11/C++11 memory model being compatible with Rust's (which it is, by design).

Cross-language atomic access is only well-defined when both sides treat the location as atomic. Passing `&AtomicU32` as a plain `*mut u32` and letting C do non-atomic stores creates a data race from Rust's perspective — undefined behavior even if the bits look right.

```rust
// BAD -- C treats it as a plain int and does *p = v;
unsafe extern "C" { fn c_set(p: *mut u32); }
let a = AtomicU32::new(0);
unsafe { c_set(a.as_ptr()) }; // races with any Rust load/store of `a`

// GOOD -- C side declares _Atomic uint32_t* and uses atomic_store_explicit
unsafe extern "C" { fn c_set_atomic(p: *mut u32, v: u32); }
let a = AtomicU32::new(0);
unsafe { c_set_atomic(a.as_ptr(), 1) }; // C guarantees atomic store
```

Availability is also platform-gated: `AtomicU64` is missing on `thumbv6m-*`, 32-bit PowerPC, and some RISC-V profiles. Code shared with C that assumes 64-bit atomicity must `#[cfg(target_has_atomic = "64")]`-gate or fall back to a mutex.

- `[FILE:LINE] FFI_ATOMIC_PASSED_AS_PLAIN_POINTER` — `AtomicU{8,16,32,64}::as_ptr()` (or `&AtomicX as *mut _`) passed to a C function whose header declares the parameter as plain `uintN_t*` rather than `_Atomic uintN_t*`.
- `[FILE:LINE] FFI_ATOMIC64_NOT_TARGET_GATED` — `AtomicU64`/`AtomicI64` used across FFI without `#[cfg(target_has_atomic = "64")]` on a crate that lists embedded targets in `Cargo.toml` or CI.

### Raw pointers, Send, Sync at FFI boundaries

`*const T` and `*mut T` are `!Send` and `!Sync` by default. Wrapping a C handle in a newtype and adding `unsafe impl Send` (and sometimes `Sync`) is the standard pattern — but each line is a safety boundary that must be justified against the C library's documented thread-safety contract.

The standard `Send`-only pattern (handle moves between threads but is never used from two threads at once):

```rust
struct Handle(*mut ffi::OpaqueT);
// SAFETY: libfoo docs §3.2 -- handles may be used from any single thread,
// just not concurrently from multiple threads.
unsafe impl Send for Handle {}
// NOTE: deliberately NOT Sync; concurrent use is documented as UB.
```

`Sync` is much stronger: it claims `&Handle` can be shared, i.e. that two threads may call C through the same handle simultaneously. Only sound if the C library documents that handle as thread-safe (e.g. SQLite with `SQLITE_THREADSAFE=1`, or libcurl multi-handles under documented rules).

```rust
// BAD -- libfoo docs say "not thread-safe"; this enables races.
unsafe impl Sync for Handle {}

// BAD -- no safety comment; reviewer cannot verify the claim.
unsafe impl Send for Handle {}
unsafe impl Sync for Handle {}
```

- `[FILE:LINE] FFI_UNSAFE_SYNC_ON_NON_THREADSAFE_HANDLE` — `unsafe impl Sync` on a wrapper around a C library whose documentation does not assert per-handle thread safety.
- `[FILE:LINE] FFI_UNSAFE_SEND_SYNC_NO_SAFETY_COMMENT` — `unsafe impl (Send|Sync) for` an FFI wrapper with no preceding `// SAFETY:` comment referencing the C library's threading docs.

### UnsafeCell on FFI boundaries

`&T` in Rust is a promise that the referent will not be mutated for the lifetime of the borrow. A C function declared `extern "C" fn c_func(x: &T)` that mutates through `x` violates that promise — undefined behavior even if no Rust code observes the mutation. The correct Rust type for "C may mutate through this borrow" is `&UnsafeCell<T>` (or a `*mut T` and an unsafe contract).

```rust
// BAD -- C writes through x, but &T promises immutability.
unsafe extern "C" {
    fn c_increment(x: &u32); // C does (*x)++
}

// GOOD -- UnsafeCell signals "C may mutate"; or use *mut u32.
unsafe extern "C" {
    fn c_increment(x: &UnsafeCell<u32>);
}
```

Similarly, if a `*mut T` is handed to C, stored there, and later mutated by C from another thread, the Rust side must model the shared-mutable semantics — `Atomic*`, `Mutex<T>`, or `UnsafeCell<T>` with hand-rolled synchronization. Plain `&mut T` cannot escape this way without violating aliasing rules.

- `[FILE:LINE] FFI_SHARED_REF_C_MUTATES` — `extern "C" fn(..&T..)` or `extern "C" fn(..&mut T..)` where the C implementation is documented to mutate `*T` (or to retain the pointer after return and mutate later).
- `[FILE:LINE] FFI_POINTER_STORED_BY_C_NO_INTERIOR_MUT` — a `*mut T` is registered with C (callback context, observer list, etc.) and the C side may mutate the pointee from another thread, but `T` is not `Atomic*`, `Mutex<T>`, or wrapped in `UnsafeCell`.

### Threading models — Rust threads vs C-spawned threads

When a C library calls a Rust callback from a thread the C library spawned, that thread is not a `std::thread` thread. It is a perfectly valid OS thread (kernel-scheduled, has a TLS slot), but Rust's `std::thread::current()` builds a thread handle lazily, and `thread::park`/`unpark` only work with handles that have been observed by both sides.

`std::sync::Mutex`, `RwLock`, atomics, and `Condvar` work across **any** OS thread — they are backed by OS primitives (futex / SRW / pthread mutex) that do not care which language spawned the thread.

`thread_local!` works on C-spawned threads (it uses platform TLS), **but the per-thread destructors are only guaranteed to run when the thread exits through Rust's thread-exit chain**. A C-managed thread pool that recycles workers without going through `pthread_exit` (or that exits the process without joining) may skip the destructors entirely.

```rust
// BAD -- relies on TLS destructor to flush a buffer in a C thread pool.
thread_local! {
    static BUF: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
}
// If the C library reuses the OS thread or exits without pthread_exit,
// `BUF`'s Drop never runs and the buffered bytes are silently lost.
```

For C-callback contexts, prefer explicit lifecycle hooks (register-on-enter, flush-on-callback-exit) over TLS destructors.

- `[FILE:LINE] FFI_TLS_DESTRUCTOR_ON_C_THREAD` — `thread_local!` whose `Drop` performs cleanup that must run (flush, unregister), inside a module whose entry point is a callback invoked by C-managed threads.
- `[FILE:LINE] FFI_PARK_UNPARK_ACROSS_C_CALLBACK` — `thread::park` or `Thread::unpark` used to coordinate with a thread that originated in a C library (the `Thread` handle may not refer to that OS thread reliably).

### Cross-references

- `[../../rust-code-review/references/concurrency-primitives.md]` — `Send`/`Sync` bounds, `Mutex`/`RwLock` semantics, poisoning, async-aware locking.
- `[../../rust-code-review/references/memory-ordering.md]` — `Relaxed`/`Acquire`/`Release`/`AcqRel`/`SeqCst` pairing rules and the publish-via-Release / observe-via-Acquire pattern.
- `[../../rust-code-review/references/lock-free-patterns.md]` — ABA, hand-rolled CAS, hazard pointers, epoch reclamation.

## Review Questions

1. Is ownership transfer documented and paired (allocate/free)?
2. Do `CString` values outlive their derived pointers?
3. Are callbacks wrapped in `catch_unwind`?
4. Are `Send`/`Sync` deliberately not implemented for thread-unsafe FFI types?
