# Dark Mode Strategies

## Contents

- [Media Query Strategy (Default)](#media-query-strategy-default)
- [Class-Based Strategy (`@custom-variant`)](#class-based-strategy-custom-variant)
- [Attribute-Based Strategy (`@custom-variant`)](#attribute-based-strategy-custom-variant)
- [Theme Switching Implementation](#theme-switching-implementation)
- [Respecting User Preferences](#respecting-user-preferences)

---

## Media Query Strategy (Default)

By default in Tailwind CSS v4, the `dark:` variant uses `@media (prefers-color-scheme: dark)` with zero configuration:

```css
@import "tailwindcss";
```

```tsx
export function Card({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-50">
      {children}
    </div>
  );
}
```

## Class-Based Strategy (`@custom-variant`)

To toggle dark mode manually with a `.dark` class in pure Tailwind v4 (without any `tailwind.config.js`), override the `dark` variant in CSS using `@custom-variant`:

```css
/* src/index.css */
@import "tailwindcss";

@custom-variant dark (&:where(.dark, .dark *));
```

*(Note: `@custom-variant dark (&:is(.dark *));` is also commonly used by shadcn/ui when `.dark` is applied on `<html>` or an ancestor wrapper. Never recommend `tailwind.config.js` `darkMode: 'class'` as a v4 approach.)*

**Usage**:
```tsx
export function App() {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    document.documentElement.classList.toggle('dark', isDark);
  }, [isDark]);

  return (
    <div className="bg-white dark:bg-slate-900">
      <button type="button" onClick={() => setIsDark((d) => !d)}>
        Toggle Theme
      </button>
    </div>
  );
}
```

## Attribute-Based Strategy (`@custom-variant`)

Use a `data-theme` attribute in pure Tailwind v4 with `@custom-variant`:

```css
/* src/index.css */
@import "tailwindcss";

@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));
```

**Usage & Multiple Themes**:
```css
/* Optional additional theme variants */
@custom-variant high-contrast (&:where([data-theme="high-contrast"], [data-theme="high-contrast"] *));
```

```tsx
type Theme = 'light' | 'dark' | 'high-contrast';

export function App() {
  const [theme, setTheme] = useState<Theme>('light');

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  return (
    <div className="bg-white dark:bg-slate-900 high-contrast:bg-black">
      <select value={theme} onChange={(e) => setTheme(e.target.value as Theme)}>
        <option value="light">Light</option>
        <option value="dark">Dark</option>
        <option value="high-contrast">High Contrast</option>
      </select>
    </div>
  );
}
```

## Theme Switching Implementation

### React Hook & Context

```tsx
// hooks/use-theme.ts
import { useEffect, useState } from 'react';

type Theme = 'light' | 'dark' | 'system';

export function useTheme() {
  const [theme, setTheme] = useState<Theme>(() => {
    if (typeof window === 'undefined') return 'system';
    return (localStorage.getItem('theme') as Theme) || 'system';
  });

  useEffect(() => {
    const root = document.documentElement;
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
      ? 'dark'
      : 'light';
    const effectiveTheme = theme === 'system' ? systemTheme : theme;

    root.classList.remove('light', 'dark');
    root.classList.add(effectiveTheme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  useEffect(() => {
    if (theme !== 'system') return;
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => {
      const systemTheme = mediaQuery.matches ? 'dark' : 'light';
      document.documentElement.classList.remove('light', 'dark');
      document.documentElement.classList.add(systemTheme);
    };
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, [theme]);

  return { theme, setTheme };
}
```

### SSR Script (Prevent FOUC)

Inject an inline script in `<head>` before styled content renders:

```tsx
// app/layout.tsx (Next.js example)
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                const theme = localStorage.getItem('theme') || 'system';
                const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
                const effectiveTheme = theme === 'system' ? systemTheme : theme;
                document.documentElement.classList.add(effectiveTheme);
              })();
            `,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

## Respecting User Preferences

### Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

Or per component with `motion-reduce:transition-none`.

### High Contrast & Forced Colors

```tsx
export function AccessibleCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-50 rounded-lg transition-colors duration-200 motion-reduce:transition-none border border-transparent contrast-more:border-slate-300 forced-colors:bg-[Canvas] forced-colors:border-[CanvasText]">
      {children}
    </div>
  );
}
```
