# Dark Mode Strategies

## Contents

- [Media Query Strategy](#media-query-strategy)
- [Class-Based Strategy](#class-based-strategy)
- [Attribute-Based Strategy](#attribute-based-strategy)
- [Theme Switching Implementation](#theme-switching-implementation)
- [Respecting User Preferences](#respecting-user-preferences)

---

## Media Query Strategy

Use the system preference for dark mode detection.

### Configuration

**Default behavior** (v4):
```css
/* No configuration needed - dark: variant works by default */
@import 'tailwindcss';
```

**Generated CSS**:
```css
@media (prefers-color-scheme: dark) {
  .dark\:bg-slate-900 {
    background-color: oklch(20.8% 0.042 265.755);
  }
}
```

### Usage

```tsx
export function Card({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-50">
      {children}
    </div>
  );
}
```

### Pros & Cons

**Pros**:
- Respects system preference automatically
- No JavaScript needed
- Simple implementation
- No FOUC (flash of unstyled content)

**Cons**:
- Users can't override system preference
- No manual toggle control
- Changes when system setting changes

### When to Use

- Documentation sites
- Content-focused websites
- Apps where system preference is preferred
- No need for manual theme switching

## Class-Based Strategy

Toggle dark mode with a `.dark` class on the root element.

### Configuration

**Pure v4 approach**: Use a v3 config file with darkMode setting:

```js
// tailwind.config.js (for v3 compatibility)
module.exports = {
  darkMode: 'class',  // or 'selector' (same as 'class')
};
```

**Note**: In pure v4, the default `dark:` variant uses media queries (`prefers-color-scheme: dark`). To use class-based dark mode, you need to either:
1. Use a v3 config file with `darkMode: 'class'` (shown above)
2. Use `@import "tailwindcss/compat"` and provide a config
3. Define a custom variant with `@custom-variant`

### Generated CSS

```css
.dark .dark\:bg-slate-900 {
  background-color: oklch(20.8% 0.042 265.755);
}
```

### Usage

```tsx
export function App() {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDark]);

  return (
    <div className="bg-white dark:bg-slate-900">
      <button onClick={() => setIsDark(!isDark)}>
        Toggle Theme
      </button>
    </div>
  );
}
```

### Pros & Cons

**Pros**:
- Full JavaScript control
- User can override system preference
- Easy to implement manual toggle
- Widely supported pattern

**Cons**:
- Requires JavaScript
- Potential FOUC without SSR handling
- Class management overhead

### When to Use

- Applications with theme toggle
- User preference override needed
- Dashboard/admin interfaces
- Apps with per-user theme settings

## Attribute-Based Strategy

Use a `data-theme` attribute for more semantic theming.

### Configuration (v3 compat)

```js
// tailwind.config.js (v3 compat mode)
module.exports = {
  darkMode: ['class', '[data-theme="dark"]'],
};
```

### Generated CSS

```css
[data-theme="dark"] .dark\:bg-slate-900 {
  background-color: oklch(20.8% 0.042 265.755);
}
```

### Usage

```tsx
export function App() {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  return (
    <div className="bg-white dark:bg-slate-900">
      <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
        Toggle Theme
      </button>
    </div>
  );
}
```

### Multiple Themes

Extend beyond light/dark with multiple theme attributes:

```tsx
type Theme = 'light' | 'dark' | 'aviation' | 'high-contrast';

export function App() {
  const [theme, setTheme] = useState<Theme>('light');

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  return (
    <div className="bg-white dark:bg-slate-900 [&[data-theme='aviation']]:bg-blue-950">
      <select value={theme} onChange={(e) => setTheme(e.target.value as Theme)}>
        <option value="light">Light</option>
        <option value="dark">Dark</option>
        <option value="aviation">Aviation</option>
        <option value="high-contrast">High Contrast</option>
      </select>
    </div>
  );
}
```

### Pros & Cons

**Pros**:
- Semantic HTML attribute
- Supports multiple themes (not just light/dark)
- Easy to inspect in DevTools
- Clear intent

**Cons**:
- Requires JavaScript
- More verbose selector in CSS
- Less common pattern

### When to Use

- Multi-theme applications
- Semantic HTML preferences
- Complex theming systems
- Better DevTools debugging

## Theme Switching Implementation

Complete implementation with persistence and SSR support.

### React Hook

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

  // Listen for system theme changes
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

### Theme Provider Component

```tsx
// components/theme-provider.tsx
import { createContext, useContext, type ReactNode } from 'react';
import { useTheme } from '@/hooks/use-theme';

type ThemeContextValue = ReturnType<typeof useTheme>;

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const value = useTheme();

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useThemeContext() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useThemeContext must be used within ThemeProvider');
  }
  return context;
}
```

### Theme Toggle Component

```tsx
// components/theme-toggle.tsx
import { Moon, Sun, Monitor } from 'lucide-react';
import { useThemeContext } from '@/components/theme-provider';
import { Button } from '@/components/ui/button';

export function ThemeToggle() {
  const { theme, setTheme } = useThemeContext();

  const cycleTheme = () => {
    const themes: Array<'light' | 'dark' | 'system'> = ['light', 'dark', 'system'];
    const currentIndex = themes.indexOf(theme);
    const nextIndex = (currentIndex + 1) % themes.length;
    setTheme(themes[nextIndex]);
  };

  const Icon = theme === 'light' ? Sun : theme === 'dark' ? Moon : Monitor;

  return (
    <Button
      variant="outline"
      size="icon"
      onClick={cycleTheme}
      aria-label={`Current theme: ${theme}. Click to cycle themes.`}
    >
      <Icon className="h-4 w-4" />
    </Button>
  );
}
```

### SSR Script (Prevent FOUC)

Inject this script before any styled content to prevent flash:

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
      <body>
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

## Respecting User Preferences

### Reduced Motion

Always respect `prefers-reduced-motion`:

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

**Usage in components**:
```tsx
export function Card() {
  return (
    <div className="transition-all duration-300 motion-reduce:transition-none">
      Content
    </div>
  );
}
```

### High Contrast

Support high contrast mode:

```css
@media (prefers-contrast: high) {
  .button {
    border-width: 2px;
  }
}
```

**Tailwind utilities**:
```html
<button class="border contrast-more:border-2">
  High Contrast Button
</button>
```

### Forced Colors

Respect forced colors mode (Windows High Contrast):

```tsx
export function Card() {
  return (
    <div className="bg-white dark:bg-slate-900 forced-colors:bg-[Canvas] forced-colors:border forced-colors:border-[CanvasText]">
      Content
    </div>
  );
}
```

### Combined Example

```tsx
export function AccessibleCard({ children }: { children: React.ReactNode }) {
  return (
    <div
      className={`
        bg-white dark:bg-slate-900
        text-slate-900 dark:text-slate-50
        rounded-lg
        transition-colors duration-200
        motion-reduce:transition-none
        border border-transparent
        contrast-more:border-slate-300
        forced-colors:bg-[Canvas]
        forced-colors:border-[CanvasText]
      `}
    >
      {children}
    </div>
  );
}
```
