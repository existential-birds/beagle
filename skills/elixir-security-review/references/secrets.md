# Secrets, Configuration, Cookies, and Path Safety

## 1. Compile-Time vs Runtime Configuration (`config/runtime.exs`)

`config/config.exs` and `config/prod.exs` are evaluated at **compile time** — any `System.get_env/1` calls there get baked into release artifacts and Docker build layers and fail silently if `nil`.

Load deployment secrets in `config/runtime.exs` using `System.fetch_env!/1` so missing secrets fail fast on boot:

```elixir
# BAD - evaluated at compile time in config/prod.exs
config :my_app, MyAppWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# GOOD - evaluated at runtime in config/runtime.exs
if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing."

  config :my_app, MyAppWeb.Endpoint,
    secret_key_base: secret_key_base

  config :my_app, MyApp.Stripe,
    api_key: System.fetch_env!("STRIPE_API_KEY")
end
```

## 2. Log, Struct, and Crash Report Redaction

- **Phoenix parameter filtering:** Configure `:filter_parameters` (or `{:keep, [...]}` allowlist) so passwords, tokens, and secrets are scrubbed from HTTP request logs:
  ```elixir
  config :phoenix, :filter_parameters, ["password", "secret", "token", "api_key"]
  ```
- **Struct inspection (`@derive Inspect`):** Exclude sensitive fields on schemas and credential structs so `inspect/1`, Logger, and error trackers never leak them:
  ```elixir
  @derive {Inspect, except: [:password, :password_hash, :api_token]}
  ```
- **Ecto schema fields:** Mark virtual/secret fields with `redact: true` (`field :password, :string, virtual: true, redact: true`).
- **GenServer state:** Implement `GenServer.format_status/1` (see [process-exposure.md](process-exposure.md)).

## 3. Session Cookies, `Plug.Crypto`, and `Phoenix.Token`

By default, `Plug.Session` with `:cookie` store **signs** the session cookie using `secret_key_base` and `:signing_salt` (preventing tampering), **but does NOT encrypt it** — anyone with the cookie can Base64-decode its contents.

- Set `:encryption_salt` if the session stores anything sensitive, or store only an opaque random session token referencing server-side storage:
  ```elixir
  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "...",
    encryption_salt: "..."
  ]
  ```
- For `Phoenix.Token.sign/4` and `:verify/4` (or `Plug.Crypto.sign/4`), use distinct purpose salts per token type and always pass an explicit `max_age` (seconds) rather than `:infinity`.

## 4. No Hardcoded Secrets

Flag any committed `secret_key_base`, signing/encryption salts, API keys, webhook secrets, or database passwords in:
- `config/config.exs`, `config/prod.exs`, or `config/dev.exs` reused for production
- Application modules, module attributes, or default function arguments

## 5. Path Traversal (`Path.safe_relative/1,2`)

When building filesystem paths from user-supplied filenames or archive entries, `Path.join/2` alone does **not** prevent `../` traversal. Validate with `Path.safe_relative/1,2` (Elixir 1.14+, returns `{:ok, safe_path}` or `:error`):

```elixir
# BAD - Path.join("/var/uploads", "../../etc/passwd") escapes upload_dir!
def read_upload(upload_dir, filename) do
  File.read(Path.join(upload_dir, filename))
end

# GOOD - rejects "..", absolute paths, and escaping symlinks
def read_upload(upload_dir, filename) do
  case Path.safe_relative(filename, upload_dir) do
    {:ok, safe_rel} -> File.read(Path.join(upload_dir, safe_rel))
    :error -> {:error, :invalid_path}
  end
end
```

## Review Questions

1. Are all production secrets loaded in `config/runtime.exs` via `System.fetch_env!/1` rather than compile-time `config/*.exs`?
2. Are `:filter_parameters`, `@derive {Inspect, except: [...]}`, and `redact: true` configured for sensitive fields?
3. Are `Plug.Session` cookies encrypted (`encryption_salt`) or limited to opaque tokens, and do `Phoenix.Token` calls enforce distinct salts and `max_age`?
4. Do user-controlled file paths validate with `Path.safe_relative/1,2`?
