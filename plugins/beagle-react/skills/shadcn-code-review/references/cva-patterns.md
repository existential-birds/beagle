# CVA Patterns

## Critical Anti-Patterns

### 1. className Passed to CVA Instead of cn()

**Problem**: CVA variants cannot be overridden by consumers. The className should be passed to cn() after CVA, not as a CVA variant.

```tsx
// BAD - className in CVA
import { cva } from "class-variance-authority"

const buttonVariants = cva("base-styles", {
  variants: {
    variant: { default: "bg-primary", destructive: "bg-destructive" },
    size: { sm: "h-9", lg: "h-11" },
    className: {}, // WRONG - className is not a variant
  },
})

export function Button({ variant, size, className }) {
  return <button className={buttonVariants({ variant, size })} />
}

// GOOD - className in cn()
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const buttonVariants = cva("base-styles", {
  variants: {
    variant: { default: "bg-primary", destructive: "bg-destructive" },
    size: { sm: "h-9", lg: "h-11" },
  },
  defaultVariants: {
    variant: "default",
    size: "default",
  },
})

export interface ButtonProps extends VariantProps<typeof buttonVariants> {
  className?: string
}

export function Button({ variant, size, className, ...props }: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  )
}
```

### 2. Missing VariantProps Export

**Problem**: Consumers cannot type-check variant props correctly.

```tsx
// BAD - no type export
const buttonVariants = cva(...)

export function Button({ variant, size }: { variant?: string, size?: string }) {
  return <button className={buttonVariants({ variant, size })} />
}

// GOOD - export VariantProps
import { type VariantProps } from "class-variance-authority"

const buttonVariants = cva(...)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

export function Button({ variant, size, className, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />
}
```

### 3. Not Using Compound Variants

**Problem**: Complex state combinations create verbose, repetitive variant definitions.

```tsx
// BAD - manual combinations
const buttonVariants = cva("rounded font-medium", {
  variants: {
    variant: {
      default: "bg-primary text-primary-foreground",
      outline: "border border-input bg-background",
      ghost: "hover:bg-accent hover:text-accent-foreground",
    },
    size: {
      sm: "h-9 px-3 text-xs",
      default: "h-10 px-4 py-2",
      lg: "h-11 px-8",
    },
    // Trying to handle all combinations manually - WRONG
    variantSize: {
      "outline-sm": "border-2", // Don't do this
      "ghost-lg": "hover:bg-accent/50",
    }
  },
})

// GOOD - use compoundVariants
const buttonVariants = cva("rounded font-medium", {
  variants: {
    variant: {
      default: "bg-primary text-primary-foreground",
      outline: "border border-input bg-background",
      ghost: "hover:bg-accent hover:text-accent-foreground",
    },
    size: {
      sm: "h-9 px-3 text-xs",
      default: "h-10 px-4 py-2",
      lg: "h-11 px-8",
    },
  },
  compoundVariants: [
    {
      variant: "outline",
      size: "sm",
      class: "border-2",
    },
    {
      variant: "ghost",
      size: "lg",
      class: "hover:bg-accent/50",
    },
  ],
  defaultVariants: {
    variant: "default",
    size: "default",
  },
})
```

### 4. Hardcoding State Classes Instead of Variants

**Problem**: State-dependent styling should be variants for consistency and reusability.

```tsx
// BAD - hardcoded state classes
export function Input({ disabled, invalid, className }) {
  return (
    <input
      className={cn(
        "rounded border px-3 py-2",
        disabled && "opacity-50 cursor-not-allowed",
        invalid && "border-red-500",
        className
      )}
      disabled={disabled}
    />
  )
}

// GOOD - state variants
const inputVariants = cva("rounded border px-3 py-2", {
  variants: {
    state: {
      default: "",
      invalid: "border-destructive focus-visible:ring-destructive",
      disabled: "opacity-50 cursor-not-allowed",
    },
  },
  defaultVariants: {
    state: "default",
  },
})

export function Input({ disabled, invalid, className, ...props }) {
  const state = disabled ? "disabled" : invalid ? "invalid" : "default"

  return (
    <input
      className={cn(inputVariants({ state }), className)}
      disabled={disabled}
      aria-invalid={invalid}
      {...props}
    />
  )
}
```

### 5. Missing defaultVariants

**Problem**: Component behavior is unpredictable without defaults.

```tsx
// BAD - no defaults
const buttonVariants = cva("base", {
  variants: {
    variant: { default: "bg-primary", outline: "border" },
    size: { sm: "h-9", lg: "h-11" },
  },
  // Missing defaultVariants - what happens with <Button />?
})

// GOOD - explicit defaults
const buttonVariants = cva("base", {
  variants: {
    variant: { default: "bg-primary", outline: "border" },
    size: { sm: "h-9", lg: "h-11" },
  },
  defaultVariants: {
    variant: "default",
    size: "sm",
  },
})
```

## Review Questions

1. Is className passed to cn() after CVA variants?
2. Are VariantProps exported for type safety?
3. Are compound variants used for complex state combinations?
4. Are state-dependent styles defined as variants?
5. Are defaultVariants specified for all variant groups?
