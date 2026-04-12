# no_std Development

## Opting Out of the Standard Library

`#![no_std]` switches the crate prelude from `std::prelude` to `core::prelude`, preventing accidental dependence on OS-provided functionality:

```rust
#![no_std]

// core types (Option, Result, Iterator) are available through the prelude
// std types (File, HashMap, println!) are not
```

The attribute only changes the prelude. You can still explicitly `use std::` if needed, which enables the common pattern of offering both no_std and std APIs through feature flags.

## Three Library Tiers

| Tier | Provides | Requires |
|------|----------|----------|
| `core` | Fundamental types (Option, Result), iterators, sorting, atomics, marker types | Nothing beyond the hardware |
| `alloc` | Vec, String, Box, Arc, Rc, BTreeMap, format! | A memory allocator |
| `std` | File, net, HashMap, println!, time, threads | An operating system |

`std` re-exports everything from `core` and `alloc`. Most types you access through `std::` actually live in `core::` or `alloc::`.

### What Each Tier Excludes

- **core only**: no heap allocation, no collections, no String, no I/O
- **core + alloc**: no HashMap (requires OS randomness), no filesystem, no networking, no threads
- **std**: full functionality, requires OS support

## Using alloc in no_std

Opt into heap-allocated types without pulling in the full standard library:

```rust
#![no_std]
extern crate alloc;

use alloc::vec::Vec;
use alloc::string::String;
use alloc::boxed::Box;
use alloc::sync::Arc;
use alloc::collections::BTreeMap;
```

Replace `use std::` with `use alloc::` for heap types. Note: `HashMap` is not in `alloc` because it requires OS-provided randomness for key hashing.

### Custom Allocator

Define a global allocator when the platform has no default:

```rust
use core::alloc::{GlobalAlloc, Layout};

struct MyAllocator;

unsafe impl GlobalAlloc for MyAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // platform-specific allocation
        # unimplemented!()
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        // platform-specific deallocation
        # unimplemented!()
    }
}

#[global_allocator]
static ALLOCATOR: MyAllocator = MyAllocator;
```

## Embedded Binary Setup

For targets without an OS, opt out of both the standard library and the Rust runtime:

```rust
#![no_std]
#![no_main]

use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {} // halt on panic; alternatives: abort, reset device
}

#[unsafe(no_mangle)]  // edition 2024 syntax
pub extern "C" fn main() -> ! {
    // entry point — never returns
    loop {}
}
```

- `#![no_main]` removes the Rust runtime (`lang_start`), so no command-line arg setup, no signal handlers, no stdout flushing
- `#[panic_handler]` is required: defines what happens on panic (must diverge with `-> !`)
- The entry point signature must match the target platform's expectations

## Volatile Memory Access

Use volatile reads and writes for memory-mapped hardware registers. The compiler cannot elide or reorder volatile operations:

```rust
use core::ptr;

const GPIO_REG: *mut u32 = 0x4000_0000 as *mut u32;

fn set_pin_high(pin: u8) {
    unsafe {
        let current = ptr::read_volatile(GPIO_REG);
        ptr::write_volatile(GPIO_REG, current | (1 << pin));
    }
}
```

Use volatile operations when:
- Hardware registers have side effects on read
- Interrupt handlers access shared memory
- Memory-mapped device state must be read/written in exact order

## Type-Safe Hardware State Machines

Use `PhantomData` and zero-sized types to enforce valid hardware states at compile time:

```rust
use core::marker::PhantomData;

pub struct On;
pub struct Off;

pub struct Led<State>(PhantomData<State>);

impl Led<Off> {
    pub fn turn_on(self) -> Led<On> {
        // write to hardware register
        Led(PhantomData)
    }
}

impl Led<On> {
    pub fn turn_off(self) -> Led<Off> {
        // write to hardware register
        Led(PhantomData)
    }
}
```

Methods consume `self` and return the new state type, making invalid transitions unrepresentable. The `PhantomData` carries no runtime cost.

## Fixed-Size Stack Collections

When heap allocation is unavailable, use stack-allocated collections with const generics. The `arrayvec` crate provides production-ready `ArrayVec<T, N>` and `ArrayString<N>` types that store elements inline with a compile-time capacity limit and fail gracefully when full.

## Cross-Compilation

Targets follow the format `machine-vendor-os` (e.g., `thumbv7m-none-eabi`, `x86_64-unknown-linux-musl`):

```shell
rustup target add thumbv7m-none-eabi
cargo build --target thumbv7m-none-eabi
```

### Verifying no_std Compatibility

Build against a bare-metal target to catch accidental `std` usage in your code and dependencies:

```shell
cargo check --target thumbv7m-none-eabi
```

Add this to CI for no_std crates. For custom targets without a prebuilt standard library:

```shell
rustup component add rust-src
cargo build -Z build-std=core,alloc --target my-custom-target.json
```

## Static Memory Preferences

In embedded contexts, prefer static and stack allocations:

| Strategy | When to Use |
|----------|-------------|
| `const` / `static` | Global configuration, lookup tables, singleton hardware handles |
| Stack arrays (`[T; N]`) | Fixed-size buffers with known bounds |
| `ArrayVec<T, N>` | Variable-length data with a compile-time maximum |
| `alloc` types | Only when dynamic sizing is essential and an allocator is available |

For fallible allocation in `alloc`-using code, prefer `try_` variants (`Vec::try_reserve`, `Box::try_new`) over panicking methods when targeting environments where out-of-memory must be handled gracefully.
