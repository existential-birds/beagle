# Data Loading

## Critical Anti-Patterns

### 1. Using useEffect Instead of Loaders

**Problem**: Race conditions, loading states, unnecessary client-side fetching.

```tsx
// BAD - Loading data in useEffect
function UserProfile() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const { userId } = useParams();

  useEffect(() => {
    setLoading(true);
    fetch(`/api/users/${userId}`)
      .then(r => r.json())
      .then(setUser)
      .finally(() => setLoading(false));
  }, [userId]);

  if (loading) return <div>Loading...</div>;
  return <div>{user.name}</div>;
}

// GOOD - Using loader
// Route definition
{
  path: "users/:userId",
  element: <UserProfile />,
  loader: async ({ params }) => {
    const response = await fetch(`/api/users/${params.userId}`);
    if (!response.ok) throw new Response("Not Found", { status: 404 });
    return response.json();
  }
}

// Component
function UserProfile() {
  const user = useLoaderData<User>();
  return <div>{user.name}</div>;
}
```

### 2. Unsafe Route Params Access

**Problem**: Runtime errors from missing or invalid params.

```tsx
// BAD - No validation
const loader = async ({ params }) => {
  // params.userId could be undefined!
  return fetch(`/api/users/${params.userId}`);
};

// GOOD - Validate params
const loader = async ({ params }) => {
  const userId = params.userId;
  if (!userId) {
    throw new Response("User ID required", { status: 400 });
  }

  // Optional: validate format
  if (!/^\d+$/.test(userId)) {
    throw new Response("Invalid user ID", { status: 400 });
  }

  return fetch(`/api/users/${userId}`);
};

// BETTER - Type-safe with zod
import { z } from "zod";

const ParamsSchema = z.object({
  userId: z.string().regex(/^\d+$/)
});

const loader = async ({ params }) => {
  const { userId } = ParamsSchema.parse(params);
  return fetch(`/api/users/${userId}`);
};
```

### 3. Sequential Data Fetching

**Problem**: Slow page loads when data can be fetched in parallel.

```tsx
// BAD - Sequential fetching
const loader = async ({ params }) => {
  const user = await fetchUser(params.userId);
  const posts = await fetchPosts(params.userId);
  const comments = await fetchComments(params.userId);

  return { user, posts, comments };
};

// GOOD - Parallel fetching
const loader = async ({ params }) => {
  const [user, posts, comments] = await Promise.all([
    fetchUser(params.userId),
    fetchPosts(params.userId),
    fetchComments(params.userId),
  ]);

  return { user, posts, comments };
};

// BETTER - Using defer for progressive loading
import { defer } from "react-router-dom";

const loader = async ({ params }) => {
  // Critical data - await it
  const user = await fetchUser(params.userId);

  // Non-critical data - defer it
  return defer({
    user,
    posts: fetchPosts(params.userId), // Don't await
    comments: fetchComments(params.userId), // Don't await
  });
};

// Component with Suspense
function UserProfile() {
  const { user, posts, comments } = useLoaderData();

  return (
    <div>
      <h1>{user.name}</h1>

      <Suspense fallback={<div>Loading posts...</div>}>
        <Await resolve={posts}>
          {(posts) => <PostList posts={posts} />}
        </Await>
      </Suspense>

      <Suspense fallback={<div>Loading comments...</div>}>
        <Await resolve={comments}>
          {(comments) => <CommentList comments={comments} />}
        </Await>
      </Suspense>
    </div>
  );
}
```

### 4. Not Revalidating After Mutations

**Problem**: Stale data after updates, manual cache invalidation.

```tsx
// BAD - Manual refetch
function UserProfile() {
  const user = useLoaderData<User>();
  const [localUser, setLocalUser] = useState(user);

  const handleUpdate = async (data) => {
    await fetch(`/api/users/${user.id}`, {
      method: "PATCH",
      body: JSON.stringify(data),
    });

    // Manual refetch - easy to forget!
    const updated = await fetch(`/api/users/${user.id}`).then(r => r.json());
    setLocalUser(updated);
  };

  return <UserForm user={localUser} onSubmit={handleUpdate} />;
}

// GOOD - Automatic revalidation
// Action automatically triggers loader revalidation
const action = async ({ request, params }) => {
  const formData = await request.formData();
  const response = await fetch(`/api/users/${params.userId}`, {
    method: "PATCH",
    body: formData,
  });

  if (!response.ok) throw new Response("Update failed", { status: 400 });
  return redirect(`/users/${params.userId}`);
};

function UserProfile() {
  const user = useLoaderData<User>();
  // No useState needed - loader data auto-revalidates
  return <UserForm user={user} />;
}
```

### 5. Missing Error Handling in Loaders

**Problem**: Uncaught errors, poor user experience.

```tsx
// BAD - No error handling
const loader = async ({ params }) => {
  const response = await fetch(`/api/users/${params.userId}`);
  return response.json(); // What if response is 404 or 500?
};

// GOOD - Proper error handling
const loader = async ({ params }) => {
  const response = await fetch(`/api/users/${params.userId}`);

  if (!response.ok) {
    throw new Response("User not found", {
      status: response.status,
      statusText: response.statusText
    });
  }

  return response.json();
};

// BETTER - Detailed error responses
const loader = async ({ params }) => {
  try {
    const response = await fetch(`/api/users/${params.userId}`);

    if (response.status === 404) {
      throw new Response("User not found", { status: 404 });
    }

    if (response.status === 403) {
      throw new Response("You don't have permission to view this user", {
        status: 403
      });
    }

    if (!response.ok) {
      throw new Response("Failed to load user", {
        status: response.status
      });
    }

    return response.json();
  } catch (error) {
    if (error instanceof Response) throw error;

    // Network error or other unexpected error
    throw new Response("Network error - please try again", {
      status: 503
    });
  }
};
```

### 6. Accessing Search Params Without URLSearchParams

**Problem**: Manual string parsing, inconsistent handling.

```tsx
// BAD - Manual parsing
const loader = async ({ request }) => {
  const url = new URL(request.url);
  const search = url.search.slice(1); // Remove '?'
  const page = search.split('&').find(p => p.startsWith('page='))?.split('=')[1] || '1';

  return fetchUsers(parseInt(page));
};

// GOOD - Using URLSearchParams
const loader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get('page') || '1';

  return fetchUsers(parseInt(page, 10));
};

// BETTER - Type-safe search params
import { z } from "zod";

const SearchParamsSchema = z.object({
  page: z.coerce.number().min(1).default(1),
  sort: z.enum(['name', 'date', 'popular']).default('name'),
  filter: z.string().optional(),
});

const loader = async ({ request }) => {
  const url = new URL(request.url);
  const rawParams = Object.fromEntries(url.searchParams);
  const { page, sort, filter } = SearchParamsSchema.parse(rawParams);

  return fetchUsers({ page, sort, filter });
};
```

## Review Questions

1. Is all route data loaded via loaders, not useEffect?
2. Are route params validated before use?
3. Are independent data fetches executed in parallel?
4. Is defer() used for non-critical data?
5. Do loaders throw proper Response objects on errors?
6. Are search params parsed with URLSearchParams?
