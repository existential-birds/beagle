# Actions and Mutations

## Contents

- [Basic Action Pattern](#basic-action-pattern)
- [Form Submission](#form-submission)
- [Redirect After Action](#redirect-after-action)
- [Form Validation](#form-validation)
- [Fetchers (Non-Navigation Mutations)](#fetchers-non-navigation-mutations)
- [Optimistic UI with Fetchers](#optimistic-ui-with-fetchers)
- [Fetcher for Data Loading (Combobox)](#fetcher-for-data-loading-combobox)
- [Optimistic List Updates](#optimistic-list-updates)
- [Client Actions](#client-actions)

---

## Basic Action Pattern

```tsx
import { useActionData, type ActionFunctionArgs } from "react-router";

async function projectAction({ request, params }: ActionFunctionArgs) {
  const formData = await request.formData();
  const title = String(formData.get("title") ?? "");
  await updateProject(params.id!, { title });
  return { success: true };
}

{
  path: "/projects/:id",
  action: projectAction,
  Component: Project,
}
```

## Form Submission

```tsx
import { Form, useActionData } from "react-router";

function Project() {
  const actionData = useActionData<typeof projectAction>();

  return (
    <Form method="post">
      <input type="text" name="title" />
      <button type="submit">Save</button>
      {actionData?.success && <p>Saved!</p>}
    </Form>
  );
}
```

## Redirect After Action

```tsx
import { redirect, type ActionFunctionArgs } from "react-router";

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const project = await createProject(formData);
  return redirect(`/projects/${project.id}`);
}
```

## Form Validation

Return `data({ errors }, { status: 400 })` on validation failures. On standard `<Form>` / `useSubmit` submissions, 4xx/5xx statuses skip default loader revalidation (`defaultShouldRevalidate` is `false`; `shouldRevalidate` can still override for fetchers or `clientAction`).

- Use `<Form>` + `actionData` when success navigates via `redirect(...)`:
```tsx
import { Form, data, redirect } from "react-router";
import type { Route } from "./+types/signup";

export async function action({ request }: Route.ActionArgs) {
  const formData = await request.formData();
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");

  const errors: Record<string, string> = {};

  if (!email.includes("@")) {
    errors.email = "Invalid email address";
  }
  if (password.length < 12) {
    errors.password = "Password must be at least 12 characters";
  }

  if (Object.keys(errors).length > 0) {
    return data({ errors }, { status: 400 });
  }

  return redirect("/dashboard");
}

export default function Signup({ actionData }: Route.ComponentProps) {
  const errors = actionData?.errors;

  return (
    <Form method="post">
      <input type="email" name="email" />
      {errors?.email && <em>{errors.email}</em>}

      <input type="password" name="password" />
      {errors?.password && <em>{errors.password}</em>}

      <button type="submit">Sign Up</button>
    </Form>
  );
}
```

- When submitting inline without navigation (same-page form), type `const fetcher = useFetcher<typeof action>();` and render `<fetcher.Form method="post">` reading `fetcher.data?.errors`.

## Fetchers (Non-Navigation Mutations)

Use fetchers when you DON'T want URL changes:

```tsx
import { useFetcher } from "react-router";

interface Todo {
  id: string;
  title: string;
}

function TodoItem({ todo }: { todo: Todo }) {
  const fetcher = useFetcher();
  const isDeleting = fetcher.state !== "idle";

  return (
    <li>
      <span>{todo.title}</span>
      <fetcher.Form method="post" action="/todos/delete">
        <input type="hidden" name="id" value={todo.id} />
        <button type="submit" disabled={isDeleting}>
          {isDeleting ? "Deleting..." : "Delete"}
        </button>
      </fetcher.Form>
    </li>
  );
}
```

## Optimistic UI with Fetchers

```tsx
import { useFetcher, useLoaderData } from "react-router";

function Component() {
  const data = useLoaderData<{ title: string }>();
  const fetcher = useFetcher();

  // Show optimistic state while submitting
  const title = String(fetcher.formData?.get("title") ?? data.title);

  return (
    <div>
      <h1>{title}</h1>
      <fetcher.Form method="post">
        <input type="text" name="title" />
        {fetcher.state !== "idle" && <p>Saving...</p>}
      </fetcher.Form>
    </div>
  );
}
```

## Fetcher for Data Loading (Combobox)

```tsx
import { useFetcher } from "react-router";

function UserSearchCombobox() {
  const fetcher = useFetcher<Array<{ id: string; name: string }>>();

  return (
    <div>
      <fetcher.Form method="get" action="/search-users">
        <input
          type="text"
          name="q"
          onChange={(e) => fetcher.submit(e.currentTarget.form)}
        />
      </fetcher.Form>
      {fetcher.data && (
        <ul style={{ opacity: fetcher.state === "idle" ? 1 : 0.25 }}>
          {fetcher.data.map((user) => (
            <li key={user.id}>{user.name}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

## Optimistic List Updates

```tsx
import { useFetcher, useLoaderData } from "react-router";

function TodoList() {
  const { todos } = useLoaderData<{ todos: Array<{ id: string; title: string }> }>();
  const fetcher = useFetcher();

  const displayedTodos = todos.filter((todo) => {
    const isDeleting = fetcher.formData?.get("id") === todo.id;
    return !isDeleting;
  });

  return (
    <ul>
      {displayedTodos.map((todo) => (
        <li key={todo.id}>
          {todo.title}
          <fetcher.Form method="post" action="/todos/delete">
            <input type="hidden" name="id" value={todo.id} />
            <button type="submit">Delete</button>
          </fetcher.Form>
        </li>
      ))}
    </ul>
  );
}
```

## Client Actions

In Framework Mode, export `clientAction` to handle mutations directly in the browser (e.g., client caches or calling `serverAction()` alongside client state updates):

```tsx
import type { Route } from "./+types/settings";

export async function clientAction({ request, serverAction }: Route.ClientActionArgs) {
  const formData = await request.clone().formData();
  localStorage.setItem("theme", String(formData.get("theme") ?? "light"));
  return await serverAction();
}
```
