# Input Validation with go-playground/validator

## Common Validation Tags

The `go-playground/validator` package uses struct tags to declare constraints. Here are the most frequently used tags for web APIs.

### String Constraints

```go
type CreatePostRequest struct {
    Title   string `json:"title"   validate:"required,min=1,max=200"`
    Slug    string `json:"slug"    validate:"required,alphanum"`
    Body    string `json:"body"    validate:"required,min=10,max=50000"`
    Status  string `json:"status"  validate:"required,oneof=draft published archived"`
    Website string `json:"website" validate:"omitempty,url"`
}
```

| Tag | Description |
|-----|-------------|
| `required` | Field must be present and non-zero |
| `omitempty` | Skip validation if field is zero value |
| `min=N` | Minimum length (string) or value (number) |
| `max=N` | Maximum length (string) or value (number) |
| `len=N` | Exact length |
| `oneof=a b c` | Value must be one of the listed options (space-separated) |
| `alpha` | Letters only |
| `alphanum` | Letters and numbers only |
| `ascii` | ASCII characters only |

### Format Validators

```go
type ContactRequest struct {
    Email   string `json:"email"   validate:"required,email"`
    Phone   string `json:"phone"   validate:"omitempty,e164"`
    Website string `json:"website" validate:"omitempty,url"`
    IP      string `json:"ip"      validate:"omitempty,ip"`
}
```

| Tag | Description |
|-----|-------------|
| `email` | Valid email address |
| `url` | Valid URL |
| `uri` | Valid URI |
| `uuid` | Valid UUID (any version) |
| `uuid4` | Valid UUID v4 |
| `ip` | Valid IPv4 or IPv6 address |
| `ipv4` | Valid IPv4 address |
| `e164` | Valid E.164 phone number |
| `json` | Valid JSON string |

### Numeric Constraints

```go
type PaginationRequest struct {
    Page     int `json:"page"      validate:"required,gte=1"`
    PageSize int `json:"page_size" validate:"required,gte=1,lte=100"`
}

type ProductRequest struct {
    Price    float64 `json:"price"    validate:"required,gt=0"`
    Quantity int     `json:"quantity" validate:"required,gte=0,lte=10000"`
    Weight   float64 `json:"weight"   validate:"omitempty,gte=0"`
}
```

| Tag | Description |
|-----|-------------|
| `gt=N` | Greater than N |
| `gte=N` | Greater than or equal to N |
| `lt=N` | Less than N |
| `lte=N` | Less than or equal to N |
| `ne=N` | Not equal to N |

---

## Custom Validators

Register custom validation functions for domain-specific rules.

### Simple Custom Validator

```go
func setupValidator() *validator.Validate {
    v := validator.New()

    // Register a custom "slug" validator
    v.RegisterValidation("slug", func(fl validator.FieldLevel) bool {
        val := fl.Field().String()
        matched, _ := regexp.MatchString(`^[a-z0-9]+(-[a-z0-9]+)*$`, val)
        return matched
    })

    // Register a custom "strong_password" validator
    v.RegisterValidation("strong_password", func(fl validator.FieldLevel) bool {
        val := fl.Field().String()
        if len(val) < 8 {
            return false
        }
        hasUpper := regexp.MustCompile(`[A-Z]`).MatchString(val)
        hasLower := regexp.MustCompile(`[a-z]`).MatchString(val)
        hasDigit := regexp.MustCompile(`[0-9]`).MatchString(val)
        return hasUpper && hasLower && hasDigit
    })

    return v
}
```

Usage:

```go
type CreatePostRequest struct {
    Slug string `json:"slug" validate:"required,slug"`
}

type RegisterRequest struct {
    Password string `json:"password" validate:"required,strong_password"`
}
```

### Custom Validator with Parameters

```go
// Usage: validate:"not_reserved=admin root system"
v.RegisterValidation("not_reserved", func(fl validator.FieldLevel) bool {
    val := fl.Field().String()
    param := fl.Param() // "admin root system"
    reserved := strings.Fields(param)
    for _, r := range reserved {
        if strings.EqualFold(val, r) {
            return false
        }
    }
    return true
})
```

