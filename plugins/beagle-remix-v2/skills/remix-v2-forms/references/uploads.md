# File Uploads

Remix v2 ships file-upload helpers under permanent `unstable_` prefixes.
The API was renamed without the prefix in React Router v7 — in v2 you
keep the prefix. Code that migrates needs to update imports.

## The Three Helpers

| Import | Purpose |
|---|---|
| `unstable_parseMultipartFormData(request, uploadHandler)` | Parse a `multipart/form-data` request body in an action. Returns `Promise<FormData>`. |
| `unstable_createMemoryUploadHandler({ maxPartSize?, filter? })` | In-memory upload handler. Returns a `File`. For small files only. |
| `unstable_createFileUploadHandler({ directory?, maxPartSize?, filter?, file? })` | Disk-backed upload handler. Streams to a directory. For larger files. |

All three live in `@remix-run/node` (or `@remix-run/cloudflare` for the
Cloudflare adapter). The `unstable_` prefix is **permanent in v2** — do
not strip it expecting it to work.

## `encType="multipart/form-data"` Is Mandatory

Without it, `request.formData()` strips file data. `formData.get("avatar")`
returns the filename **string**, not a `File`. The upload silently
fails. Set `encType="multipart/form-data"` on the `<Form>` AND parse via
`unstable_parseMultipartFormData` in the action.

## Pattern: In-Memory Upload (Small Files)

```tsx
// app/routes/avatar.tsx
import {
  json,
  redirect,
  unstable_createMemoryUploadHandler,
  unstable_parseMultipartFormData,
  type ActionFunctionArgs,
} from "@remix-run/node";
import { Form } from "@remix-run/react";

export async function action({ request }: ActionFunctionArgs) {
  const uploadHandler = unstable_createMemoryUploadHandler({
    maxPartSize: 500_000, // 500 KB cap; reject larger uploads
  });
  const formData = await unstable_parseMultipartFormData(request, uploadHandler);
  const file = formData.get("avatar");
  if (!(file instanceof File)) return json({ error: "No file" }, { status: 400 });
  await storeAvatar(file);
  return redirect("/account");
}

export default function AvatarRoute() {
  return (
    <Form method="post" encType="multipart/form-data">
      <input type="file" name="avatar" accept="image/*" />
      <button>Upload</button>
    </Form>
  );
}
```

Memory handler is fine for avatars and small attachments (a few hundred
KB). For anything larger, use `unstable_createFileUploadHandler` or
stream directly to object storage.

## Pattern: Disk-Backed Upload

```tsx
import {
  unstable_createFileUploadHandler,
  unstable_parseMultipartFormData,
  type ActionFunctionArgs,
} from "@remix-run/node";

export async function action({ request }: ActionFunctionArgs) {
  const uploadHandler = unstable_createFileUploadHandler({
    directory: "/tmp/uploads",
    maxPartSize: 10_000_000,    // 10 MB
    file: ({ filename }) => filename,
    filter: ({ contentType }) => contentType.startsWith("image/"),
  });
  const formData = await unstable_parseMultipartFormData(request, uploadHandler);
  const upload = formData.get("attachment");
  // upload is a NodeOnDiskFile — has .name, .size, .type, and .getFilePath()
  // Move it to permanent storage, then delete the temp file.
  return json({ ok: true });
}
```

`unstable_createFileUploadHandler` streams the part to disk. The returned
file object exposes the temp path; move or stream from there to your
permanent store, then clean up.

## Bound Every Handler

**Always pass `maxPartSize`.** Without it,
`unstable_createMemoryUploadHandler` will buffer entire uploads into RAM.
A single malicious upload can OOM the server. The disk handler will fill
the disk. Treat unbounded handlers as a security bug.

`filter` is the second line of defense: reject parts whose `contentType`
or `name` doesn't match what you accept.

```ts
const uploadHandler = unstable_createMemoryUploadHandler({
  maxPartSize: 500_000,
  filter: ({ contentType, name }) =>
    name === "avatar" && contentType.startsWith("image/"),
});
```

## Anti-Patterns

- **`<Form method="post">` with `<input type="file">` but no `encType`.**
  The file silently isn't sent; `formData.get("avatar")` returns the
  filename string. Set `encType="multipart/form-data"`.
- **`unstable_createMemoryUploadHandler()` with no `maxPartSize`.**
  Unbounded RAM buffering — OOM risk. Always bound.
- **Stripping the `unstable_` prefix in v2.** The prefix is permanent in
  Remix v2; only React Router v7 renamed these without it.
- **Using the memory handler for user-uploaded photos / documents.**
  Anything over ~1 MB should stream to disk or object storage.
- **Trusting `file.name` or `file.type` as security boundaries.** Both
  are user-controlled. Validate magic bytes, scan content, or run
  uploads through a trusted processor.

## Gotchas

- `unstable_parseMultipartFormData` returns the parsed `FormData`. Use
  `formData.get(name) instanceof File` to discriminate text fields from
  uploads — `get` can return string, File, or null.
- Mixed forms (text fields + file inputs) work fine: text fields pass
  through `formData` as strings; only file inputs invoke the upload
  handler.
- The Cloudflare adapter (`@remix-run/cloudflare`) re-exports these
  helpers with the same `unstable_` names. Node and Cloudflare imports
  are interchangeable at the type level but pick one matching your
  runtime.
- Upload handlers run on the server. The `request` object cannot be
  consumed twice — call `unstable_parseMultipartFormData(request, ...)`
  exactly once per action.
