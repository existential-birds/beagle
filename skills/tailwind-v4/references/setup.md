# Setup & Installation

## Contents

- [Package Installation](#package-installation)
- [Vite Plugin Configuration](#vite-plugin-configuration)
- [PostCSS Configuration (Next.js / Non-Vite)](#postcss-configuration-nextjs--non-vite)
- [CSS Entry Point & Custom Utilities](#css-entry-point--custom-utilities)
- [Why No Config Files](#why-no-config-files)

---

## Package Installation

**With Vite** (recommended for Vite apps):
```bash
pnpm add -D tailwindcss @tailwindcss/vite
```

**With PostCSS** (Next.js, Webpack, Parcel, or other bundlers):
```bash
pnpm add -D tailwindcss @tailwindcss/postcss postcss
```

**Complete `package.json` example (Vite)**:
```json
{
  "name": "react-tailwind-app",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.0.0",
    "@vitejs/plugin-react": "^5.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "^5.6.0",
    "vite": "^6.0.0"
  }
}
```

## Vite Plugin Configuration

Use `@tailwindcss/vite` directly in `vite.config.ts` (no `postcss.config.js` needed):

```ts
// vite.config.ts
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
});
```

## PostCSS Configuration (Next.js / Non-Vite)

When not using Vite, configure `@tailwindcss/postcss` (autoprefixer is built into v4's Lightning CSS pipeline and no longer needs to be listed separately):

```js
// postcss.config.mjs
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
```

## CSS Entry Point & Custom Utilities

Create a single CSS entry point importing Tailwind:

```css
/* src/index.css */
@import "tailwindcss";
```

Import it in your app entry (e.g., `src/main.tsx` or `app/layout.tsx`).

### Custom Utilities with `@utility` (Replaces `@layer utilities`)

In Tailwind v4, define custom utilities with `@utility` instead of `@layer utilities` so they automatically work with all variants (`hover:`, `md:`, `dark:`):

```css
/* src/index.css */
@import "tailwindcss";

@theme {
  --color-primary: oklch(60% 0.24 262);
}

@utility content-auto {
  content-visibility: auto;
}

/* Supports hover:content-auto, md:content-auto, etc. */
```

### shadcn/ui Tailwind v4 Entry

When using shadcn/ui with Tailwind v4, import `tw-animate-css` and `shadcn/tailwind.css` alongside `@theme inline`:

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

## Why No Config Files

Tailwind v4 eliminates `tailwind.config.js` in favor of CSS-first configuration.

### Theme Tokens: `@theme` Instead of `tailwind.config.js`

```css
/* v4 CSS-first */
@theme {
  --color-primary: oklch(60% 0.24 262);
}
```

### Content Detection: Automatic + `@source`

Tailwind v4 automatically scans source files (ignoring `.gitignore`, `node_modules`, and binary files). Add `@source` only for files outside standard paths or ignored directories:

```css
@import "tailwindcss";

/* Optional: scan external package or explicit paths */
@source "../node_modules/@my-org/ui";
```
