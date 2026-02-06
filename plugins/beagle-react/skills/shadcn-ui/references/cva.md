# Class Variance Authority (CVA) Reference

This document covers CVA patterns used in shadcn/ui for variant-based styling with Tailwind CSS.

## Basic CVA Pattern

```tsx
import { cva, type VariantProps } from "class-variance-authority"

const componentVariants = cva(
  // Base classes applied to all variants
  "base-class-1 base-class-2",
  {
    variants: {
      // Variant dimension name
      variantName: {
        // Variant option: classes
        option1: "classes-for-option-1",
        option2: "classes-for-option-2",
      },
    },
    defaultVariants: {
      variantName: "option1",
    },
  }
)

// Extract TypeScript types from the variant definition
type ComponentVariants = VariantProps<typeof componentVariants>
```

## Button Variants Example

```tsx
const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-white hover:bg-destructive/90",
        outline: "border bg-background shadow-xs hover:bg-accent",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2",
        sm: "h-8 rounded-md gap-1.5 px-3",
        lg: "h-10 rounded-md px-6",
        icon: "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)
```

**Usage in Component:**
```tsx
function Button({
  className,
  variant,
  size,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants>) {
  return (
    <button
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}
```

## Compound Variants

Compound variants apply classes when multiple variant conditions are met simultaneously.

```tsx
const buttonVariants = cva(
  "base-classes",
  {
    variants: {
      variant: {
        default: "bg-primary",
        outline: "border",
      },
      size: {
        sm: "h-8",
        lg: "h-12",
      },
      disabled: {
        true: "opacity-50",
        false: "",
      },
    },
    compoundVariants: [
      {
        // When variant=outline AND size=lg
        variant: "outline",
        size: "lg",
        class: "border-2", // Use thicker border
      },
      {
        // When variant=default AND disabled=true
        variant: "default",
        disabled: true,
        class: "bg-primary/50", // Dim the background
      },
    ],
    defaultVariants: {
      variant: "default",
      size: "sm",
      disabled: false,
    },
  }
)
```

## Sidebar Menu Button Variants

Real-world example with compound variants from Sidebar component:

```tsx
const sidebarMenuButtonVariants = cva(
  "peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md p-2 text-left text-sm outline-hidden ring-sidebar-ring transition-[width,height,padding] hover:bg-sidebar-accent focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50 group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:p-2!",
  {
    variants: {
      variant: {
        default: "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
        outline:
          "bg-background shadow-[0_0_0_1px_hsl(var(--sidebar-border))] hover:shadow-[0_0_0_1px_hsl(var(--sidebar-accent))]",
      },
      size: {
        default: "h-8 text-sm",
        sm: "h-7 text-xs",
        lg: "h-12 text-sm group-data-[collapsible=icon]:p-0!",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)
```

**Key Features:**
- `peer/menu-button` - named peer for sibling selectors
- `group-data-[collapsible=icon]:size-8!` - conditional sizing based on parent state
- `transition-[width,height,padding]` - specific transition properties
- Custom CSS variables: `hsl(var(--sidebar-border))`

## Default Variants

Default variants specify which variant options are used when no props are provided:

```tsx
const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium",
  {
    variants: {
      variant: {
        default: "border-transparent bg-primary text-primary-foreground",
        secondary: "border-transparent bg-secondary text-secondary-foreground",
        destructive: "border-transparent bg-destructive text-white",
        outline: "text-foreground",
      },
    },
    defaultVariants: {
      variant: "default", // Used when no variant prop provided
    },
  }
)

// Usage
<Badge /> // Uses variant="default"
<Badge variant="destructive" /> // Uses variant="destructive"
```

## Responsive Variants with Container Queries

CVA variants can include responsive modifiers and container query classes:

