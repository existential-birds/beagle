# Mutations

## Critical Anti-Patterns

### 1. Manual Form Submission with fetch

**Problem**: Missing navigation state, manual revalidation, no progressive enhancement.

```tsx
// BAD - Manual fetch in handler
function CreateUser() {
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setLoading(true);

    const formData = new FormData(e.currentTarget);
    const response = await fetch("/api/users", {
      method: "POST",
      body: JSON.stringify(Object.fromEntries(formData)),
    });

    if (response.ok) {
      navigate("/users");
    } else {
      alert("Error creating user");
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" />
      <button disabled={loading}>
        {loading ? "Creating..." : "Create"}
      </button>
    </form>
  );
}

// GOOD - Using Form and action
import { data, redirect, Form, useNavigation, useActionData, type ActionFunctionArgs } from "react-router";

async function createUserAction({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const response = await fetch("/api/users", {
    method: "POST",
    body: formData,
  });

  if (!response.ok) {
    return data({ error: "Failed to create user" }, { status: response.status });
  }

  return redirect("/users");
}

{
  path: "users/new",
  Component: CreateUser,
  action: createUserAction,
}

function CreateUser() {
  const navigation = useNavigation();
  const actionData = useActionData<typeof createUserAction>();
  const isSubmitting = navigation.state === "submitting";

  return (
    <Form method="post">
      <input name="name" />
      {actionData && "error" in actionData && <div className="error">{actionData.error}</div>}
      <button disabled={isSubmitting}>
        {isSubmitting ? "Creating..." : "Create"}
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
  const todos = useLoaderData<typeof todosLoader>();

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
import { useFetcher, useLoaderData } from "react-router";

function TodoList() {
  const todos = useLoaderData<typeof todosLoader>();

  return (
    <div>
      {todos.map(todo => (
        <TodoItem key={todo.id} todo={todo} />
      ))}
    </div>
  );
}

function TodoItem({ todo }: { todo: Todo }) {
  const fetcher = useFetcher();

  // Optimistic UI - show state immediately
  const isComplete = fetcher.formData
    ? fetcher.formData.get("complete") === "true"
    : todo.complete;

  return (
    <div>
      <span style={{ textDecoration: isComplete ? "line-through" : "none" }}>
        {todo.text}
      </span>
      <fetcher.Form method="post" action={`/todos/${todo.id}/toggle`}>
        <input type="hidden" name="complete" value={String(!isComplete)} />
        <button disabled={fetcher.state !== "idle"}>
          {fetcher.state !== "idle" ? "Toggling..." : "Toggle"}
        </button>
      </fetcher.Form>
    </div>
  );
}
```

### 3. Not Validating Action Data

**Problem**: Runtime errors, poor error messages; returning HTTP 200 on validation errors also triggers unnecessary loader revalidation.

```tsx
// BAD - No validation
const action = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();

  // What if name is missing or invalid?
  const name = formData.get("name");
  const email = formData.get("email");

  await createUser({ name, email });
  return redirect("/users");
};

// GOOD - Validation returning data({ errors }, { status: 400 })
import { data, redirect, type ActionFunctionArgs } from "react-router";

const action = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();
  const rawName = formData.get("name");
  const rawEmail = formData.get("email");
  const name = typeof rawName === "string" ? rawName.trim() : "";
  const email = typeof rawEmail === "string" ? rawEmail.trim() : "";

  const errors: Record<string, string> = {};

  if (name.length === 0) {
    errors.name = "Name is required";
  }

  if (email.length === 0) {
    errors.email = "Email is required";
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    errors.email = "Invalid email format";
  }

  if (Object.keys(errors).length > 0) {
    return data({ errors }, { status: 400 });
  }

  await createUser({ name, email });
  return redirect("/users");
};

// BETTER - Schema validation
import { z } from "zod";
import { data, redirect, useActionData, type ActionFunctionArgs } from "react-router";

const CreateUserSchema = z.object({
  name: z.string().min(1, "Name is required").max(100),
  email: z.string().email("Invalid email format"),
});

const schemaAction = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();
  const payload = Object.fromEntries(formData);

  const parsed = CreateUserSchema.safeParse(payload);
  if (!parsed.success) {
    return data(
      { errors: parsed.error.flatten().fieldErrors },
      { status: 400 }
    );
  }

  await createUser(parsed.data);
  return redirect("/users");
};

// Component using validation errors
function CreateUser() {
  const actionData = useActionData<typeof schemaAction>();

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
        {liked ? "❤️" : "🤍"}
      </button>
    </fetcher.Form>
  );
}

// GOOD - Optimistic UI
function LikeButton({ postId, liked }: { postId: string; liked: boolean }) {
  const fetcher = useFetcher();

  // Show optimistic state immediately
  const optimisticLiked = fetcher.formData
    ? fetcher.formData.get("liked") === "true"
    : liked;

  return (
    <fetcher.Form method="post" action={`/posts/${postId}/like`}>
      <input type="hidden" name="liked" value={String(!optimisticLiked)} />
      <button disabled={fetcher.state !== "idle"}>
        {optimisticLiked ? "❤️" : "🤍"}
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
    ? fetcher.formData.get("liked") === "true"
    : liked;

  const optimisticCount = fetcher.formData
    ? optimisticLiked
      ? likeCount + 1
      : likeCount - 1
    : likeCount;

  return (
    <fetcher.Form method="post" action={`/posts/${postId}/like`}>
      <input type="hidden" name="liked" value={String(!optimisticLiked)} />
      <button disabled={fetcher.state !== "idle"}>
        {optimisticLiked ? "❤️" : "🤍"} {optimisticCount}
      </button>
    </fetcher.Form>
  );
}
```

