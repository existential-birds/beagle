# Component Composition

## Critical Anti-Patterns

### 1. `asChild` Without `Slot` (or Base UI `render` Prop Misuse)

**Problem**: Polymorphic rendering via `asChild` requires Radix's `Slot` (from unified `radix-ui` or `@radix-ui/react-slot`) to merge props, refs, and event handlers. In Base UI (`@base-ui/react`) shadcn styles, components use the `render` prop (`useRender`) instead of `asChild`.

```tsx
// BAD - asChild without Slot drops props and refs
export function Button({ asChild, children, ...props }: React.ComponentProps<"button"> & { asChild?: boolean }) {
  if (asChild) {
    return children // WRONG - doesn't merge className, ref, or event handlers
  }
  return <button {...props}>{children}</button>
}

// GOOD (Radix UI unified package — current shadcn default)
import { Slot } from "radix-ui" // or: import { Slot } from "@radix-ui/react-slot"

export function Button({
  asChild = false,
  className,
  variant,
  size,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button" // Note: `@radix-ui/react-slot` exports `Slot` directly

  return (
    <Comp
      data-slot="button"
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  )
}

// GOOD (Base UI `@base-ui/react` style — uses `render` prop instead of `asChild`)
import { useRender } from "@base-ui/react/use-render"
import { mergeProps } from "@base-ui/react/merge-props"

export function BaseUiButton({
  render,
  className,
  variant,
  size,
  ...props
}: useRender.ComponentProps<"button"> & VariantProps<typeof buttonVariants>) {
  return useRender({
    defaultTagName: "button",
    render,
    props: mergeProps<"button">(
      { className: cn(buttonVariants({ variant, size }), className) },
      props
    ),
  })
}
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

// GOOD - using Context
const CardContext = React.createContext<{ variant?: string }>({})

export function Card({ variant = "default", children, ...props }: React.ComponentProps<"div"> & { variant?: string }) {
  return (
    <CardContext.Provider value={{ variant }}>
      <div className={cn(cardVariants({ variant }))} {...props}>
        {children}
      </div>
    </CardContext.Provider>
  )
}

export function CardHeader({ className, ...props }: React.ComponentProps<"div">) {
  const { variant } = React.useContext(CardContext)
  return (
    <div
      className={cn(headerVariants({ variant }), className)}
      {...props}
    />
  )
}
```

### 3. Slot Props Not Merged Correctly

**Problem**: When using `asChild` or custom click handlers, passing `onClick={handler}` after `{...props}` (or before without composition) can overwrite the consumer's `onClick`.

```tsx
// BAD - props collision overwrites consumer's onClick
export function Button({ asChild, onClick, ...props }: React.ComponentProps<"button"> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : "button"
  return <Comp {...props} onClick={onClick} />
}

// GOOD - compose handlers cleanly
export function Button({ asChild, onClick, ...props }: React.ComponentProps<"button"> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      {...props}
      onClick={(e: React.MouseEvent<HTMLButtonElement>) => {
        onClick?.(e)
        if (!e.defaultPrevented) {
          // Component's internal click logic
        }
      }}
    />
  )
}
```

### 4. Dropping `ref` Prop in Wrapper Components (React 19 vs React 18)

**Problem**: In React 19, `ref` is passed as a standard prop inside `React.ComponentProps<...>` — `React.forwardRef` is no longer required and should NOT be demanded by reviewers. However, wrappers that destructure specific props and pass a custom subset without spreading `...props` (or explicitly passing `ref`) will still drop `ref`.

```tsx
// BAD - drops ref because props aren't spread and ref isn't forwarded
export function Button({ asChild, className, children }: { asChild?: boolean; className?: string; children: React.ReactNode }) {
  const Comp = asChild ? Slot.Root : "button"
  return <Comp className={className}>{children}</Comp> // ref is lost!
}

// GOOD (React 19 / modern shadcn) - `ref` is included in React.ComponentProps<"button">
export function Button({
  asChild = false,
  className,
  ...props
}: React.ComponentProps<"button"> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : "button"
  return <Comp className={className} {...props} />
}
```

*(Only flag missing `React.forwardRef` if the project explicitly targets React 18 or earlier and passes `ref` to a function component that drops it.)*

### 5. Polymorphic Components Without Type Safety

**Problem**: Using an `as` prop without proper TypeScript typing loses type safety.

```tsx
// BAD - no type safety
export function Text({ as = "p", ...props }) {
  const Comp = as
  return <Comp {...props} />
}

// GOOD - typed polymorphic component (React 19 ComponentPropsWithRef includes ref)
import type { ElementType, ComponentPropsWithRef } from "react"

type PolymorphicProps<E extends ElementType> = {
  as?: E
} & Omit<ComponentPropsWithRef<E>, "as">

export function Text<E extends ElementType = "p">({
  as,
  className,
  ...props
}: PolymorphicProps<E>) {
  const Comp: ElementType = as || "p"

  return (
    <Comp
      className={cn("text-base", className)}
      {...props}
    />
  )
}
```

### 6. Overusing `React.cloneElement`

**Problem**: `cloneElement` is fragile and breaks with fragments, context, or wrapped children.

```tsx
// BAD - cloneElement everywhere
export function List({ spacing, children }) {
  return (
    <ul>
      {React.Children.map(children, child =>
        React.cloneElement(child, { spacing })
      )}
    </ul>
  )
}

// GOOD - use Context
const ListContext = React.createContext({ spacing: "md" })

export function List({ spacing = "md", children, ...props }: React.ComponentProps<"ul"> & { spacing?: string }) {
  return (
    <ListContext.Provider value={{ spacing }}>
      <ul {...props}>{children}</ul>
    </ListContext.Provider>
  )
}

export function ListItem({ className, ...props }: React.ComponentProps<"li">) {
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

1. Does `asChild` use `Slot` from `radix-ui` / `@radix-ui/react-slot` (or does Base UI use `useRender` / `render` prop)?
2. Are compound components using Context for state sharing?
3. Are `ref` and HTML attributes preserved via `React.ComponentProps<...>` spread (without erroneously demanding `React.forwardRef` in React 19)?
4. Are event handlers composed rather than overwritten when wrapping slots?
5. Is `React.cloneElement` avoided in favor of Context?