### Using JSON Tag Names in Error Messages

By default, validator uses Go struct field names in errors. Register the JSON tag name function to get API-friendly field names:

```go
v := validator.New()
v.RegisterTagNameFunc(func(fld reflect.StructField) string {
    name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
    if name == "-" {
        return ""
    }
    return name
})
```

Now `e.Field()` returns `"email"` instead of `"Email"` in validation errors.

---

## Nested Struct Validation

Validator automatically descends into nested structs when `validate:"required"` or `validate:"dive"` is used.

### Required Nested Struct

```go
type CreateOrderRequest struct {
    Items   []OrderItem    `json:"items"   validate:"required,min=1,dive"`
    Address ShippingAddress `json:"address" validate:"required"`
}

type OrderItem struct {
    ProductID string `json:"product_id" validate:"required,uuid"`
    Quantity  int    `json:"quantity"    validate:"required,gte=1,lte=100"`
}

type ShippingAddress struct {
    Street  string `json:"street"  validate:"required,min=1,max=200"`
    City    string `json:"city"    validate:"required,min=1,max=100"`
    State   string `json:"state"   validate:"required,len=2"`
    ZipCode string `json:"zip"     validate:"required,numeric,len=5"`
    Country string `json:"country" validate:"required,iso3166_1_alpha2"`
}
```

Key points:
- `dive` tells the validator to validate each element inside a slice
- Without `dive`, only the slice itself is checked (length, required)
- Nested structs with `validate:"required"` are validated recursively

### Optional Nested Struct

Use a pointer for optional nested structs:

```go
type UpdateProfileRequest struct {
    Name    string           `json:"name"    validate:"omitempty,min=1,max=100"`
    Address *ShippingAddress `json:"address" validate:"omitempty"`
}
```

When `Address` is `nil`, validation is skipped. When present, all its field rules apply.

---

## Slice and Map Validation

### Slice Validation

```go
type BulkCreateRequest struct {
    // Validate the slice itself (1-50 items) AND each element
    Users []CreateUserRequest `json:"users" validate:"required,min=1,max=50,dive"`
}
```

The `dive` tag means: after validating the slice-level constraints (`min=1,max=50`), validate each element according to its own struct tags.

### Slice of Primitives

```go
type TagRequest struct {
    Tags []string `json:"tags" validate:"required,min=1,max=10,dive,required,min=1,max=50"`
}
```

Reading left to right:
1. `required` -- slice must be present
2. `min=1,max=10` -- slice must have 1-10 elements
3. `dive` -- now validate each element
4. `required,min=1,max=50` -- each string must be non-empty and max 50 chars

### Map Validation

```go
type MetadataRequest struct {
    // Validate keys and values separately
    Metadata map[string]string `json:"metadata" validate:"required,max=20,dive,keys,min=1,max=50,endkeys,required,max=500"`
}
```

Reading left to right:
1. `required,max=20` -- map is required, max 20 entries
2. `dive` -- enter the map
3. `keys,min=1,max=50,endkeys` -- each key must be 1-50 chars
4. `required,max=500` -- each value must be non-empty and max 500 chars

---

## Cross-Field Validation

Validate fields relative to each other using `eqfield`, `nefield`, `gtfield`, etc.

### Password Confirmation

```go
type RegisterRequest struct {
    Email           string `json:"email"            validate:"required,email"`
    Password        string `json:"password"         validate:"required,min=8,max=72"`
    ConfirmPassword string `json:"confirm_password" validate:"required,eqfield=Password"`
}
```

### Date Range Validation

```go
type DateRangeRequest struct {
    StartDate time.Time `json:"start_date" validate:"required"`
    EndDate   time.Time `json:"end_date"   validate:"required,gtfield=StartDate"`
}
```

### Cross-Field Tags

| Tag | Description |
|-----|-------------|
| `eqfield=Other` | Must equal the value of `Other` |
| `nefield=Other` | Must not equal the value of `Other` |
| `gtfield=Other` | Must be greater than `Other` |
| `gtefield=Other` | Must be greater than or equal to `Other` |
| `ltfield=Other` | Must be less than `Other` |
| `ltefield=Other` | Must be less than or equal to `Other` |