```tsx
const cardVariants = cva(
  "rounded-lg border p-4",
  {
    variants: {
      layout: {
        compact: "gap-2 @container/card:gap-4",
        comfortable: "gap-4 @container/card:gap-6",
        spacious: "gap-6 @container/card:gap-8",
      },
      responsive: {
        true: "flex-col @md:flex-row",
        false: "flex-col",
      },
    },
    defaultVariants: {
      layout: "comfortable",
      responsive: true,
    },
  }
)
```

**Key Features:**
- `@container/card:gap-4` - container query modifier
- `@md:flex-row` - container breakpoint
- Boolean variants for toggleable behavior

## Integration with cn() Utility

CVA works seamlessly with the `cn()` utility for merging class names:

```tsx
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// In component
function Button({
  className,
  variant,
  size,
  ...props
}: React.ComponentProps<"button"> & VariantProps<typeof buttonVariants>) {
  return (
    <button
      className={cn(
        buttonVariants({ variant, size }), // CVA output
        className // User-provided overrides
      )}
      {...props}
    />
  )
}
```

**How it works:**
1. `buttonVariants({ variant, size })` generates variant classes
2. User's `className` prop can override specific properties
3. `clsx()` conditionally combines classes
4. `twMerge()` intelligently merges Tailwind classes, resolving conflicts

## Type Extraction

Extract TypeScript types from variant definitions:

```tsx
import { type VariantProps } from "class-variance-authority"

const buttonVariants = cva("base", {
  variants: {
    variant: { default: "", destructive: "" },
    size: { sm: "", md: "", lg: "" },
  },
})

// Extract types for use in component props
type ButtonVariants = VariantProps<typeof buttonVariants>
// Result:
// {
//   variant?: "default" | "destructive"
//   size?: "sm" | "md" | "lg"
// }

// Use in component
interface ButtonProps extends React.ComponentProps<"button">, ButtonVariants {
  asChild?: boolean
}
```

## Export Pattern

Always export both the component and the variants for reusability:

```tsx
const buttonVariants = cva(/* ... */)

function Button({ ... }) {
  // Implementation
}

// Export both for external use
export { Button, buttonVariants }
```

**Why export variants:**
- Allows style reuse in other components
- Enables composition of variant styles
- Supports extending components with same styling

**Example:**
```tsx
import { buttonVariants } from "@/components/ui/button"

function CustomButton() {
  return (
    <a
      className={cn(
        buttonVariants({ variant: "outline", size: "lg" }),
        "custom-additional-classes"
      )}
    >
      Link styled as button
    </a>
  )
}
```

## Advanced Pattern: Nullable Variants

Handle optional variant states with explicit null/undefined handling:

```tsx
const alertVariants = cva(
  "rounded-lg border p-4",
  {
    variants: {
      severity: {
        info: "border-blue-500 bg-blue-50",
        warning: "border-yellow-500 bg-yellow-50",
        error: "border-red-500 bg-red-50",
        success: "border-green-500 bg-green-50",
      },
      dismissible: {
        true: "pr-10",
        false: "pr-4",
      },
    },
    // No defaultVariants means undefined is valid
  }
)

// TypeScript allows undefined
function Alert({
  severity,
  dismissible = false,
}: VariantProps<typeof alertVariants>) {
  // severity can be undefined
  return <div className={cn(alertVariants({ severity, dismissible }))} />
}
```

## Performance Considerations

CVA generates static classes that can be tree-shaken:

```tsx
// Good: Variants are statically analyzable
const buttonVariants = cva("base", {
  variants: {
    variant: {
      primary: "bg-blue-500",
      secondary: "bg-gray-500",
    },
  },
})

// Avoid: Dynamic class generation loses tree-shaking
const dynamicButton = (color: string) => cn(`bg-${color}-500`)
```

**Best Practices:**
- Define all variant options statically
- Use CVA for variant-based styling, not arbitrary values
- Leverage defaultVariants for sensible defaults
- Export variants for reusability
- Combine with `cn()` for user overrides
