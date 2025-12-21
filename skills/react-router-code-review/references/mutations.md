# Mutations

## Critical Anti-Patterns

### 1. Manual Form Submission with fetch

**Problem**: Missing navigation state, manual revalidation, no progressive enhancement.

```tsx
// BAD - Manual fetch in handler
function CreateUser() {
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    const formData = new FormData(e.target);
    const response = await fetch('/api/users', {
      method: 'POST',
      body: JSON.stringify(Object.fromEntries(formData)),
    });

    if (response.ok) {
      navigate('/users');
    } else {
      alert('Error creating user');
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" />
      <button disabled={loading}>
        {loading ? 'Creating...' : 'Create'}
      </button>
    </form>
  );
}

// GOOD - Using Form and action
// Route definition
{
  path: "users/new",
  element: <CreateUser />,
  action: async ({ request }) => {
    const formData = await request.formData();
    const response = await fetch('/api/users', {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      return { error: 'Failed to create user' };
    }

    return redirect('/users');
  }
}

// Component
import { Form, useNavigation, useActionData } from 'react-router-dom';

function CreateUser() {
  const navigation = useNavigation();
  const actionData = useActionData();
  const isSubmitting = navigation.state === 'submitting';

  return (
    <Form method="post">
      <input name="name" />
      {actionData?.error && <div className="error">{actionData.error}</div>}
      <button disabled={isSubmitting}>
        {isSubmitting ? 'Creating...' : 'Create'}
      </button>
    </Form>
  );
}
```

### 2. Using Form When useFetcher is Appropriate

**Problem**: Unnecessary navigation, losing current page state.

```tsx
// BAD - Form causes navigation away from current page
function TodoList() {
  const todos = useLoaderData<Todo[]>();

  return (
    <div>
      {todos.map(todo => (
        <div key={todo.id}>
          <span>{todo.text}</span>
          {/* This will navigate away! */}
          <Form method="post" action={`/todos/${todo.id}/toggle`}>
            <button>Toggle</button>
          </Form>
        </div>
      ))}
    </div>
  );
}

// GOOD - useFetcher stays on current page
import { useFetcher } from 'react-router-dom';

function TodoList() {
  const todos = useLoaderData<Todo[]>();

  return (
    <div>
      {todos.map(todo => (
        <TodoItem key={todo.id} todo={todo} />
      ))}
    </div>
  );
}

function TodoItem({ todo }) {
  const fetcher = useFetcher();

  // Optimistic UI - show state immediately
  const isComplete = fetcher.formData
    ? fetcher.formData.get('complete') === 'true'
    : todo.complete;

  return (
    <div>
      <span style={{ textDecoration: isComplete ? 'line-through' : 'none' }}>
        {todo.text}
      </span>
      <fetcher.Form method="post" action={`/todos/${todo.id}/toggle`}>
        <input type="hidden" name="complete" value={String(!isComplete)} />
        <button disabled={fetcher.state !== 'idle'}>
          {fetcher.state !== 'idle' ? 'Toggling...' : 'Toggle'}
        </button>
      </fetcher.Form>
    </div>
  );
}
```

### 3. Not Validating Action Data

**Problem**: Runtime errors, poor error messages.

```tsx
// BAD - No validation
const action = async ({ request }) => {
  const formData = await request.formData();

  // What if name is missing or invalid?
  const name = formData.get('name');
  const email = formData.get('email');

  await createUser({ name, email });
  return redirect('/users');
};

// GOOD - Validation with helpful errors
const action = async ({ request }) => {
  const formData = await request.formData();
  const name = formData.get('name');
  const email = formData.get('email');

  const errors = {};

  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    errors.name = 'Name is required';
  }

  if (!email || typeof email !== 'string') {
    errors.email = 'Email is required';
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    errors.email = 'Invalid email format';
  }

  if (Object.keys(errors).length > 0) {
    return { errors };
  }

  await createUser({ name, email });
  return redirect('/users');
};

// BETTER - Schema validation
import { z } from 'zod';

const CreateUserSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email('Invalid email format'),
});

const action = async ({ request }) => {
  const formData = await request.formData();
  const data = Object.fromEntries(formData);

  try {
    const validated = CreateUserSchema.parse(data);
    await createUser(validated);
    return redirect('/users');
  } catch (error) {
    if (error instanceof z.ZodError) {
      return {
        errors: error.flatten().fieldErrors
      };
    }
    throw error;
  }
};

// Component using validation errors
function CreateUser() {
  const actionData = useActionData<{ errors?: Record<string, string[]> }>();

  return (
    <Form method="post">
      <div>
        <input name="name" />
        {actionData?.errors?.name && (
          <span className="error">{actionData.errors.name[0]}</span>
        )}
      </div>
      <div>
        <input name="email" type="email" />
        {actionData?.errors?.email && (
          <span className="error">{actionData.errors.email[0]}</span>
        )}
      </div>
      <button>Create User</button>
    </Form>
  );
}
```

### 4. Missing Optimistic UI

**Problem**: Slow perceived performance, no immediate feedback.

