# Theming & Design Tokens

## Contents

- [@theme Directive Modes](#theme-directive-modes)
- [CSS Variable Naming Conventions](#css-variable-naming-conventions)
- [OKLCH Color System](#oklch-color-system)
- [Status & Semantic Token Example](#status--semantic-token-example)
- [Two-Tier Variable System](#two-tier-variable-system)
- [Custom Font Configuration](#custom-font-configuration)
- [Animation Keyframes](#animation-keyframes)

---

## @theme Directive Modes

Tailwind v4 provides multiple modes for defining theme values. Modes can be combined (e.g., `@theme default inline`, `@theme inline reference`).

### `@theme` (default mode)

Generates CSS variables on `:root, :host` that can be referenced in custom CSS:

```css
@theme {
  --color-brand: oklch(60% 0.24 262);
  --spacing: 0.25rem;
}
```

**Usage in utilities & custom CSS**:
```html
<div class="text-brand">Uses var(--color-brand)</div>
```
```css
.custom-element {
  color: var(--color-brand);
  padding: calc(var(--spacing) * 4);
}
```

### `@theme inline`

Inlines values directly without CSS variable indirection:

```css
@theme inline {
  --color-brand: oklch(60% 0.24 262);
}
```

**When to use**:
- Mapping runtime CSS variables (`--color-primary: var(--primary)`) that change under `.dark` or theme scopes
- Static values that won't change at runtime (no `var()` lookup overhead)
- Utilities with multiple values (animations, shadows)

### `@theme reference`

Inlines values as fallbacks without emitting CSS variables to `:root`:

```css
@theme reference {
  --color-internal: oklch(50% 0.1 180);
}
```

Generates `.bg-internal { background-color: var(--color-internal, oklch(50% 0.1 180)); }` without cluttering `:root`.

### `@theme default`

Explicitly marks theme values as defaults that later `@theme` declarations can override:

```css
@theme default {
  --color-primary: oklch(60% 0.24 262);
}

@theme {
  --color-primary: oklch(70% 0.20 180); /* Overrides the default */
}
```

## CSS Variable Naming Conventions

- **Colors**: `--color-{name}-{shade}` → `text-{name}-{shade}`, `bg-{name}-{shade}`, `border-{name}-{shade}`
- **Spacing**: `--spacing: 0.25rem;` (base multiplier for `p-4`, `m-2`, etc.)
- **Fonts**: `--font-{family}` and `--font-{family}--font-variation-settings` / `--font-feature-settings`
- **Breakpoints**: `--breakpoint-{size}: 48rem;`
- **Animations**: `--animate-{name}: {value};` with `@keyframes` inside `@theme`

## OKLCH Color System

OKLCH (Oklab LCH) provides perceptually uniform colors with consistent lightness across hues:

```css
oklch(L% C H / A)
```

- **L (Lightness)**: `0%` (black) to `100%` (white)
- **C (Chroma)**: `0` (gray) to `~0.4` (vibrant)
- **H (Hue)**: `0–360` degrees (`0°` Red, `60°` Yellow, `120°` Green, `180°` Cyan, `240°` Blue, `300°` Magenta)
- **A (Alpha)**: Optional (`0–1` or percentage)

### Chroma Guidelines

- `0`: Pure gray (achromatic)
- `0.01–0.05`: Subtle neutral tint (slate, zinc)
- `0.10–0.15`: Muted colors (backgrounds, badges)
- `0.15–0.25`: Vibrant UI colors (buttons, links)
- `0.25–0.40`: Maximum saturation (use sparingly)

## Status & Semantic Token Example

```css
@theme {
  /* Semantic status colors */
  --color-status-ok: oklch(72.3% 0.219 149.579);
  --color-status-warn: oklch(76.9% 0.188 70.08);
  --color-status-error: oklch(63.7% 0.237 25.331);
  --color-status-info: oklch(68.5% 0.169 237.323);

  /* Surface & chrome tokens */
  --color-surface: oklch(98.4% 0.003 247.858);
  --color-surface-muted: oklch(92.9% 0.013 255.508);
  --color-border-subtle: oklch(86.9% 0.022 252.894);
}
```

## Two-Tier Variable System

Separate primitive design tokens from semantic intent (especially useful with light/dark theme switching via `@theme inline`):

```css
:root {
  --surface-base: oklch(98.4% 0.003 247.858);
  --surface-raised: oklch(100% 0 0);
  --text-base: oklch(20.8% 0.042 265.755);
  --brand-primary: oklch(54.6% 0.245 262.881);
}

.dark {
  --surface-base: oklch(14.5% 0.02 265);
  --surface-raised: oklch(20.8% 0.042 265.755);
  --text-base: oklch(98.4% 0.003 247.858);
  --brand-primary: oklch(70.7% 0.165 254.624);
}

@theme inline {
  --color-surface: var(--surface-base);
  --color-surface-raised: var(--surface-raised);
  --color-foreground: var(--text-base);
  --color-primary: var(--brand-primary);
}
```

## Custom Font Configuration

```css
@theme {
  --font-sans: 'Inter Variable', ui-sans-serif, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;
  --font-display: 'Manrope Variable', system-ui, sans-serif;

  --font-display--font-variation-settings: 'wght' 600;
  --font-display--font-feature-settings: 'ss01', 'ss02', 'cv05';
}
```

## Animation Keyframes

Define custom animations with `@theme inline` and nested `@keyframes`:

```css
@theme inline {
  --animate-fade-in: fade-in 0.3s ease-out;
  --animate-slide-up: slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1);

  @keyframes fade-in {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slide-up {
    from { transform: translateY(10px); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
}
```

Always pair animations with `motion-reduce:` utilities or `@media (prefers-reduced-motion: reduce)`.
