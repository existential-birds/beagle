# Component Composition

## Critical Anti-Patterns

### 1. asChild Without Slot

**Problem**: The asChild pattern requires @radix-ui/react-slot to work correctly.

```tsx
// BAD - asChild without Slot
export function Button({ asChild, children, ...props }) {
  if (asChild) {
    return children // WRONG - doesn't merge props
  }
  return <button {...props}>{children}</button>
}

// Usage breaks:
<Button asChild>
  <Link href="/">Home</Link> {/* Link doesn't receive Button's props */}
</Button>

// GOOD - using Slot
import { Slot } from "@radix-ui/react-slot"

export function Button({ asChild, className, variant, size, ...props }) {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  )
}

// Usage works correctly:
<Button asChild variant="outline">
  <Link href="/">Home</Link> {/* Link receives variant styles and all props */}
</Button>
```

### 2. Missing Context for Compound Components

**Problem**: Component parts cannot communicate state without Context.

```tsx
// BAD - no context, state passed via props (brittle)
export function Card({ variant, children }) {
  return (
    <div className={cardVariants({ variant })}>
      {React.Children.map(children, child =>
        React.cloneElement(child, { variant }) // WRONG - fragile, breaks with fragments
      )}
    </div>
  )
}

export function CardHeader({ variant, children }) {
  return <div className={headerVariants({ variant })}>{children}</div>
}

// GOOD - using Context
const CardContext = React.createContext<{ variant?: string }>({})

export function Card({ variant = "default", children, ...props }) {
  return (
    <CardContext.Provider value={{ variant }}>
      <div className={cn(cardVariants({ variant }))} {...props}>
        {children}
      </div>
    </CardContext.Provider>
  )
}

export function CardHeader({ className, ...props }) {
  const { variant } = React.useContext(CardContext)
  return (
    <div
      className={cn(headerVariants({ variant }), className)}
      {...props}
    />
  )
}

// Usage is clean:
<Card variant="elevated">
  <CardHeader>Title</CardHeader> {/* Automatically gets variant */}
  <CardContent>Content</CardContent>
</Card>
```

### 3. Slot Props Not Merged Correctly

**Problem**: When using asChild, child props must be merged with component props.

```tsx
// BAD - props collision
export function Button({ asChild, onClick, ...props }) {
  const Comp = asChild ? Slot : "button"
  return <Comp onClick={onClick} {...props} /> // Child's onClick is overwritten
}

// GOOD - proper prop merging with composeEventHandlers
import { composeEventHandlers } from "@radix-ui/primitive"
import { Slot } from "@radix-ui/react-slot"

export function Button({ asChild, onClick, ...props }) {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      {...props}
      onClick={composeEventHandlers(onClick, (e) => {
        // Component's onClick logic
      })}
    />
  )
}

// Or use Radix's component approach:
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ asChild = false, onClick, ...props }, ref) => {
    const Comp = asChild ? Slot : "button"

    return (
      <Comp
        ref={ref}
        onClick={onClick}
        {...props}
      />
    )
  }
)
```

### 4. Not Forwarding Refs with asChild

**Problem**: Refs break when using asChild without forwardRef.

```tsx
// BAD - ref not forwarded
export function Button({ asChild, ...props }) {
  const Comp = asChild ? Slot : "button"
  return <Comp {...props} /> // ref won't work
}

// Usage breaks:
const ref = useRef()
<Button ref={ref} asChild>
  <Link>Home</Link> {/* ref is lost */}
</Button>

// GOOD - forwardRef with asChild
export const Button = React.forwardRef<
  HTMLButtonElement,
  ButtonProps
>(({ asChild = false, className, variant, size, ...props }, ref) => {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      className={cn(buttonVariants({ variant, size }), className)}
      ref={ref}
      {...props}
    />
  )
})
Button.displayName = "Button"
```

### 5. Polymorphic Components Without Type Safety

**Problem**: Using 'as' prop without proper TypeScript typing loses type safety.

```tsx
// BAD - no type safety
export function Text({ as = "p", ...props }) {
  const Comp = as
  return <Comp {...props} /> // No type checking for Comp-specific props
}

// GOOD - typed polymorphic component
import { ElementType, ComponentPropsWithoutRef } from "react"

type PolymorphicProps<E extends ElementType> = {
  as?: E
} & ComponentPropsWithoutRef<E>

export function Text<E extends ElementType = "p">({
  as,
  className,
  ...props
}: PolymorphicProps<E>) {
  const Comp = as || "p"

  return (
    <Comp
      className={cn("text-base", className)}
      {...props}
    />
  )
}

// Usage is type-safe:
<Text as="h1" onClick={(e) => {/* e is typed correctly */}}>Title</Text>
<Text as="a" href="/about">Link</Text> {/* href required for 'a' */}
```

### 6. Overusing React.cloneElement

**Problem**: cloneElement is fragile and breaks with fragments, context, or complex children.

```tsx
// BAD - cloneElement everywhere
export function List({ spacing, children }) {
  return (
    <ul>
      {React.Children.map(children, child =>
        React.cloneElement(child, { spacing }) // Breaks with fragments, context
      )}
    </ul>
  )
}

// GOOD - use Context
const ListContext = React.createContext({ spacing: "md" })

export function List({ spacing = "md", children, ...props }) {
  return (
    <ListContext.Provider value={{ spacing }}>
      <ul {...props}>{children}</ul>
    </ListContext.Provider>
  )
}

export function ListItem({ className, ...props }) {
  const { spacing } = React.useContext(ListContext)
  return (
    <li
      className={cn(listItemVariants({ spacing }), className)}
      {...props}
    />
  )
}
```

## Review Questions

1. Does asChild use Slot from @radix-ui/react-slot?
2. Are compound components using Context for state sharing?
3. Are refs forwarded with React.forwardRef?
4. Are event handlers composed correctly with asChild?
5. Is React.cloneElement avoided in favor of Context?
