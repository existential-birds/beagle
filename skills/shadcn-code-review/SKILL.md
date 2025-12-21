---
name: shadcn-code-review
description: Reviews shadcn/ui components for CVA patterns, composition with asChild, accessibility states, and data-slot usage. Use when reviewing React components using shadcn/ui, Radix primitives, or Tailwind styling.
---

# shadcn/ui Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| className in CVA, missing VariantProps, compound variants | [references/cva-patterns.md](references/cva-patterns.md) |
| asChild without Slot, missing Context, component composition | [references/composition.md](references/composition.md) |
| Missing focus-visible, aria-invalid, disabled states | [references/accessibility.md](references/accessibility.md) |
| Missing data-slot, incorrect CSS targeting | [references/data-slot.md](references/data-slot.md) |

## Review Checklist

- [ ] `cn()` receives className, not CVA variants
- [ ] `VariantProps<typeof variants>` exported for consumers
- [ ] Compound variants used for complex state combinations
- [ ] `asChild` pattern uses `@radix-ui/react-slot`
- [ ] Context used for component composition (Card, Accordion, etc.)
- [ ] `focus-visible:` states, not just `:focus`
- [ ] `aria-invalid`, `aria-disabled` for form states
- [ ] `disabled:` variants for all interactive elements
- [ ] `sr-only` for screen reader text
- [ ] `data-slot` attributes for targetable composition parts
- [ ] CSS uses `has()` selectors for state-based styling
- [ ] No direct className overrides of variant styles

## When to Load References

- Reviewing variant definitions → cva-patterns.md
- Reviewing component composition with asChild → composition.md
- Reviewing form components or interactive elements → accessibility.md
- Reviewing multi-part components (Card, Select, etc.) → data-slot.md

## Review Questions

1. Are CVA variants properly separated from className props?
2. Does asChild composition work correctly with Slot?
3. Are all accessibility states (focus, invalid, disabled) handled?
4. Are data-slot attributes used for component part targeting?
5. Can consumers extend variants without breaking composition?
