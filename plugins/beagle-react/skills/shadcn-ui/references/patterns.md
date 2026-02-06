# shadcn/ui Component Patterns

This document covers architectural patterns used in shadcn/ui components.

## Table of Contents

- [Compound Component Pattern](#compound-component-pattern)
- [asChild / Slot Polymorphism](#aschild--slot-polymorphism)
- [Controlled vs Uncontrolled State](#controlled-vs-uncontrolled-state)
- [Context for Complex Components](#context-for-complex-components)
- [data-slot CSS Targeting](#data-slot-css-targeting)
- [has() Selector Usage](#has-selector-usage)

## Compound Component Pattern

Compound components split complex UI into multiple related components that work together.

### Card Example

```tsx
// Export multiple related components
export {
  Card,          // Container
  CardHeader,    // Header section
  CardTitle,     // Title element
  CardDescription, // Description text
  CardContent,   // Main content area
  CardFooter,    // Footer section
  CardAction,    // Action area (optional)
}

// Usage - compose as needed
<Card>
  <CardHeader>
    <CardTitle>Dashboard</CardTitle>
    <CardDescription>Overview of your account</CardDescription>
    <CardAction>
      <Button>Settings</Button>
    </CardAction>
  </CardHeader>
  <CardContent>
    Main content here
  </CardContent>
  <CardFooter>
    Footer content
  </CardFooter>
</Card>
```

**Key Benefits:**
- Flexible composition - use only needed parts
- Clear semantic structure
- Each component handles its own styling
- Type-safe with independent prop types

### Dialog Example

```tsx
export {
  Dialog,              // Root component (state container)
  DialogTrigger,       // Opens the dialog
  DialogContent,       // Modal content wrapper
  DialogHeader,        // Header section
  DialogTitle,         // Title (accessibility required)
  DialogDescription,   // Description (accessibility)
  DialogFooter,        // Footer for actions
  DialogClose,         // Close button
}

// Usage
<Dialog>
  <DialogTrigger asChild>
    <Button>Open</Button>
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Confirm Action</DialogTitle>
      <DialogDescription>This action cannot be undone.</DialogDescription>
    </DialogHeader>
    <DialogFooter>
      <DialogClose asChild>
        <Button variant="outline">Cancel</Button>
      </DialogClose>
      <Button>Confirm</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

### Sidebar Context Example

Complex compound components use Context for shared state:

```tsx
// 1. Define context type
type SidebarContextProps = {
  state: "expanded" | "collapsed"
  open: boolean
  setOpen: (open: boolean) => void
  toggleSidebar: () => void
  isMobile: boolean
}

// 2. Create context
const SidebarContext = React.createContext<SidebarContextProps | null>(null)

// 3. Custom hook for consuming context
function useSidebar() {
  const context = React.useContext(SidebarContext)
  if (!context) {
    throw new Error("useSidebar must be used within a SidebarProvider.")
  }
  return context
}

// 4. Provider component
function SidebarProvider({ children, defaultOpen = true, ...props }) {
  const [open, setOpen] = React.useState(defaultOpen)
  const isMobile = useIsMobile()

  const toggleSidebar = React.useCallback(() => {
    setOpen((open) => !open)
  }, [])

  const contextValue = React.useMemo(
    () => ({
      state: open ? "expanded" : "collapsed",
      open,
      setOpen,
      toggleSidebar,
      isMobile,
    }),
    [open, setOpen, toggleSidebar, isMobile]
  )

  return (
    <SidebarContext.Provider value={contextValue}>
      {children}
    </SidebarContext.Provider>
  )
}

// 5. Child components consume context
function SidebarTrigger({ ...props }) {
  const { toggleSidebar } = useSidebar()

  return (
    <Button onClick={toggleSidebar} {...props}>
      Toggle
    </Button>
  )
}

// Usage
<SidebarProvider>
  <Sidebar>
    <SidebarHeader>Header</SidebarHeader>
    <SidebarContent>Content</SidebarContent>
  </Sidebar>
  <SidebarTrigger />
</SidebarProvider>
```

## asChild / Slot Polymorphism

The `asChild` pattern allows components to render as different elements while preserving styling and behavior.

### Basic Pattern

```tsx
import { Slot } from "@radix-ui/react-slot"

function Button({
  asChild = false,
  className,
  ...props
}: React.ComponentProps<"button"> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      className={cn(buttonVariants({ className }))}
      {...props}
    />
  )
}
```

### Usage Examples

```tsx
// Renders as <button>
<Button>Click me</Button>

// Renders as <a> with button styling
<Button asChild>
  <a href="/home">Home</a>
</Button>

// Renders as Next.js Link
<Button asChild>
  <Link href="/dashboard">Dashboard</Link>
</Button>

// Renders as custom component
<Button asChild>
  <motion.div whileHover={{ scale: 1.05 }}>
    Animated Button
  </motion.div>
</Button>
```

### How Slot Works

The `Slot` component from Radix UI merges props and classes from the wrapper onto the child:

```tsx
// With asChild=true
<Button asChild className="custom-class" onClick={handler}>
  <a href="/home">Home</a>
</Button>

// Renders as:
<a
  href="/home"
  className="button-variant-classes custom-class"
  onClick={handler}
>
  Home
</a>
```

### Badge with asChild

```tsx
function Badge({
  asChild = false,
  variant,
  className,
  ...props
}: React.ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> &
  { asChild?: boolean }) {
  const Comp = asChild ? Slot : "span"

  return (
    <Comp
      data-slot="badge"
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  )
}

// Usage
<Badge asChild variant="destructive">
  <a href="/alerts">5 Alerts</a>
</Badge>
```

## Controlled vs Uncontrolled State

Components support both controlled (parent manages state) and uncontrolled (internal state) patterns.

### Uncontrolled Pattern

```tsx
function Checkbox({ defaultChecked = false, ...props }) {
  const [checked, setChecked] = React.useState(defaultChecked)

  return (
    <input
      type="checkbox"
      checked={checked}
      onChange={(e) => setChecked(e.target.checked)}
      {...props}
    />
  )
}

// Usage - component manages own state
<Checkbox defaultChecked={true} />
```

### Controlled Pattern

```tsx
function Checkbox({ checked, onCheckedChange, ...props }) {
  return (
    <input
      type="checkbox"
      checked={checked}
      onChange={(e) => onCheckedChange?.(e.target.checked)}
      {...props}
    />
  )
}

// Usage - parent controls state
const [checked, setChecked] = useState(false)
<Checkbox checked={checked} onCheckedChange={setChecked} />
```

### Hybrid Pattern (Sidebar)

Support both controlled and uncontrolled usage:

```tsx
function SidebarProvider({
  defaultOpen = true,
  open: openProp,
  onOpenChange: setOpenProp,
  ...props
}) {
  // Internal state
  const [_open, _setOpen] = React.useState(defaultOpen)

  // Use prop if provided, otherwise internal state
  const open = openProp ?? _open

  const setOpen = React.useCallback(
    (value: boolean | ((value: boolean) => boolean)) => {
      const openState = typeof value === "function" ? value(open) : value

      // Call prop callback if provided
      if (setOpenProp) {
        setOpenProp(openState)
      } else {
        // Otherwise update internal state
        _setOpen(openState)
      }
    },
    [setOpenProp, open]
  )

  return (
    <SidebarContext.Provider value={{ open, setOpen }}>
      {children}
    </SidebarContext.Provider>
  )
}

// Uncontrolled usage
<SidebarProvider defaultOpen={false}>
  <Sidebar />
</SidebarProvider>

// Controlled usage
const [sidebarOpen, setSidebarOpen] = useState(true)
<SidebarProvider open={sidebarOpen} onOpenChange={setSidebarOpen}>
  <Sidebar />
</SidebarProvider>
```

## Context for Complex Components

Use React Context for components with multiple children sharing state.

### When to Use Context

- Multiple child components need access to shared state
- Props drilling would be excessive
- State logic is complex (e.g., Sidebar open/collapsed/mobile states)
- Component has plugin/extension architecture

### Form Context Example

```tsx
type FormContextValue = {
  formId: string
  errors: Record<string, string>
  register: (name: string) => void
  unregister: (name: string) => void
}

const FormContext = React.createContext<FormContextValue | null>(null)

function useFormContext() {
  const context = React.useContext(FormContext)
  if (!context) {
    throw new Error("Form components must be used within Form")
  }
  return context
}

function Form({ children, onSubmit }: FormProps) {
  const [errors, setErrors] = React.useState({})
  const formId = React.useId()

  const contextValue = React.useMemo(
    () => ({
      formId,
      errors,
      register: (name) => { /* ... */ },
      unregister: (name) => { /* ... */ },
    }),
    [formId, errors]
  )

  return (
    <FormContext.Provider value={contextValue}>
      <form id={formId} onSubmit={onSubmit}>
        {children}
      </form>
    </FormContext.Provider>
  )
}

function FormField({ name, ...props }) {
  const { formId, errors, register } = useFormContext()

  React.useEffect(() => {
    register(name)
    return () => unregister(name)
  }, [name])

  return (
    <div>
      <input id={`${formId}-${name}`} {...props} />
      {errors[name] && <span>{errors[name]}</span>}
    </div>
  )
}
```

### Best Practices

1. **Memoize context value** to prevent unnecessary re-renders:
```tsx
const contextValue = React.useMemo(
  () => ({ state, setState, helpers }),
  [state, setState, helpers]
)
```

2. **Type the context properly**:
```tsx
const Context = React.createContext<ContextType | null>(null)
```

3. **Provide helpful error messages**:
```tsx
if (!context) {
  throw new Error("useComponent must be used within ComponentProvider")
}
```

4. **Use custom hooks** for consuming context:
```tsx
function useComponent() {
  const context = React.useContext(ComponentContext)
  if (!context) throw new Error("...")
  return context
}
```

## data-slot CSS Targeting

Every shadcn/ui component includes a `data-slot` attribute for CSS targeting.

### Basic Usage

```tsx
function Button({ ...props }) {
  return <button data-slot="button" {...props} />
}

function Card({ ...props }) {
  return <div data-slot="card" {...props} />
}
```

**CSS Targeting:**
```css
/* Target all buttons */
[data-slot="button"] {
  /* styles */
}

/* Target buttons within cards */
[data-slot="card"] [data-slot="button"] {
  /* styles */
}
```

**Tailwind Usage:**
```tsx
<div className="[&_[data-slot=button]]:shadow-lg">
  <Button>Styled via parent</Button>
</div>
```

### Advanced Patterns

#### Conditional Layouts Based on Slots

```tsx
function CardHeader({ className, ...props }) {
  return (
    <div
      data-slot="card-header"
      className={cn(
        "grid gap-2 px-6",
        // If CardAction is present, use two columns
        "has-data-[slot=card-action]:grid-cols-[1fr_auto]",
        className
      )}
      {...props}
    />
  )
}

// Usage
<CardHeader>
  <CardTitle>Title</CardTitle>
  {/* When CardAction is added, layout changes automatically */}
  <CardAction>
    <Button>Action</Button>
  </CardAction>
</CardHeader>
```

#### Parent Selectors with Slots

```tsx
function CardFooter({ className, ...props }) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        "flex items-center px-6",
        // If parent has .border-t class, add top padding
        "[.border-t]:pt-6",
        className
      )}
      {...props}
    />
  )
}

// Usage
<Card className="border-t">
  <CardFooter>Footer gets top padding</CardFooter>
</Card>
```

#### Multiple data-* Attributes

Components can have multiple data attributes for different purposes:

```tsx
function Sidebar({ variant, side, collapsible, ...props }) {
  return (
    <div
      data-slot="sidebar"
      data-variant={variant}
      data-side={side}
      data-collapsible={collapsible}
      className={cn(
        "group",
        "group-data-[variant=floating]:rounded-lg",
        "group-data-[side=left]:border-r",
        "group-data-[collapsible=icon]:w-12"
      )}
      {...props}
    />
  )
}
```

## has() Selector Usage

Modern CSS `:has()` selector enables parent styling based on children.

### Basic Pattern

```tsx
// Button with icon adjusts padding
<button className="px-4 has-[>svg]:px-3">
  <Icon />
  Text
</button>
```

**How it works:**
- `has-[>svg]` - if button has direct child `<svg>`
- Apply `px-3` instead of base `px-4`
- Automatically adjusts based on content

### Size Variants with Icons

```tsx
const buttonVariants = cva("...", {
  variants: {
    size: {
      default: "h-9 px-4 py-2 has-[>svg]:px-3",
      sm: "h-8 px-3 has-[>svg]:px-2.5",
      lg: "h-10 px-6 has-[>svg]:px-4",
    },
  },
})

// Padding adjusts automatically
<Button size="sm">
  <Icon />
  Text
</Button>
```

### CardHeader Grid Layout

```tsx
function CardHeader({ className, ...props }) {
  return (
    <div
      className={cn(
        "grid gap-2",
        // Single column by default
        "grid-rows-[auto_auto]",
        // When CardAction exists, add second column
        "has-data-[slot=card-action]:grid-cols-[1fr_auto]",
        className
      )}
      {...props}
    />
  )
}

// Layout adapts based on children
<CardHeader>
  <CardTitle>Title</CardTitle>
  <CardDescription>Description</CardDescription>
  {/* Adding this changes layout to two columns */}
  <CardAction>
    <Button>Action</Button>
  </CardAction>
</CardHeader>
```

### Conditional Border Padding

```tsx
function CardFooter({ className, ...props }) {
  return (
    <div
      className={cn(
        "flex items-center px-6",
        // Add padding only if parent has border-t class
        "[.border-t]:pt-6",
        className
      )}
      {...props}
    />
  )
}
```

### Group-based Conditional Styling

```tsx
function SidebarGroupLabel({ className, ...props }) {
  return (
    <div
      className={cn(
        "flex h-8 items-center px-2",
        // Hide when sidebar is collapsed (icon mode)
        "group-data-[collapsible=icon]:-mt-8",
        "group-data-[collapsible=icon]:opacity-0",
        className
      )}
      {...props}
    />
  )
}

// Parent controls child visibility
<div className="group" data-collapsible="icon">
  <SidebarGroupLabel>Hidden in icon mode</SidebarGroupLabel>
</div>
```

### Peer-based Interactions

```tsx
function SidebarMenuButton({ size, isActive, className, ...props }) {
  return (
    <button
      data-slot="sidebar-menu-button"
      data-size={size}
      data-active={isActive}
      className={cn(
        "peer/menu-button",
        "flex items-center gap-2",
        className
      )}
      {...props}
    />
  )
}

function SidebarMenuAction({ showOnHover, className, ...props }) {
  return (
    <button
      data-slot="sidebar-menu-action"
      className={cn(
        "absolute right-1",
        // Show when peer (menu button) is hovered
        showOnHover && "peer-hover/menu-button:opacity-100 md:opacity-0",
        // Highlight when peer is active
        "peer-data-[active=true]/menu-button:text-accent-foreground",
        className
      )}
      {...props}
    />
  )
}

// Usage
<div>
  <SidebarMenuButton isActive={true}>Menu</SidebarMenuButton>
  <SidebarMenuAction showOnHover />
</div>
```

### Browser Support

The `:has()` selector is supported in all modern browsers (Chrome 105+, Safari 15.4+, Firefox 121+). For older browsers, provide fallback styling:

```tsx
className={cn(
  // Fallback for browsers without :has() support
  "px-4",
  // Modern browsers with :has() support
  "has-[>svg]:px-3",
)}
```