### 5. Not Handling Action Errors

**Problem**: Silent failures, poor error UX.

```tsx
// BAD - No error handling
const action = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();
  // If this throws, user sees error boundary
  await createUser(Object.fromEntries(formData));
  return redirect("/users");
};

// GOOD - Graceful error handling
const action = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();

  try {
    await createUser(Object.fromEntries(formData));
    return redirect("/users");
  } catch (error) {
    // Return error to show in form, not error boundary
    if (error instanceof Error) {
      return data({ error: error.message }, { status: 400 });
    }
    return data({ error: "An unexpected error occurred" }, { status: 500 });
  }
};

// BETTER - Handle fetch 4xx/5xx directly (fetch() resolves on 4xx/5xx rather than throwing;
// `error instanceof Response` in catch only matches helpers/wrappers that explicitly throw Response)
const actionWithStatus = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();

  try {
    const response = await fetch("/api/users", { method: "POST", body: formData });
    if (!response.ok) {
      const body = await response.json();
      return data({ error: body.message, status: response.status }, { status: response.status });
    }
    return redirect("/users");
  } catch (error) {
    if (error instanceof Response) {
      const body = await error.json();
      return data({ error: body.message, status: error.status }, { status: error.status });
    }

    if (error instanceof Error) {
      return data({ error: error.message }, { status: 500 });
    }

    return data({ error: "An unexpected error occurred" }, { status: 500 });
  }
};

// Component showing errors
function CreateUser() {
  const actionData = useActionData<{ error?: string; status?: number }>();

  return (
    <div>
      {actionData?.error && (
        <div className={actionData.status === 400 ? "warning" : "error"}>
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
const action = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();
  const action = formData.get("_action");

  if (action === "create") {
    // create logic
  } else if (action === "update") {
    // update logic
  } else if (action === "delete") {
    // delete logic
  }

  return redirect("/users");
};

// GOOD - Separate action routes
{
  path: "users",
  children: [
    {
      path: "new",
      Component: CreateUser,
      action: createUserAction,
    },
    {
      path: ":userId/edit",
      Component: EditUser,
      action: updateUserAction,
    },
    {
      path: ":userId/delete",
      action: deleteUserAction,
    }
  ]
}

// ACCEPTABLE - Multiple intents with clear intent field
const intentAction = async ({ request }: ActionFunctionArgs) => {
  const formData = await request.formData();
  const intent = formData.get("intent");

  switch (intent) {
    case "archive":
      return handleArchive(formData);
    case "unarchive":
      return handleUnarchive(formData);
    default:
      throw new Response("Invalid intent", { status: 400 });
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
3. Are action inputs validated before processing and returning `data(..., { status: 400 })` on failure?
4. Are optimistic UI updates shown for immediate feedback?
5. Do actions handle and return errors gracefully?
6. Is action intent clear and single-purpose?
