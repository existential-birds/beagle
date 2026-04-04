# Type State Pattern

## What It Is

Type State Pattern encodes different states of a system as types, not runtime flags. The compiler enforces valid state transitions -- invalid operations become compile errors instead of runtime bugs.

`PhantomData<State>` is removed after compilation, so there is no runtime overhead.

## Simple Example: Connection State

```rust
use std::marker::PhantomData;

struct Disconnected;
struct Connected;

struct Client<State> {
    addr: String,
    _state: PhantomData<State>,
}

impl Client<Disconnected> {
    fn new(addr: &str) -> Self {
        Client { addr: addr.to_string(), _state: PhantomData }
    }

    fn connect(self) -> Result<Client<Connected>, std::io::Error> {
        // ... establish connection ...
        Ok(Client { addr: self.addr, _state: PhantomData })
    }
}

impl Client<Connected> {
    fn send(&self, msg: &[u8]) -> Result<(), std::io::Error> {
        // Only available when connected
        Ok(())
    }
}
```

```rust
let client = Client::new("localhost:8080");
// client.send(b"hello"); // Won't compile -- not connected yet
let connected = client.connect()?;
connected.send(b"hello")?; // Works
```

## Builder with Required Fields

Force callers to set required fields before `.build()`:

```rust
use std::marker::PhantomData;

struct Missing;
struct Set;

struct Builder<NameState, PortState> {
    name: Option<String>,
    port: Option<u16>,
    _name: PhantomData<NameState>,
    _port: PhantomData<PortState>,
}

impl Builder<Missing, Missing> {
    fn new() -> Self {
        Builder {
            name: None, port: None,
            _name: PhantomData, _port: PhantomData,
        }
    }
}

impl<P> Builder<Missing, P> {
    fn name(self, name: impl Into<String>) -> Builder<Set, P> {
        Builder {
            name: Some(name.into()), port: self.port,
            _name: PhantomData, _port: PhantomData,
        }
    }
}

impl<N> Builder<N, Missing> {
    fn port(self, port: u16) -> Builder<N, Set> {
        Builder {
            name: self.name, port: Some(port),
            _name: PhantomData, _port: PhantomData,
        }
    }
}

impl Builder<Set, Set> {
    fn build(self) -> Server {
        Server {
            name: self.name.unwrap(),
            port: self.port.unwrap(),
        }
    }
}
```

```rust
// Valid -- both required fields set
let server = Builder::new().name("api").port(8080).build();
let server = Builder::new().port(8080).name("api").build(); // order doesn't matter

// Won't compile -- missing required field
// let server = Builder::new().name("api").build(); // Error: port not set
```

## When to Use

- **Compile-time state safety** -- prevent invalid operations entirely
- **API constraints** -- builders with required fields, protocol state machines
- **Replace runtime booleans** -- `is_connected`, `is_authenticated` become type-level guarantees
- **Workflow pipelines** -- validate -> authorize -> process

## When to Avoid

- **Trivial state** -- simple enums are clearer for 2-3 states without complex transitions
- **Runtime flexibility** -- state determined by user input at runtime
- **Complex generics** -- if the type signature becomes harder to understand than the bug it prevents
- **Not worth the verbosity** -- pattern requires duplicating struct fields across state transitions

## Downsides

- More verbose than runtime checks
- Complex type signatures with multiple state parameters
- PhantomData is not intuitive for Rust beginners
- Struct fields must be moved between states (some duplication)

> Use when it saves bugs, increases safety, or simplifies logic -- not for cleverness.
