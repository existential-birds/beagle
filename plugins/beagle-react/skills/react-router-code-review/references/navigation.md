# Navigation

## Critical Anti-Patterns

### 1. Using navigate() Instead of Link

**Problem**: Missing accessibility, no progressive enhancement, can't open in new tab.

```tsx
// BAD - navigate() for user-initiated navigation
function UserCard({ userId }: { userId: string }) {
  const navigate = useNavigate();

  return (
    <div onClick={() => navigate(`/users/${userId}`)}>
      <h3>User {userId}</h3>
    </div>
  );
}

// Problems:
// - Can't right-click to open in new tab
// - Can't Cmd+Click to open in new tab
// - Screen readers don't know it's a link
// - No keyboard navigation

// GOOD - Use Link for navigation
function UserCard({ userId }: { userId: string }) {
  return (
    <Link to={`/users/${userId}`} className="user-card">
      <h3>User {userId}</h3>
    </Link>
  );
}

// Benefits:
// - Right-click works
// - Cmd/Ctrl+Click works
// - Accessible to screen readers
// - Tab navigation works
// - Shows URL on hover
```

### 2. Imperative Navigation in Render

**Problem**: Navigation happens during render, causes infinite loops.

```tsx
// BAD - navigate() during render
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const user = useLoaderData<User | null>();
  const navigate = useNavigate();

  if (!user) {
    navigate('/login'); // BAD: navigate during render!
    return null;
  }

  return <>{children}</>;
}

// GOOD - Navigate in effect
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const user = useLoaderData<User | null>();
  const navigate = useNavigate();

  React.useEffect(() => {
    if (!user) {
      navigate('/login');
    }
  }, [user, navigate]);

  if (!user) {
    return <div>Redirecting...</div>;
  }

  return <>{children}</>;
}

// BETTER - Handle in loader
const loader = async ({ request }) => {
  const user = await getUser(request);

  if (!user) {
    // Redirect before component renders
    throw redirect('/login');
  }

  return user;
};
```

### 3. Missing Pending UI States

**Problem**: No feedback during navigation, feels broken.

```tsx
// BAD - No loading state
function UserList() {
  const users = useLoaderData<User[]>();

  return (
    <div>
      <h1>Users</h1>
      <ul>
        {users.map(user => (
          <li key={user.id}>
            <Link to={`/users/${user.id}`}>{user.name}</Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

// User clicks link, nothing happens for 2 seconds, then page changes
// Bad UX!

// GOOD - Show loading state
import { useNavigation } from 'react-router-dom';

function UserList() {
  const users = useLoaderData<User[]>();
  const navigation = useNavigation();

  return (
    <div>
      <h1>Users</h1>
      {navigation.state === 'loading' && (
        <div className="loading-bar" />
      )}
      <ul className={navigation.state === 'loading' ? 'opacity-50' : ''}>
        {users.map(user => (
          <li key={user.id}>
            <Link to={`/users/${user.id}`}>{user.name}</Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

// BETTER - Global loading indicator
function Root() {
  const navigation = useNavigation();

  return (
    <div>
      {navigation.state !== 'idle' && (
        <div className="global-loading-bar">
          Loading...
        </div>
      )}

      <nav>
        <Link to="/">Home</Link>
        <Link to="/users">Users</Link>
      </nav>

      <main className={navigation.state === 'loading' ? 'loading' : ''}>
        <Outlet />
      </main>
    </div>
  );
}
```

### 4. Not Using NavLink for Active Styles

**Problem**: Manual active state management, inconsistent UI.

```tsx
// BAD - Manual active state
function Navigation() {
  const location = useLocation();

  return (
    <nav>
      <Link
        to="/"
        className={location.pathname === '/' ? 'active' : ''}
      >
        Home
      </Link>
      <Link
        to="/users"
        className={location.pathname.startsWith('/users') ? 'active' : ''}
      >
        Users
      </Link>
      <Link
        to="/settings"
        className={location.pathname === '/settings' ? 'active' : ''}
      >
        Settings
      </Link>
    </nav>
  );
}

// GOOD - NavLink with className function
import { NavLink } from 'react-router-dom';

function Navigation() {
  return (
    <nav>
      <NavLink
        to="/"
        end // Only match exact path
        className={({ isActive }) => isActive ? 'active' : ''}
      >
        Home
      </NavLink>
      <NavLink
        to="/users"
        className={({ isActive }) => isActive ? 'active' : ''}
      >
        Users
      </NavLink>
      <NavLink
        to="/settings"
        className={({ isActive }) => isActive ? 'active' : ''}
      >
        Settings
      </NavLink>
    </nav>
  );
}

// BETTER - NavLink with style function
function Navigation() {
  const activeStyle = {
    fontWeight: 'bold',
    color: 'var(--primary)',
    borderBottom: '2px solid var(--primary)',
  };

  return (
    <nav>
      <NavLink
        to="/"
        end
        style={({ isActive }) => isActive ? activeStyle : undefined}
      >
        Home
      </NavLink>
      <NavLink
        to="/users"
        style={({ isActive }) => isActive ? activeStyle : undefined}
      >
        Users
      </NavLink>
    </nav>
  );
}
```

### 5. Not Preserving Search Params on Navigation

**Problem**: Lost state, broken URLs, poor UX.

