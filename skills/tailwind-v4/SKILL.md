---
name: tailwind-v4
description: Tailwind CSS v4 CSS-first configuration, OKLCH design tokens, @theme modes, @utility, @custom-variant dark mode, and v3-to-v4 utility changes. Use when configuring Tailwind v4 with Vite or PostCSS, defining CSS theme variables, or reviewing v4 styles.
---

# Tailwind CSS v4 Best Practices

## Quick Reference

**Vite Plugin Setup** (Vite apps):
```ts
// vite.config.ts
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [tailwindcss()],
});
```

**PostCSS Plugin Setup** (Next.js, Webpack, or other non-Vite bundlers):
```js
// postcss.config.mjs
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
```

**CSS Entry Point**:
```css
/* src/index.css */
@import "tailwindcss";
```

**`@theme` & `@utility` Directives**:
```css
@theme inline {
  --color-primary: oklch(60% 0.24 262);
  --color-surface: oklch(98% 0.002 247);
}

@utility content-auto {
  content-visibility: auto;
}
```

## Key Differences from v3

| Feature | v3 | v4 |
|---|---|---|
| Configuration | `tailwind.config.js` | `@theme` in CSS |
| Build Tool | `tailwindcss` + `autoprefixer` | `@tailwindcss/vite` (Vite) or `@tailwindcss/postcss` (Next.js/PostCSS) |
| CSS Entry | `@tailwind base; @tailwind components; @tailwind utilities;` | `@import "tailwindcss";` |
| Colors | `rgb()` / `hsl()` | `oklch()` (default) |
| Custom Utilities | `@layer utilities { .foo { ... } }` | `@utility foo { ... }` (supports variants like `hover:foo`) |
| Dark Mode | `darkMode` in JS config | Media query by default, or `@custom-variant dark (...)` in CSS |
| CSS Variables in Arbitrary Values | `max-h-[var(--x)]` | `max-h-(--x)` |

## v4 Utility Renames & Removals (Common v3 Regressions)

- **Shadows & Radii**: `shadow-sm` → `shadow-xs`, `shadow` → `shadow-sm`; `rounded-sm` → `rounded-xs`, `rounded` → `rounded-sm`; `blur-sm` → `blur-xs`, `blur` → `blur-sm`.
- **Outline**: `outline-none` → `outline-hidden` (for keeping accessible outline in forced-colors mode; `outline-none` now sets `outline-style: none`).
- **Ring default width**: `ring` defaults to `1px` in v4 (use `ring-3` for v3's `3px` default).
- **Opacity modifiers**: `bg-opacity-50` / `text-opacity-50` removed — use `bg-black/50` or `text-white/50`.
- **CSS variables**: Use parentheses `bg-(--brand)` / `max-h-(--var)` instead of `bg-[var(--brand)]`.

## shadcn/ui + Tailwind v4 Integration

Modern shadcn/ui on Tailwind v4 maps runtime CSS variables from `:root` / `.dark` into Tailwind utility tokens via `@theme inline` and imports `tw-animate-css` and `shadcn/tailwind.css` instead of `tailwind.config.js` + `tailwindcss-animate`:

```css
@import "tailwindcss";
@import "tw-animate-css";
@import "shadcn/tailwind.css";

@custom-variant dark (&:is(.dark *));

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
}
```

## `@theme` Directive Modes

### `default` (standard mode)
Generates CSS variables on `:root, :host` that can be referenced elsewhere:
```css
@theme {
  --color-brand: oklch(60% 0.24 262);
}
```

### `inline`
Inlines values directly without CSS variable indirection (essential when referencing runtime CSS vars like `var(--background)` inside `@theme inline`):
```css
@theme inline {
  --color-brand: oklch(60% 0.24 262);
}
```

### `reference`
Inlines values as fallbacks without emitting `:root` CSS variables:
```css
@theme reference {
  --color-internal: oklch(50% 0.1 180);
}
```

## OKLCH Color Format

```css
oklch(L% C H)
```

- **L (Lightness)**: `0%` (black) to `100%` (white)
- **C (Chroma)**: `0` (gray) to `~0.4` (vibrant)
- **H (Hue)**: `0–360` degrees (red → yellow → green → blue → magenta)

## Progressive Disclosure

- **Setup & Installation**: See [references/setup.md](references/setup.md) for Vite & PostCSS plugin configuration, CSS entry, `@utility`, and `@source`.
- **Theming & Design Tokens**: See [references/theming.md](references/theming.md) for `@theme` modes, OKLCH palettes, two-tier semantic tokens, custom fonts, and animations.
- **Dark Mode Strategies**: See [references/dark-mode.md](references/dark-mode.md) for media query, `@custom-variant` class/attribute strategies, FOUC prevention, and reduced motion.

## Gates (Setup Verification)

Before recommending `@theme` choices, OKLCH tokens, or v4 utilities, confirm the project is actually on the v4 integration path:

1. **Build wiring**: Either Vite loads `tailwindcss()` from `@tailwindcss/vite`, or PostCSS loads `'@tailwindcss/postcss'` (`postcss.config.*`), and the CSS entry uses `@import "tailwindcss";`.
2. **Major versions**: `package.json` lists `tailwindcss` (and `@tailwindcss/vite` or `@tailwindcss/postcss`) at **major 4** (no legacy `autoprefixer` + v3 plugin pipeline).
3. **Theme source**: New theme tokens and dark variants live in CSS (`@theme`, `@theme inline`, `@custom-variant`, `@utility`) — not `tailwind.config.js` `extend` or `@layer utilities`.

## Decision Guide

### When to use `@theme inline` vs `@theme`
- **Use `@theme inline`** when mapping another CSS variable (`--color-primary: var(--primary)`), for static tokens that should inline directly, or for `@keyframes` animations.
- **Use `@theme`** when you want Tailwind to emit `--*` custom properties on `:root` for runtime inspection or custom CSS `var(...)` usage.

### When to use `@theme reference`
- Provide fallback utility definitions without emitting `:root` variables.
