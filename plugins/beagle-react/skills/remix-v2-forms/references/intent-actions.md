# Multiple Actions on One Route (the `intent` Pattern)

A Remix route has exactly one `action` export. To handle multiple
operations (like, retweet, delete) without sprawling into separate route
files, encode the operation in a FormData field named `intent` and
switch on it inside the single action.

## The Pattern

```tsx
// app/routes/tweets.$id.tsx
import { json, type ActionFunctionArgs } from "@remix-run/node";
import { useFetcher } from "@remix-run/react";

export async function action({ request, params }: ActionFunctionArgs) {
  const form = await request.formData();
  const intent = form.get("intent");
  switch (intent) {
    case "like":
      return json(await likeTweet(params.id!));
    case "retweet":
      return json(await retweetTweet(params.id!));
    case "delete":
      return json(await deleteTweet(params.id!));
    default:
      throw new Response("Unknown intent", { status: 400 });
  }
}

export default function Tweet() {
  const fetcher = useFetcher();
  const pendingIntent = fetcher.formData?.get("intent");
  return (
    <fetcher.Form method="post">
      <button name="intent" value="like" disabled={pendingIntent === "like"}>
        Like
      </button>
      <button name="intent" value="retweet" disabled={pendingIntent === "retweet"}>
        RT
      </button>
      <button name="intent" value="delete">
        Delete
      </button>
    </fetcher.Form>
  );
}
```

## Why It Works

Only the clicked submit button's `name=value` lands in the form body. So
when the user clicks "Like", `formData.get("intent")` is `"like"`; the
other two buttons contribute nothing. This is HTML-standard form behavior
and works without JS.

Per-button pending state comes from `fetcher.formData?.get("intent")` —
populated synchronously on submit, cleared at `idle`.

## When to Use It

- A row in a list has multiple related actions (like, retweet, delete).
- A form has a primary submit and a "Save as draft" variant.
- A modal handles a small group of related mutations.

When **not** to use it:

- Mutations operate on different resources (different URLs are clearer).
- Operations belong on a different route conceptually (e.g. user vs.
  admin actions on the same record — split them).
- The intents have wildly different request shapes (validation gets
  ugly fast).

## Pattern: Page Form Variant

The same pattern works with page-level `<Form>`:

```tsx
import { Form, useNavigation } from "@remix-run/react";

export default function PostForm() {
  const nav = useNavigation();
  const pending = nav.formData?.get("intent");
  return (
    <Form method="post">
      <input name="body" />
      <button name="intent" value="draft" disabled={pending === "draft"}>
        Save Draft
      </button>
      <button name="intent" value="publish" disabled={pending === "publish"}>
        Publish
      </button>
    </Form>
  );
}
```

Filter on `nav.formAction` too if the route can be the target of multiple
unrelated forms.

## Anti-Patterns

- **Multiple `<form>` elements each posting to a different route** just
  to disambiguate operations. Forces route file sprawl, duplicates
  parsing, and breaks revalidation scope. Use one action with intents.
- **Reading `useActionData()` to detect which intent ran**, without
  including the intent in the response. `useActionData` is per-route,
  not per-intent — the component can't tell whether the "like" or the
  "delete" returned. Either include the intent in the response
  (`json({ intent: "like", ok: true })`) or use a separate
  `useFetcher` per intent.
- **Defaulting to a "happy" intent in the action** when `intent` is
  missing. Better to throw `400` so a bug in the UI doesn't silently
  mutate the wrong way.

## Gotchas

- **Pressing Enter in a text input submits the first button in DOM
  order.** Order your `<button>` elements so the safe / common operation
  comes first. If you have a destructive action ("Delete"), put it
  last and consider requiring a confirmation step.
- `formData.get("intent")` returns `FormDataEntryValue | null`. Compare
  against string literals; do not pass it directly to a discriminated
  union without narrowing.
- The `intent` field is just a convention — any name works as long as
  the action and UI agree. `intent` is the conventional choice and
  matches the broader Remix ecosystem.
