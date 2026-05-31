# Multi-action Routes & Method Choice

Flag route file sprawl that the intent pattern would collapse, missing
submit buttons that break progressive enhancement, and `method="put"` /
`"patch"` / `"delete"` without a JS-only acknowledgement. See
[remix-v2-forms](../../remix-v2-forms/SKILL.md) for the
canonical intent pattern.

## Anti-pattern 1 — Separate routes for sibling mutations

```text
// BAD — file tree
app/routes/
  tweets.$id.like.tsx
  tweets.$id.unlike.tsx
  tweets.$id.retweet.tsx
  tweets.$id.delete.tsx
```

```tsx
// Each route has a tiny action and no default export
export async function action({ params }: ActionFunctionArgs) {
  await likeTweet(params.id!);
  return json({ ok: true });
}
```

**Why bad:** Four route files for one logical resource. Each duplicates
parsing, auth checks, and revalidation scope. The component now juggles
four `useFetcher()` instances or four `<Form action>` targets when one
would do. Adds friction for new operations (every new mutation needs a
new file).

**Fix:** Single route `app/routes/tweets.$id.tsx` with one `action`
that switches on `formData.get("intent")`. Each operation is a `<button
name="intent" value="...">` inside one `<fetcher.Form>`.

```tsx
export async function action({ request, params }: ActionFunctionArgs) {
  const fd = await request.formData();
  switch (fd.get("intent")) {
    case "like":    return json(await likeTweet(params.id!));
    case "retweet": return json(await retweetTweet(params.id!));
    case "delete":  return json(await deleteTweet(params.id!));
    default: throw new Response("Unknown intent", { status: 400 });
  }
}

export default function Tweet() {
  const fetcher = useFetcher();
  const pendingIntent = fetcher.formData?.get("intent");
  return (
    <fetcher.Form method="post">
      <button name="intent" value="like" disabled={pendingIntent === "like"}>Like</button>
      <button name="intent" value="retweet" disabled={pendingIntent === "retweet"}>RT</button>
      <button name="intent" value="delete">Delete</button>
    </fetcher.Form>
  );
}
```

**Exemptions — do NOT flag:**

- The mutations live on genuinely different resources (`/posts/:id/like`
  vs `/users/:id/follow`).
- Each route owns substantively different auth, validation, or
  revalidation requirements.
- One mutation is a webhook target and not a UI submission.

## Anti-pattern 2 — Action chooses intent from non-button source

```tsx
// BAD — intent inferred from field presence
export async function action({ request }: ActionFunctionArgs) {
  const fd = await request.formData();
  if (fd.has("like")) return like();
  if (fd.has("retweet")) return retweet();
}
```

**Why bad:** Only the clicked submit button's `name=value` lands in the
body. Inferring intent from field presence couples the action to a
specific render order and breaks under refactor. Pressing Enter in a
text input submits the FIRST button in DOM order, so the inferred
intent may not match user expectation.

**Fix:** Use `<button name="intent" value="...">` and read
`formData.get("intent")`. Order buttons so the first is the correct
Enter-key default.

Older codebases may use `_action` instead of `intent` — treat as equivalent; do not flag the spelling difference unless the action handler hardcodes one name.

## Anti-pattern 3 — `method="put"` / `"patch"` / `"delete"` without fallback

```tsx
// BAD — works only with JS
<Form method="delete" action={`/posts/${id}`}>
  <button>Delete</button>
</Form>
```

**Why bad:** Native HTML forms only support `GET` and `POST`. Without
JS, the browser degrades `method="delete"` to GET, which usually hits
the loader (or 405s the action) — the delete silently never happens.
Progressive enhancement is silently broken.

**Fix:** If progressive enhancement matters for this surface, use
`method="post"` and dispatch via an `intent` field:

```tsx
<Form method="post" action={`/posts/${id}`}>
  <input type="hidden" name="intent" value="delete" />
  <button>Delete</button>
</Form>
```

If the surface is admin-only or JS-required, document the constraint
near the form and move on. Flag missing acknowledgement, not the
choice itself.

**Exemptions — do NOT flag:**

- The route is explicitly an internal admin tool with a JS requirement
  documented in project conventions (e.g. `AGENTS.md` or `CLAUDE.md`), README, or a comment.
- The form is `method="get"` — GET is the only other HTML-native verb
  and works fine without JS.

## Anti-pattern 4 — `<button type="button">` as the only submit

```tsx
// BAD — no native submit path
<Form method="post">
  <input name="title" />
  <button type="button" onClick={() => submit(formRef.current!)}>Save</button>
</Form>
```

**Why bad:** Without JS, pressing Enter or clicking "Save" does
nothing — the action never runs. Progressive enhancement is gone.

**Fix:** Keep at least one `<button>` (default `type="submit"`) inside
the `<Form>` body so the native submit path works. Use `useSubmit()`
only for genuinely programmatic submission (autosave, keyboard
shortcuts) and pair it with a real submit button as fallback.

**Exemptions — do NOT flag:** JS-only admin tool with documented
constraint; controlled wizard step where the parent owns submit.

## Verification before reporting

1. For separate-routes findings, read all sibling route files and
   confirm the mutations are genuinely on the same resource with
   compatible auth and validation. False positives are common when the
   routes look similar but encapsulate different domains.
2. For PUT/PATCH/DELETE findings, check whether the project has a
   declared no-JS-fallback stance (project conventions such as `AGENTS.md`
   or `CLAUDE.md`, repo README, or per-file comments). If so, downgrade to
   a low-severity note.
3. For intent-inference findings, confirm there is at least one
   `<button name="intent">` somewhere — many codebases mix patterns
   inconsistently.
4. For missing-submit-button findings, confirm no `<button>` (without `type="button"`) and no `<input type="submit">` exists inside the `<Form>`.