```tsx
// BAD - Navigation loses search params
function UserFilters() {
  return (
    <div>
      {/* Current URL: /users?sort=name&filter=active */}
      {/* After clicking, URL becomes: /users?sort=date (filter lost!) */}
      <Link to="/users?sort=date">Sort by date</Link>
    </div>
  );
}

// GOOD - Preserve existing search params
function UserFilters() {
  const [searchParams] = useSearchParams();

  const getSortLink = (sort: string) => {
    const params = new URLSearchParams(searchParams);
    params.set('sort', sort);
    return `/users?${params.toString()}`;
  };

  return (
    <div>
      <Link to={getSortLink('date')}>Sort by date</Link>
      <Link to={getSortLink('name')}>Sort by name</Link>
    </div>
  );
}

// BETTER - Reusable hook
function useSearchParamsWithPreserve() {
  const [searchParams, setSearchParams] = useSearchParams();

  const updateSearchParam = React.useCallback(
    (key: string, value: string | null) => {
      setSearchParams(prev => {
        const params = new URLSearchParams(prev);
        if (value === null) {
          params.delete(key);
        } else {
          params.set(key, value);
        }
        return params;
      });
    },
    [setSearchParams]
  );

  return [searchParams, updateSearchParam] as const;
}

function UserFilters() {
  const [searchParams, updateSearchParam] = useSearchParamsWithPreserve();

  return (
    <div>
      <button onClick={() => updateSearchParam('sort', 'date')}>
        Sort by date
      </button>
      <button onClick={() => updateSearchParam('sort', 'name')}>
        Sort by name
      </button>
    </div>
  );
}
```

### 6. Blocking Navigation Without Confirmation

**Problem**: Lost unsaved changes, data loss.

```tsx
// BAD - No confirmation on navigation
function EditUser() {
  const [formData, setFormData] = useState({});
  const [isDirty, setIsDirty] = useState(false);

  // User can navigate away and lose changes!
  return (
    <form>
      <input
        onChange={(e) => {
          setFormData({ ...formData, name: e.target.value });
          setIsDirty(true);
        }}
      />
    </form>
  );
}

// GOOD - Block navigation with confirmation
import { useBlocker } from 'react-router-dom';

function EditUser() {
  const [formData, setFormData] = useState({});
  const [isDirty, setIsDirty] = useState(false);

  // Block navigation if form is dirty
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      isDirty && currentLocation.pathname !== nextLocation.pathname
  );

  return (
    <>
      {blocker.state === 'blocked' && (
        <div className="modal">
          <p>You have unsaved changes. Are you sure you want to leave?</p>
          <button onClick={() => blocker.proceed()}>Leave</button>
          <button onClick={() => blocker.reset()}>Stay</button>
        </div>
      )}

      <form>
        <input
          onChange={(e) => {
            setFormData({ ...formData, name: e.target.value });
            setIsDirty(true);
          }}
        />
      </form>
    </>
  );
}

// BETTER - Also handle browser navigation
function EditUser() {
  const [formData, setFormData] = useState({});
  const [isDirty, setIsDirty] = useState(false);

  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      isDirty && currentLocation.pathname !== nextLocation.pathname
  );

  // Handle browser back/forward, refresh, close
  React.useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (isDirty) {
        e.preventDefault();
        e.returnValue = ''; // Required for Chrome
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [isDirty]);

  return (
    <>
      {blocker.state === 'blocked' && (
        <ConfirmationModal
          onConfirm={() => blocker.proceed()}
          onCancel={() => blocker.reset()}
        />
      )}
      <form>{/* form fields */}</form>
    </>
  );
}
```

### 7. Not Using Relative Paths

**Problem**: Brittle routes, hard to refactor.

```tsx
// BAD - Absolute paths everywhere
// Route: /projects/:projectId/tasks/:taskId

function TaskDetail() {
  const { projectId, taskId } = useParams();

  return (
    <div>
      <Link to={`/projects/${projectId}/tasks`}>Back to tasks</Link>
      <Link to={`/projects/${projectId}/tasks/${taskId}/edit`}>Edit</Link>
      <Link to={`/projects/${projectId}`}>Back to project</Link>
    </div>
  );
}

// If you change the route structure, all these links break!

// GOOD - Relative paths
function TaskDetail() {
  return (
    <div>
      {/* Go up one level */}
      <Link to="..">Back to tasks</Link>

      {/* Stay at current level, append /edit */}
      <Link to="edit">Edit</Link>

      {/* Go up two levels */}
      <Link to="../..">Back to project</Link>
    </div>
  );
}

// BETTER - Mix relative and absolute as appropriate
function TaskDetail() {
  const { projectId } = useParams();

  return (
    <div>
      {/* Relative for sibling/parent routes */}
      <Link to="..">Back to tasks</Link>
      <Link to="edit">Edit</Link>

      {/* Absolute for cross-section navigation */}
      <Link to="/">Home</Link>
      <Link to="/settings">Settings</Link>

      {/* Template when you need params */}
      <Link to={`/projects/${projectId}/settings`}>Project Settings</Link>
    </div>
  );
}
```

## Review Questions

1. Are Links used for navigation instead of navigate()?
2. Is navigate() only called in effects or handlers, not render?
3. Are pending states shown during navigation?
4. Is NavLink used for navigation with active states?
5. Are search params preserved when updating URLs?
6. Are unsaved changes protected with useBlocker?
7. Are relative paths used within route hierarchies?