### Struct-Level Validation

For complex cross-field rules that cannot be expressed with tags, use struct-level validation:

```go
v.RegisterStructValidation(func(sl validator.StructLevel) {
    req := sl.Current().Interface().(CreateEventRequest)

    if req.EndDate.Before(req.StartDate) {
        sl.ReportError(req.EndDate, "end_date", "EndDate", "after_start", "")
    }

    if req.MaxAttendees > 0 && req.MinAttendees > req.MaxAttendees {
        sl.ReportError(req.MinAttendees, "min_attendees", "MinAttendees", "lte_max", "")
    }
}, CreateEventRequest{})
```

---

## Error Message Formatting for API Responses

### Basic Formatting

```go
func formatValidationErrors(err error) string {
    var msgs []string
    for _, e := range err.(validator.ValidationErrors) {
        msgs = append(msgs, fmt.Sprintf("field '%s' failed on '%s'", e.Field(), e.Tag()))
    }
    return strings.Join(msgs, "; ")
}
```

### Structured JSON Error Response

For richer API responses, return field-level errors as a map:

```go
type ValidationError struct {
    Field   string `json:"field"`
    Message string `json:"message"`
}

func formatValidationErrorsJSON(err error) []ValidationError {
    var errs []ValidationError
    for _, e := range err.(validator.ValidationErrors) {
        errs = append(errs, ValidationError{
            Field:   e.Field(),
            Message: msgForTag(e),
        })
    }
    return errs
}

func msgForTag(e validator.FieldError) string {
    switch e.Tag() {
    case "required":
        return "this field is required"
    case "email":
        return "must be a valid email address"
    case "min":
        return fmt.Sprintf("must be at least %s characters", e.Param())
    case "max":
        return fmt.Sprintf("must be at most %s characters", e.Param())
    case "oneof":
        return fmt.Sprintf("must be one of: %s", e.Param())
    case "uuid":
        return "must be a valid UUID"
    case "gte":
        return fmt.Sprintf("must be at least %s", e.Param())
    case "lte":
        return fmt.Sprintf("must be at most %s", e.Param())
    case "eqfield":
        return fmt.Sprintf("must match %s", e.Param())
    default:
        return fmt.Sprintf("failed validation: %s", e.Tag())
    }
}
```

### Usage in Handler

```go
func (s *Server) handleCreateUser(w http.ResponseWriter, r *http.Request) error {
    var req CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        return &AppError{Code: 400, Message: "invalid JSON"}
    }

    if err := validate.Struct(req); err != nil {
        errs := formatValidationErrorsJSON(err)
        writeJSON(w, 422, map[string]any{
            "error":  "validation failed",
            "fields": errs,
        })
        return nil
    }

    // proceed with validated request...
    return nil
}
```

Example API response:

```json
{
    "error": "validation failed",
    "fields": [
        {"field": "email", "message": "must be a valid email address"},
        {"field": "name", "message": "this field is required"}
    ]
}
```

---

## Validation Anti-Patterns

### Validating in the service layer

```go
// BAD: validation scattered across layers
func (s *UserService) Create(ctx context.Context, name, email string) (*User, error) {
    if name == "" {
        return nil, errors.New("name required")  // should be caught at handler
    }
}
```

Validate once at the boundary. Services receive trusted data.

### Using validate tags without dive on slices

```go
// BAD: only checks slice length, not element contents
Items []OrderItem `json:"items" validate:"required,min=1"`

// GOOD: dive validates each element
Items []OrderItem `json:"items" validate:"required,min=1,dive"`
```

### Ignoring the difference between required and omitempty

```go
// Required: field must be present and non-zero
Name string `validate:"required"`  // "" is invalid

// Omitempty: skip validation if zero, validate if present
Bio string `validate:"omitempty,min=10,max=1000"`  // "" is valid, "short" is invalid
```

### Not limiting request body size

```go
// BAD: attacker can send gigabytes
json.NewDecoder(r.Body).Decode(&req)

// GOOD: limit body size
r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB limit
if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
    // MaxBytesError is returned if the limit is exceeded
    return &AppError{Code: 413, Message: "request body too large"}
}
```