```tsx
// BAD - No optimistic update
function LikeButton({ postId, liked }: { postId: string; liked: boolean }) {
  const fetcher = useFetcher();

  return (
    <fetcher.Form method="post" action={`/posts/${postId}/like`}>
      <button>
        {/* Only updates after server responds */}
        {liked ? '❤️' : '🤍'}
      </button>
    </fetcher.Form>
  );
}

// GOOD - Optimistic UI
function LikeButton({ postId, liked }: { postId: string; liked: boolean }) {
  const fetcher = useFetcher();

  // Show optimistic state immediately
  const optimisticLiked = fetcher.formData
    ? fetcher.formData.get('liked') === 'true'
    : liked;

  return (
    <fetcher.Form method="post" action={`/posts/${postId}/like`}>
      <input type="hidden" name="liked" value={String(!optimisticLiked)} />
      <button disabled={fetcher.state !== 'idle'}>
        {optimisticLiked ? '❤️' : '🤍'}
      </button>
    </fetcher.Form>
  );
}

// BETTER - Optimistic UI with count
function LikeButton({
  postId,
  liked,
  likeCount
}: {
  postId: string;
  liked: boolean;
  likeCount: number;
}) {
  const fetcher = useFetcher();

  const optimisticLiked = fetcher.formData
    ? fetcher.formData.get('liked') === 'true'
    : liked;

  const optimisticCount = fetcher.formData
    ? optimisticLiked
      ? likeCount + 1
      : likeCount - 1
    : likeCount;

  return (
    <fetcher.Form method="post" action={`/posts/${postId}/like`}>
      <input type="hidden" name="liked" value={String(!optimisticLiked)} />
      <button disabled={fetcher.state !== 'idle'}>
        {optimisticLiked ? '❤️' : '🤍'} {optimisticCount}
      </button>
    </fetcher.Form>
  );
}
```

### 5. Not Handling Action Errors

**Problem**: Silent failures, poor error UX.

```tsx
// BAD - No error handling
const action = async ({ request }) => {
  const formData = await request.formData();
  // If this throws, user sees error boundary
  await createUser(Object.fromEntries(formData));
  return redirect('/users');
};

// GOOD - Graceful error handling
const action = async ({ request }) => {
  const formData = await request.formData();

  try {
    await createUser(Object.fromEntries(formData));
    return redirect('/users');
  } catch (error) {
    // Return error to show in form, not error boundary
    if (error instanceof Error) {
      return { error: error.message };
    }
    return { error: 'An unexpected error occurred' };
  }
};

// BETTER - Typed errors with status
const action = async ({ request }) => {
  const formData = await request.formData();

  try {
    await createUser(Object.fromEntries(formData));
    return redirect('/users');
  } catch (error) {
    if (error instanceof Response) {
      // API returned error response
      const body = await error.json();
      return { error: body.message, status: error.status };
    }

    if (error instanceof Error) {
      return { error: error.message };
    }

    return { error: 'An unexpected error occurred' };
  }
};

// Component showing errors
function CreateUser() {
  const actionData = useActionData<{ error?: string; status?: number }>();

  return (
    <div>
      {actionData?.error && (
        <div className={actionData.status === 400 ? 'warning' : 'error'}>
          {actionData.error}
        </div>
      )}
      <Form method="post">
        {/* form fields */}
      </Form>
    </div>
  );
}
```

### 6. Action Without Intent

**Problem**: Multiple actions in one endpoint, unclear intent.

```tsx
// BAD - Multiple actions in one action function
const action = async ({ request }) => {
  const formData = await request.formData();
  const action = formData.get('_action');

  if (action === 'create') {
    // create logic
  } else if (action === 'update') {
    // update logic
  } else if (action === 'delete') {
    // delete logic
  }

  return redirect('/users');
};

// GOOD - Separate action routes
// Route definition
{
  path: "users",
  children: [
    {
      path: "new",
      element: <CreateUser />,
      action: createUserAction,
    },
    {
      path: ":userId/edit",
      element: <EditUser />,
      action: updateUserAction,
    },
    {
      path: ":userId/delete",
      action: deleteUserAction,
    }
  ]
}

// ACCEPTABLE - Multiple intents with clear intent field
const action = async ({ request }) => {
  const formData = await request.formData();
  const intent = formData.get('intent');

  switch (intent) {
    case 'archive':
      return handleArchive(formData);
    case 'unarchive':
      return handleUnarchive(formData);
    default:
      throw new Response('Invalid intent', { status: 400 });
  }
};

// Component making intent clear
<fetcher.Form method="post">
  <input type="hidden" name="intent" value="archive" />
  <button>Archive</button>
</fetcher.Form>
```

## Review Questions

1. Are mutations using Form/fetcher.Form instead of manual fetch?
2. Is useFetcher used for actions that shouldn't navigate?
3. Are action inputs validated before processing?
4. Are optimistic UI updates shown for immediate feedback?
5. Do actions handle and return errors gracefully?
6. Is action intent clear and single-purpose?
