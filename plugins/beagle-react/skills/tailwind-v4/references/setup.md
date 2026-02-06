# Setup & Installation

## Contents

- [Package Installation](#package-installation)
- [Vite Plugin Configuration](#vite-plugin-configuration)
- [TypeScript Configuration](#typescript-configuration)
- [CSS Entry Point](#css-entry-point)
- [Why No Config Files](#why-no-config-files)

---

## Package Installation

Install Tailwind CSS v4 with the Vite plugin:

```bash
pnpm add -D tailwindcss@next @tailwindcss/vite@next
```

**Complete package.json example**:
```json
{
  "name": "amelia-dashboard",
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
    "@types/node": "^22.0.0",
    "@vitejs/plugin-react": "^5.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "^5.6.0",
    "vite": "^6.0.0"
  }
}
```

## Vite Plugin Configuration

Use the `@tailwindcss/vite` plugin (NOT the PostCSS plugin):

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

**Plugin options**:
```ts
export type PluginOptions = {
  /**
   * Optimize and minify the output CSS.
   * Default: true in build mode, false in dev mode
   */
  optimize?: boolean | { minify?: boolean };
};

// Example with options
tailwindcss({
  optimize: {
    minify: true,
  },
});
```

**How it works**:
- Scans source files for Tailwind class candidates
- Intercepts CSS files containing `@import 'tailwindcss'`
- Generates utilities based on detected classes
- Watches for file changes in dev mode
- Optimizes and minifies in build mode

## TypeScript Configuration

Add `@types/node` for path resolution in Vite config:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,

    /* Bundler mode */
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",

    /* Linting */
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,

    /* Path resolution */
    "types": ["node"],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

**Why `@types/node` is needed**:
- Vite uses Node.js path resolution APIs
- Required for `import.meta.env` types
- Enables `path.resolve()` in config files

## CSS Entry Point

Create a single CSS file that imports Tailwind:

```css
/* src/index.css */
@import 'tailwindcss';
```

**That's it.** No other imports or configuration needed.

**Import in your app**:
```tsx
// src/main.tsx
import './index.css';
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

**Advanced: Multiple entry points**:
```css
/* src/index.css */
@import 'tailwindcss';

/* Custom theme for this entry point */
@theme {
  --color-primary: oklch(60% 0.24 262);
}

/* Custom utilities */
@layer utilities {
  .content-auto {
    content-visibility: auto;
  }
}
```

## Why No Config Files

Tailwind v4 eliminates separate configuration files in favor of CSS-first configuration.

### No `tailwind.config.js`

**v3 approach** (separate JS config):
```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#3b82f6',
      },
    },
  },
};
```

**v4 approach** (CSS-first):
```css
@theme {
  --color-primary: oklch(60% 0.24 262);
}
```

**Benefits**:
- Configuration lives with styles
- No build-time JS evaluation
- Better CSS tooling support (syntax highlighting, autocomplete)
- Easier to understand what CSS gets generated
- No context switching between files

### No `postcss.config.js`

**v3 approach** (PostCSS plugin):
```js
// postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

**v4 approach** (Vite plugin):
```ts
// vite.config.ts
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [tailwindcss()],
});
```

**Benefits**:
- Faster builds (no PostCSS overhead)
- Integrated with Vite's dev server
- Better HMR (Hot Module Replacement)
- Automatic source map generation
- Native ES modules support

### Content Detection

**v3 approach** (manual content paths):
```js
// tailwind.config.js
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx}'],
};
```

**v4 approach** (automatic scanning):
```css
/* Auto-scans all files by default */
@import 'tailwindcss';

/* Optional: Custom source patterns */
@source "src/**/*.{js,ts,jsx,tsx}";
@source "components/**/*.vue";
```

**Benefits**:
- Zero configuration by default
- Explicit control when needed
- CSS-based configuration
- Easier to understand and debug
