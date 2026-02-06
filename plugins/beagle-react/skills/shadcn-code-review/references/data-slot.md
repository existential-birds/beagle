# data-slot Pattern

## Critical Anti-Patterns

### 1. Missing data-slot Attributes

**Problem**: Component parts cannot be targeted by consumers for custom styling without data-slot.

```tsx
// BAD - no way to target subcomponents
export function Card({ children, ...props }) {
  return (
    <div className="border rounded-lg" {...props}>
      {children}
    </div>
  )
}

export function CardHeader({ children, ...props }) {
  return (
    <div className="p-6" {...props}>
      {children}
    </div>
  )
}

// Consumer cannot style CardHeader inside Card without fragile selectors:
<Card className="[&>div]:bg-red-500"> {/* BRITTLE - breaks if structure changes */}
  <CardHeader>Title</CardHeader>
</Card>

// GOOD - data-slot for targetable parts
export function Card({ children, ...props }) {
  return (
    <div className="border rounded-lg" data-slot="card" {...props}>
      {children}
    </div>
  )
}

export function CardHeader({ children, ...props }) {
  return (
    <div className="p-6" data-slot="card-header" {...props}>
      {children}
    </div>
  )
}

// Consumer can target with stable selector:
<Card className="[&_[data-slot=card-header]]:bg-red-500">
  <CardHeader>Title</CardHeader>
</Card>
```

### 2. Not Using has() Selectors for State-Based Styling

**Problem**: Parent styling based on child state requires data-slot + has().

```tsx
// BAD - manual state prop threading
export function Card({ hasError, children }) {
  return (
    <div className={cn("border", hasError && "border-red-500")}>
      {children}
    </div>
  )
}

export function CardContent({ error, children }) {
  return (
    <div>
      {error && <p className="text-red-500">{error}</p>}
      {children}
    </div>
  )
}

// Usage is verbose:
const [error, setError] = useState("")
<Card hasError={!!error}>
  <CardContent error={error}>...</CardContent>
</Card>

// GOOD - has() selector with data-slot
export function Card({ children, ...props }) {
  return (
    <div
      className="border has-[[data-slot=card-content][data-error]]:border-destructive"
      data-slot="card"
      {...props}
    >
      {children}
    </div>
  )
}

export function CardContent({ error, children, ...props }) {
  return (
    <div data-slot="card-content" data-error={error ? "" : undefined} {...props}>
      {error && (
        <p className="text-sm text-destructive" data-slot="card-error">
          {error}
        </p>
      )}
      {children}
    </div>
  )
}

// Usage is clean:
<Card>
  <CardContent error={error}>...</CardContent>
</Card>
```

### 3. Incorrect CSS Targeting Without data-slot

**Problem**: Targeting by element type or class is fragile and breaks with structural changes.

```tsx
// BAD - targeting by element type
const selectVariants = cva(
  // Targeting trigger button directly - fragile
  "[&>button]:flex [&>button]:items-center [&>button]:justify-between",
  // Targeting value span - fragile
  "[&>button>span]:text-sm [&>button>span]:text-muted-foreground"
)

export function Select({ children }) {
  return <div className={selectVariants()}>{children}</div>
}

// GOOD - targeting by data-slot
const selectVariants = cva(
  "[&_[data-slot=select-trigger]]:flex [&_[data-slot=select-trigger]]:items-center",
  "[&_[data-slot=select-value]]:text-sm [&_[data-slot=select-value]]:text-muted-foreground"
)

export function Select({ children, ...props }) {
  return (
    <div className={selectVariants()} data-slot="select" {...props}>
      {children}
    </div>
  )
}

export function SelectTrigger({ children, ...props }) {
  return (
    <button data-slot="select-trigger" {...props}>
      {children}
    </button>
  )
}

export function SelectValue({ children, ...props }) {
  return (
    <span data-slot="select-value" {...props}>
      {children}
    </span>
  )
}
```

### 4. data-state Without data-slot

**Problem**: data-state is useful but needs data-slot for scoped targeting.

```tsx
// BAD - data-state only, no scoping
export function Accordion({ open, children }) {
  return (
    <div data-state={open ? "open" : "closed"}>
      {children}
    </div>
  )
}

export function AccordionTrigger({ children }) {
  return <button>{children}</button>
}

// Consumer cannot target trigger based on parent state:
// Can't write: [&[data-state=open]_button]:rotate-180

// GOOD - data-slot + data-state
export function Accordion({ open, children, ...props }) {
  return (
    <div
      data-slot="accordion"
      data-state={open ? "open" : "closed"}
      {...props}
    >
      {children}
    </div>
  )
}

export function AccordionTrigger({ children, ...props }) {
  return (
    <button data-slot="accordion-trigger" {...props}>
      {children}
    </button>
  )
}

// Consumer can target:
<Accordion className="[&[data-state=open]_[data-slot=accordion-trigger]]:rotate-180">
  <AccordionTrigger>...</AccordionTrigger>
</Accordion>

// Or use has():
<Accordion className="has-[[data-slot=accordion-trigger][aria-expanded=true]]:bg-accent">
```

### 5. Nested Component Targeting

**Problem**: Deeply nested components need data-slot for stable targeting.

```tsx
// BAD - descendant selectors by element
export function Table({ children }) {
  return (
    <table className="[&_thead_tr]:border-b [&_tbody_tr]:border-b [&_td]:p-4">
      {children}
    </table>
  )
}

// Breaks if you add divs or other elements in structure

// GOOD - data-slot for all parts
export function Table({ children, ...props }) {
  return (
    <table
      data-slot="table"
      className="[&_[data-slot=table-header-row]]:border-b [&_[data-slot=table-row]]:border-b [&_[data-slot=table-cell]]:p-4"
      {...props}
    >
      {children}
    </table>
  )
}

export function TableHeader({ children, ...props }) {
  return (
    <thead data-slot="table-header" {...props}>
      {children}
    </thead>
  )
}

export function TableRow({ children, ...props }) {
  return (
    <tr data-slot="table-row" {...props}>
      {children}
    </tr>
  )
}

export function TableCell({ children, ...props }) {
  return (
    <td data-slot="table-cell" {...props}>
      {children}
    </td>
  )
}
```

### 6. Using data-slot for State Instead of data-state

**Problem**: data-slot is for targeting parts, data-state is for state values.

```tsx
// BAD - using data-slot for state
export function Tab({ active, children }) {
  return (
    <button
      data-slot={active ? "tab-active" : "tab-inactive"} // WRONG - use data-state
    >
      {children}
    </button>
  )
}

// GOOD - data-slot for type, data-state for state
export function Tab({ active, children, ...props }) {
  return (
    <button
      data-slot="tab"
      data-state={active ? "active" : "inactive"}
      role="tab"
      aria-selected={active}
      {...props}
    >
      {children}
    </button>
  )
}

// Targeting:
<TabList className="[&_[data-slot=tab][data-state=active]]:border-b-2">
  <Tab active>...</Tab>
</TabList>
```

## Review Questions

1. Do all component parts have data-slot attributes?
2. Are has() selectors used for state-based parent styling?
3. Is CSS targeting using data-slot instead of element types?
4. Are data-state and data-slot used together for stateful components?
5. Can consumers reliably target nested component parts?
6. Is data-slot used for identification and data-state for values?
