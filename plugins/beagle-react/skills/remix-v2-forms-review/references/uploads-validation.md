# Uploads, FormData Validation & Optimistic State

Flag upload handlers that can be weaponized for DoS, file inputs that
silently strip their contents, FormData consumed without validation,
and optimistic UI that drifts from `fetcher.formData`. See
[beagle-react:remix-v2-forms](../../remix-v2-forms/SKILL.md) for the
canonical upload and optimistic patterns.

## Anti-pattern 1 — Unbounded `unstable_createMemoryUploadHandler`

```tsx
// BAD — no maxPartSize, user input
import {
  unstable_createMemoryUploadHandler,
  unstable_parseMultipartFormData,
} from "@remix-run/node";

export async function action({ request }: ActionFunctionArgs) {
  const handler = unstable_createMemoryUploadHandler({});  // no cap
  const fd = await unstable_parseMultipartFormData(request, handler);
  await storeAvatar(fd.get("avatar"));
  return redirect("/account");
}
```

**Why bad:** The memory upload handler buffers entire uploads into RAM.
Without `maxPartSize`, a single malicious POST with a multi-gigabyte
body can OOM the server. This is a denial-of-service surface, not a
theoretical concern — it is exploitable from the public internet by
anyone who can submit the form.

**Fix:** Always pass `maxPartSize`, and prefer
`unstable_createFileUploadHandler` (disk-backed) or a streaming
upload directly to object storage for anything larger than ~1 MB.

```tsx
const handler = unstable_createMemoryUploadHandler({
  maxPartSize: 500_000,           // 500 KB cap; reject larger uploads
  filter: ({ contentType }) => contentType.startsWith("image/"),
});
```

**Exemptions — do NOT flag:**

- Internal admin-only routes behind authentication where input size is
  bounded by upstream constraints (still better to set a cap).
- A fixed-size internal artifact uploaded by a trusted job runner.

## Anti-pattern 2 — Missing `encType="multipart/form-data"` on file upload

```tsx
// BAD — file data is silently stripped
export default function AvatarRoute() {
  return (
    <Form method="post">
      <input type="file" name="avatar" />
      <button>Upload</button>
    </Form>
  );
}
```

**Why bad:** Without `encType="multipart/form-data"`, the browser
encodes the form as `application/x-www-form-urlencoded`.
`request.formData()` then yields the filename string for `avatar`, not
a `File` instance. The upload silently fails — the action runs, sees a
string where it expected a file, and either errors out or stores
garbage.

**Fix:** Set `encType="multipart/form-data"` on the `<Form>` and parse
in the action via `unstable_parseMultipartFormData` with a bounded
upload handler.

```tsx
<Form method="post" encType="multipart/form-data">
  <input type="file" name="avatar" accept="image/*" />
  <button>Upload</button>
</Form>
```

## Anti-pattern 3 — `request.formData()` values trusted as-is

```tsx
// BAD
export async function action({ request }: ActionFunctionArgs) {
  const fd = await request.formData();
  await db.user.update({
    where: { id: fd.get("id") as string },
    data: {
      email: fd.get("email") as string,
      age: Number(fd.get("age")),
    },
  });
  return redirect("/account");
}
```

**Why bad:** `FormData.get()` returns `FormDataEntryValue | null` — a
string, a `File`, or `null`. `as string` lies to the type system. An
empty form field, a repeated key, a file upload masquerading as a
text input, or a missing key all flow straight into the DB. `Number()`
on `null` is `0`; on an empty string is also `0`. Coercion silently
corrupts data.

**Fix:** Validate every field. Cast explicitly with
`String(fd.get("x") ?? "")`, then run a schema validator (Zod,
Valibot, or hand-rolled checks) before any DB call.

```tsx
const id = String(fd.get("id") ?? "");
const email = String(fd.get("email") ?? "");
const age = Number(fd.get("age") ?? "");

if (!id) return json({ error: "missing id" }, { status: 400 });
if (!email.includes("@")) return json({ errors: { email: "invalid" } }, { status: 400 });
if (!Number.isFinite(age) || age < 0) return json({ errors: { age: "invalid" } }, { status: 400 });
```

**Exemptions — do NOT flag:**

- A wrapper helper (e.g. `parseForm(request, schema)`) is in use and
  delegates validation. Flag only the call sites that bypass it.
- The action is server-internal (e.g. called only by another action via
  `fetch` on the server) where input shape is provably bounded.

## Anti-pattern 4 — Mirroring `fetcher.formData` into local state

```tsx
// BAD
function FavoriteButton({ favorited }: { favorited: boolean }) {
  const fetcher = useFetcher();
  const [optimistic, setOptimistic] = useState(favorited);
  return (
    <fetcher.Form
      method="post"
      onSubmit={() => setOptimistic((v) => !v)}
    >
      <input type="hidden" name="favorited" value={String(!optimistic)} />
      <button aria-pressed={optimistic}>Favorite</button>
    </fetcher.Form>
  );
}
```

**Why bad:** Two sources of truth. On an action error, `fetcher.data`
returns the failure but local state still shows the optimistic flipped
value. The button is now lying about the server's state. The user
clicks again, the state mismatches further, debugging gets ugly.

**Fix:** Read directly from `fetcher.formData` each render. It is
populated synchronously on submit and cleared automatically when
`fetcher.state === "idle"`.

```tsx
function FavoriteButton({ id, favorited }: { id: string; favorited: boolean }) {
  const fetcher = useFetcher();
  const pendingFavorited = fetcher.formData
    ? fetcher.formData.get("favorited") === "true"
    : favorited;
  return (
    <fetcher.Form method="post" action={`/items/${id}/favorite`}>
      <input type="hidden" name="favorited" value={String(!pendingFavorited)} />
      <button aria-pressed={pendingFavorited}>Favorite</button>
    </fetcher.Form>
  );
}
```

The same rule applies to `navigation.formData` for `<Form>` submissions.

**Exemptions — do NOT flag:**

- A genuine local UI state that does not represent the in-flight
  submission (e.g. a modal-open flag).
- A debounced text input where local state is the controlled value and
  only the submitted version flows through `fetcher.formData`.

## Verification before reporting

1. For an unbounded-upload finding, confirm the `unstable_create*`
   handler is invoked without `maxPartSize` (or with a suspiciously
   high cap) on a route reachable by unauthenticated users.
2. For a missing `encType` finding, confirm at least one
   `<input type="file">` is rendered inside the same `<Form>` and the
   method is POST.
3. For a FormData-validation finding, confirm there is no wrapper /
   schema helper called before the DB write. Grep for Zod / Valibot /
   `parseForm` first.
4. For a mirrored-optimistic-state finding, confirm the local state
   actually shadows what `fetcher.formData` already exposes — a local
   "is-editing" flag is not the same bug.
