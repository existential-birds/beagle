# Accessibility Patterns

## Critical Anti-Patterns

### 1. Using :focus Instead of :focus-visible

**Problem**: Visible focus rings on mouse clicks create poor UX. Use focus-visible for keyboard-only focus.

```tsx
// BAD - :focus shows ring on click
const buttonVariants = cva(
  "rounded focus:ring-2 focus:ring-primary" // Shows ring on mouse click
)

// GOOD - :focus-visible shows ring only for keyboard
const buttonVariants = cva(
  "rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
)

// Also apply to inputs:
const inputVariants = cva(
  "border rounded px-3 py-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
)
```

### 2. Missing aria-invalid for Form States

**Problem**: Screen readers cannot announce validation errors without aria-invalid.

```tsx
// BAD - visual error state only
export function Input({ error, className, ...props }) {
  return (
    <input
      className={cn(
        "border rounded",
        error && "border-red-500", // Visual only
        className
      )}
      {...props}
    />
  )
}

// GOOD - aria-invalid with proper error announcement
export function Input({ error, className, ...props }) {
  const errorId = React.useId()

  return (
    <div>
      <input
        className={cn(
          "border rounded focus-visible:ring-2",
          error && "border-destructive focus-visible:ring-destructive",
          className
        )}
        aria-invalid={error ? "true" : undefined}
        aria-describedby={error ? errorId : undefined}
        {...props}
      />
      {error && (
        <p id={errorId} className="text-sm text-destructive mt-1">
          {error}
        </p>
      )}
    </div>
  )
}
```

### 3. Missing Disabled States

**Problem**: Disabled elements must have both visual and semantic disabled states.

```tsx
// BAD - CSS only, no semantic disabled
export function Button({ disabled, children }) {
  return (
    <button className={disabled ? "opacity-50 cursor-not-allowed" : ""}>
      {children}
    </button>
    // Missing disabled attribute and aria-disabled
  )
}

// GOOD - semantic + visual disabled
const buttonVariants = cva("rounded px-4 py-2", {
  variants: {
    variant: {
      default: "bg-primary text-primary-foreground hover:bg-primary/90",
      outline: "border hover:bg-accent",
    },
  },
  defaultVariants: { variant: "default" },
})

export function Button({ disabled, variant, className, ...props }) {
  return (
    <button
      className={cn(
        buttonVariants({ variant }),
        disabled && "opacity-50 cursor-not-allowed pointer-events-none",
        className
      )}
      disabled={disabled}
      aria-disabled={disabled}
      {...props}
    />
  )
}
```

### 4. Missing Screen Reader Text

**Problem**: Icon-only buttons or visual indicators need sr-only text for screen readers.

```tsx
// BAD - icon button with no label
export function CloseButton({ onClick }) {
  return (
    <button onClick={onClick}>
      <X className="h-4 w-4" /> {/* No text for screen readers */}
    </button>
  )
}

// GOOD - sr-only text for screen readers
export function CloseButton({ onClick }) {
  return (
    <button
      onClick={onClick}
      aria-label="Close" // For simple cases
    >
      <X className="h-4 w-4" />
    </button>
  )
}

// BETTER - visible text with icon
export function CloseButton({ onClick }) {
  return (
    <button onClick={onClick}>
      <X className="h-4 w-4" />
      <span className="sr-only">Close</span>
    </button>
  )
}

// For status indicators:
export function Badge({ status, children }) {
  return (
    <div className="flex items-center gap-2">
      <div className={cn(
        "h-2 w-2 rounded-full",
        status === "online" && "bg-green-500",
        status === "offline" && "bg-gray-500"
      )} />
      <span className="sr-only">{status === "online" ? "Online" : "Offline"}</span>
      {children}
    </div>
  )
}
```

### 5. Missing Keyboard Navigation

**Problem**: Interactive custom elements must support keyboard navigation.

```tsx
// BAD - div with onClick, no keyboard support
export function Card({ onClick, children }) {
  return (
    <div onClick={onClick} className="cursor-pointer">
      {children}
    </div>
  )
}

// GOOD - proper button with keyboard support
export function Card({ onClick, children, ...props }) {
  if (onClick) {
    return (
      <button
        onClick={onClick}
        className="text-left w-full"
        {...props}
      >
        {children}
      </button>
    )
  }

  return <div {...props}>{children}</div>
}

// For custom interactive elements:
export function Tab({ active, onClick, children }) {
  return (
    <button
      role="tab"
      aria-selected={active}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault()
          onClick(e)
        }
      }}
      tabIndex={active ? 0 : -1}
      className={cn(
        "px-4 py-2",
        active && "border-b-2 border-primary"
      )}
    >
      {children}
    </button>
  )
}
```

### 6. Color as Only Indicator

**Problem**: Color alone cannot convey state (WCAG 1.4.1).

```tsx
// BAD - color only for required fields
export function Label({ required, children }) {
  return (
    <label className={required ? "text-red-500" : ""}>
      {children}
    </label>
  )
}

// GOOD - color + text/icon indicator
export function Label({ required, children }) {
  return (
    <label>
      {children}
      {required && (
        <>
          <span className="text-destructive ml-1" aria-hidden="true">*</span>
          <span className="sr-only">(required)</span>
        </>
      )}
    </label>
  )
}

// For status:
export function Status({ status }) {
  const icons = {
    success: <Check className="h-4 w-4" />,
    error: <X className="h-4 w-4" />,
    warning: <AlertTriangle className="h-4 w-4" />,
  }

  return (
    <div className={cn(
      "flex items-center gap-2",
      status === "success" && "text-green-600",
      status === "error" && "text-destructive",
      status === "warning" && "text-yellow-600"
    )}>
      {icons[status]}
      <span>{status}</span> {/* Text accompanies color */}
    </div>
  )
}
```

### 7. Missing Loading States

**Problem**: Async actions must indicate loading state for screen readers.

```tsx
// BAD - visual spinner only
export function Button({ loading, children, ...props }) {
  return (
    <button {...props}>
      {loading ? <Spinner /> : children}
    </button>
  )
}

// GOOD - aria-busy with announcement
export function Button({ loading, children, ...props }) {
  return (
    <button
      aria-busy={loading}
      disabled={loading}
      {...props}
    >
      {loading && <Spinner className="mr-2 h-4 w-4 animate-spin" />}
      {children}
      {loading && <span className="sr-only">Loading...</span>}
    </button>
  )
}
```

## Review Questions

1. Are focus-visible styles used instead of focus?
2. Is aria-invalid set for error states with describedby?
3. Do disabled elements have both disabled and aria-disabled?
4. Are icon-only buttons labeled with sr-only text or aria-label?
5. Do custom interactive elements support keyboard navigation?
6. Is state conveyed through more than just color?
7. Are loading states announced with aria-busy?
