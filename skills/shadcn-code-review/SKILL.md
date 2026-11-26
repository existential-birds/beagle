---
name: shadcn-code-review
description: Reviews shadcn/ui components for CVA patterns, composition with asChild or Base UI render props, accessibility states, and data-slot usage. Use when reviewing React components using shadcn/ui, Radix UI, Base UI, or Tailwind styling.
---

# shadcn/ui Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| className in CVA, missing VariantProps, compound variants | [references/cva-patterns.md](references/cva-patterns.md) |
| asChild / Slot (radix-ui or @radix-ui/react-slot), Base UI render prop, Context, React 19 ref | [references/composition.md](references/composition.md) |
| Missing focus-visible, aria-invalid, disabled states | [references/accessibility.md](references/accessibility.md) |
| Missing data-slot, incorrect CSS targeting | [references/data-slot.md](references/data-slot.md) |

## Review Checklist

- [ ] `cn()` receives `className`, not CVA variants
- [ ] `VariantProps<typeof variants>` exported for consumers
- [ ] Compound variants used for complex state combinations
- [ ] `asChild` uses `Slot` from unified `radix-ui` (`import { Slot } from "radix-ui"`) or `@radix-ui/react-slot`, or Base UI components use `@base-ui/react` `render` prop
- [ ] Props typed with `React.ComponentProps<...>` (React 19 `ref` prop forwarded cleanly; do not require `React.forwardRef` on React 19)
- [ ] Context used for compound component composition (Card, Accordion, etc.)
- [ ] `focus-visible:` states, not just `:focus`
- [ ] `aria-invalid`, `aria-disabled` for form states
- [ ] `disabled:` variants for all interactive elements
- [ ] `sr-only` for screen reader text
- [ ] `data-slot` attributes for targetable composition parts
- [ ] CSS uses `has()` selectors for state-based styling
- [ ] No direct className overrides of variant styles

## Hard gates (before writing findings)

Run these in order. **Do not draft user-facing findings until every gate passes** for the batch you are about to report.

1. **Location evidence** — **Pass:** Each issue lists a repo path and either a line range or a short verbatim quote from the file you read (not from memory or diff-only guesswork).

2. **Exemption check** — **Pass:** For each issue, you can state in one line why it is *not* covered by [Valid Patterns (Do NOT Flag)](#valid-patterns-do-not-flag).

3. **Context-sensitive claims** — **Pass:** For accessibility or Radix/Base UI-related flags, you checked the file for imports/wrappers showing what actually runs (or you cite the concrete gap).

4. **Protocol** — **Pass:** You completed the Pre-Report Verification Checklist in [review-verification-protocol](../review-verification-protocol/SKILL.md) for this review.

## Valid Patterns (Do NOT Flag)

These are correct patterns that should NOT be flagged as issues:

- `max-h-(--var)` - correct Tailwind v4 CSS variable syntax (NOT v3 bracket notation)
- `text-[color:var(--x)]` - valid arbitrary value syntax
- React 19 function components accepting `ref` via `React.ComponentProps<"button">` without `React.forwardRef`
- Unified `import { Slot } from "radix-ui"` (or `Slot.Root`) or Base UI `@base-ui/react` `render` prop composition
- Copying shadcn component code into project - intended usage pattern
- Not documenting copied shadcn components - library internals, not custom code
- Using `cn()` with many arguments - composition is the pattern
- Conditional classes in `cn()` arrays - valid Tailwind pattern
- Extending primitive components without additional docs - well-known base

## Context-Sensitive Rules

Apply these rules with appropriate context awareness:

- Flag accessibility issues ONLY IF not handled by Radix or Base UI primitives underneath
- Flag missing aria labels ONLY IF component isn't using accessible Radix/Base UI primitive
- Flag variant proliferation ONLY IF variants could be composed from existing
- Flag component documentation ONLY IF it's custom code, not copied shadcn

## Library Convention Note

shadcn/ui components are designed to be copied and modified. Code review should focus on:
- Custom modifications made to copied components
- Integration with application state/data
- Accessibility in custom usage contexts

Do NOT flag:
- Standard shadcn component internals
- Radix or Base UI primitive usage patterns
- Default variant implementations

## When to Load References

- Reviewing variant definitions → `references/cva-patterns.md`
- Reviewing component composition with `asChild` / `render` / `ref` → `references/composition.md`
- Reviewing form components or interactive elements → `references/accessibility.md`
- Reviewing multi-part components (Card, Select, etc.) → `references/data-slot.md`

## Review Questions

1. Are CVA variants properly separated from `className` props?
2. Does composition work correctly with `Slot` (`radix-ui` / `@radix-ui/react-slot`) or Base UI `render` prop and React 19 `ref` forwarding?
3. Are all accessibility states (focus, invalid, disabled) handled?
4. Are `data-slot` attributes used for component part targeting?
5. Can consumers extend variants without breaking composition?

## Before Submitting Findings

Complete [Hard gates](#hard-gates-before-writing-findings) (especially gate 4), then report only issues that still pass the [review-verification-protocol](../review-verification-protocol/SKILL.md) pre-report checks.
