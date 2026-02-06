# Theming & Design Tokens

## Contents

- [@theme Directive Modes](#theme-directive-modes)
- [CSS Variable Naming Conventions](#css-variable-naming-conventions)
- [OKLCH Color System](#oklch-color-system)
- [Aviation Theme Example](#aviation-theme-example)
- [Two-Tier Variable System](#two-tier-variable-system)
- [Custom Font Configuration](#custom-font-configuration)
- [Animation Keyframes](#animation-keyframes)

---

## @theme Directive Modes

Tailwind v4 provides multiple modes for defining theme values. Modes can be combined (e.g., `@theme default inline`, `@theme inline reference`).

### @theme (default mode)

Generates CSS variables that can be referenced in custom CSS:

```css
@theme {
  --color-brand: oklch(60% 0.24 262);
  --spacing: 0.25rem;
}
```

**Generated CSS**:
```css
:root {
  --color-brand: oklch(60% 0.24 262);
  --spacing: 0.25rem;
}
```

**Usage in utilities**:
```html
<div class="text-brand">Uses var(--color-brand)</div>
```

**Usage in custom CSS**:
```css
.custom-element {
  color: var(--color-brand);
  padding: calc(var(--spacing) * 4);
}
```

### @theme inline

Inlines values directly without CSS variable indirection:

```css
@theme inline {
  --color-brand: oklch(60% 0.24 262);
}
```

**Generated CSS** (when `text-brand` is used):
```css
.text-brand {
  color: oklch(60% 0.24 262);
}
```

**When to use**:
- Better performance (no `var()` lookups)
- Static values that won't change
- Utilities with multiple values (animations, shadows)
- Production builds with no runtime theming

### @theme reference

Inlines values as fallbacks without emitting CSS variables to :root:

```css
@theme reference {
  --color-internal: oklch(50% 0.1 180);
}
```

**Generated CSS** (when `bg-internal` is used):
```css
.bg-internal {
  background-color: var(--color-internal, oklch(50% 0.1 180));
}
```

**Key behavior**: No `:root` variable is created, but the utility still works by using the value as a fallback in `var()`.

**When to use**:
- Provide fallback values without CSS variable overhead
- Reduce :root bloat while maintaining utility functionality
- Values that should work even if the variable isn't defined elsewhere
- Combine with `inline` for direct value substitution (e.g., `@theme reference inline`)

### @theme default

Explicitly marks theme values as defaults that can be overridden:

```css
@theme default {
  --color-primary: oklch(60% 0.24 262);
}

/* Later in the file or another file */
@theme {
  --color-primary: oklch(70% 0.20 180);  /* This overrides the default */
}
```

**Generated CSS**:
```css
:root, :host {
  --color-primary: oklch(70% 0.20 180);
}
```

**When to use**:
- Providing base theme values that can be customized
- Library or framework default themes
- Creating overridable design systems
- Used extensively in Tailwind's built-in `theme.css`

**Mode combinations**:
- `@theme default inline` - Default values, inlined directly
- `@theme default reference` - Default fallbacks without :root emission
- `@theme default inline reference` - All three combined

## CSS Variable Naming Conventions

Tailwind v4 uses consistent naming patterns for theme variables:

### Colors

```css
--color-{name}-{shade}
```

**Examples**:
```css
@theme {
  --color-primary-500: oklch(60% 0.24 262);
  --color-surface-900: oklch(21% 0.006 286);
  --color-success-600: oklch(62.7% 0.194 149);
}

/* Usage: text-primary-500, bg-surface-900, border-success-600 */
```

### Spacing

```css
--spacing: {base-unit}
```

**Example**:
```css
@theme {
  --spacing: 0.25rem;  /* Base unit (4px at 16px root) */
}

/* Generated scale:
  p-1  → padding: calc(0.25rem * 1)  → 4px
  p-4  → padding: calc(0.25rem * 4)  → 16px
  p-12 → padding: calc(0.25rem * 12) → 48px
*/
```

### Fonts

```css
--font-{family}
--font-{family}--{feature}
```

**Examples**:
```css
@theme {
  --font-sans: ui-sans-serif, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --font-display: 'Inter Variable', system-ui;

  --font-display--font-variation-settings: 'wght' 400;
  --font-display--font-feature-settings: 'cv02', 'cv03';
}

/* Usage: font-sans, font-mono, font-display */
```

### Breakpoints

```css
--breakpoint-{size}: {value}
```

**Examples**:
```css
@theme {
  --breakpoint-sm: 40rem;   /* 640px */
  --breakpoint-md: 48rem;   /* 768px */
  --breakpoint-lg: 64rem;   /* 1024px */
  --breakpoint-xl: 80rem;   /* 1280px */
  --breakpoint-2xl: 96rem;  /* 1536px */
}
```

### Animations

```css
--animate-{name}: {animation-value}
```

**Examples**:
```css
@theme inline {
  --animate-spin: spin 1s linear infinite;
  --animate-pulse: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  --animate-beacon: beacon 2s ease-in-out infinite;

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  @keyframes pulse {
    50% { opacity: 0.5; }
  }

  @keyframes beacon {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.5; transform: scale(1.05); }
  }
}

/* Usage: animate-spin, animate-pulse, animate-beacon */
```

## OKLCH Color System

OKLCH (Oklab LCH) provides perceptually uniform colors with consistent lightness across all hues.

### Syntax

```css
oklch(L% C H / A)
```

- **L (Lightness)**: 0% (black) to 100% (white)
- **C (Chroma)**: 0 (gray) to ~0.4 (vibrant)
- **H (Hue)**: 0-360 degrees
- **A (Alpha)**: Optional, 0-1

### Hue Wheel

```
  0° / 360° - Red
  30°       - Orange
  60°       - Yellow
  120°      - Green
  180°      - Cyan
  240°      - Blue
  270°      - Indigo
  300°      - Magenta
```

### Complete Color Palette

```css
@theme {
  /* Blue scale (H ≈ 260) */
  --color-blue-50: oklch(97% 0.014 254.604);
  --color-blue-100: oklch(93.2% 0.032 255.585);
  --color-blue-200: oklch(88.2% 0.059 254.128);
  --color-blue-300: oklch(80.9% 0.105 251.813);
  --color-blue-400: oklch(70.7% 0.165 254.624);
  --color-blue-500: oklch(62.3% 0.214 259.815);
  --color-blue-600: oklch(54.6% 0.245 262.881);
  --color-blue-700: oklch(48.8% 0.243 264.376);
  --color-blue-800: oklch(42.4% 0.199 265.638);
  --color-blue-900: oklch(37.9% 0.146 265.522);
  --color-blue-950: oklch(28.2% 0.091 267.935);

  /* Slate scale (neutral with slight blue tint) */
  --color-slate-50: oklch(98.4% 0.003 247.858);
  --color-slate-100: oklch(96.8% 0.007 247.896);
  --color-slate-200: oklch(92.9% 0.013 255.508);
  --color-slate-300: oklch(86.9% 0.022 252.894);
  --color-slate-400: oklch(70.4% 0.04 256.788);
  --color-slate-500: oklch(55.4% 0.046 257.417);
  --color-slate-600: oklch(44.6% 0.043 257.281);
  --color-slate-700: oklch(37.2% 0.044 257.287);
  --color-slate-800: oklch(27.9% 0.041 260.031);
  --color-slate-900: oklch(20.8% 0.042 265.755);
  --color-slate-950: oklch(12.9% 0.042 264.695);
}
```

### Chroma Guidelines

- **0**: Pure gray (achromatic)
- **0.01-0.05**: Subtle tint (slate, zinc)
- **0.10-0.15**: Muted colors (good for backgrounds)
- **0.15-0.25**: Vibrant colors (good for UI elements)
- **0.25-0.40**: Maximum saturation (use sparingly)

## Aviation Theme Example

Custom color palette for an aviation-themed dashboard:

```css
@theme {
  /* Flight status colors */
  --color-on-time: oklch(72.3% 0.219 149.579);      /* Green-600 */
  --color-delayed: oklch(76.9% 0.188 70.08);        /* Amber-500 */
  --color-cancelled: oklch(63.7% 0.237 25.331);     /* Red-500 */
  --color-diverted: oklch(68.5% 0.169 237.323);     /* Sky-500 */

  /* Navigation colors */
  --color-runway: oklch(87.1% 0.006 286.286);       /* Zinc-300 */
  --color-taxiway: oklch(70.5% 0.015 286.067);      /* Zinc-400 */
  --color-apron: oklch(55.2% 0.016 285.938);        /* Zinc-500 */

  /* Radar colors */
  --color-primary-radar: oklch(74.6% 0.16 232.661); /* Sky-400 */
  --color-secondary-radar: oklch(76.5% 0.177 163.223); /* Emerald-400 */

  /* Map layers */
  --color-airspace-class-a: oklch(70.7% 0.165 254.624); /* Blue-400 */
  --color-airspace-class-b: oklch(84.1% 0.238 128.85);  /* Lime-400 */
  --color-airspace-class-c: oklch(71.8% 0.202 349.761); /* Pink-400 */
}
```

## Two-Tier Variable System

Separate design tokens from semantic naming:

```css
@theme {
  /* Tier 1: Design tokens (OKLCH primitives) */
  --color-blue-600: oklch(54.6% 0.245 262.881);
  --color-slate-50: oklch(98.4% 0.003 247.858);
  --color-slate-800: oklch(27.9% 0.041 260.031);
  --color-slate-900: oklch(20.8% 0.042 265.755);
  --color-emerald-500: oklch(69.6% 0.17 162.48);

  /* Tier 2: Semantic mappings */
  --color-primary: var(--color-blue-600);
  --color-surface: var(--color-slate-900);
  --color-surface-raised: var(--color-slate-800);
  --color-text: var(--color-slate-50);
  --color-success: var(--color-emerald-500);
}

/* Usage in components */
.button-primary {
  background-color: var(--color-primary);
  color: var(--color-text);
}

.card {
  background-color: var(--color-surface-raised);
}
```

**Benefits**:
- Design tokens maintain consistency
- Semantic names convey intent
- Easy theme switching (just remap tier 2)
- Clear separation of concerns

## Custom Font Configuration

Configure custom fonts with variable font features:

```css
@theme {
  /* Font families */
  --font-sans: 'Inter Variable', ui-sans-serif, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;
  --font-display: 'Manrope Variable', system-ui, sans-serif;

  /* Variable font settings for --font-display */
  --font-display--font-variation-settings: 'wght' 600;

  /* OpenType features for --font-display */
  --font-display--font-feature-settings: 'ss01', 'ss02', 'cv05';

  /* Font weights */
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;

  /* Letter spacing */
  --tracking-tight: -0.025em;
  --tracking-normal: 0em;
  --tracking-wide: 0.025em;
}
```

**Load fonts in HTML**:
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@100..900&display=swap" rel="stylesheet">
```

**Usage**:
```html
<h1 class="font-display font-semibold tracking-tight">Aviation Dashboard</h1>
<code class="font-mono text-sm">ATC-1234</code>
```

## Animation Keyframes

Define custom animations with `@theme inline` and `@keyframes`:

```css
@theme inline {
  /* Simple animations */
  --animate-fade-in: fade-in 0.3s ease-out;
  --animate-slide-up: slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1);

  /* Complex animations */
  --animate-beacon: beacon 2s ease-in-out infinite;
  --animate-pulse-glow: pulse-glow 1.5s cubic-bezier(0.4, 0, 0.6, 1) infinite;

  /* Keyframe definitions */
  @keyframes fade-in {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }

  @keyframes slide-up {
    from {
      transform: translateY(10px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  @keyframes beacon {
    0%, 100% {
      opacity: 1;
      transform: scale(1);
      box-shadow: 0 0 0 0 rgba(59, 130, 246, 0.7);
    }
    50% {
      opacity: 0.9;
      transform: scale(1.05);
      box-shadow: 0 0 0 10px rgba(59, 130, 246, 0);
    }
  }

  @keyframes pulse-glow {
    0%, 100% {
      box-shadow: 0 0 8px 2px rgba(34, 197, 94, 0.4);
    }
    50% {
      box-shadow: 0 0 16px 4px rgba(34, 197, 94, 0.8);
    }
  }
}
```

**Usage**:
```html
<div class="animate-fade-in">Fades in on mount</div>
<div class="animate-beacon">Pulsing beacon effect</div>
<div class="animate-pulse-glow">Glowing status indicator</div>
```

**Respecting prefers-reduced-motion**:
```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```
