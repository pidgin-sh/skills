---
name: pidgin-share
description: Use when the user asks to share an artifact (HTML, image, PDF, plot, report) by URL. Uploads the file to pidgin and returns a public unlisted URL on <subdomain>.pidgin.sh.
---

# pidgin-share

Use this when the user asks you to share an artifact — an HTML page, image, PDF, plot, report, anything renderable — and you have a local file. You upload the file to pidgin's API; pidgin returns a public unlisted URL on `<subdomain>.pidgin.sh`. Hand the URL back. The URL is unlisted (URL contains a random privacy token), so knowing the subdomain alone reveals nothing.

## Prerequisites

The user must have an API key. Read it from `$PIDGIN_API_KEY`.

If `$PIDGIN_API_KEY` is unset, stop and tell the user:

> No `PIDGIN_API_KEY` set. Create a key at https://pidgin.sh/dashboard/keys, then run `export PIDGIN_API_KEY=pdg_…` in your shell and try again.

Do not proceed without a key.

## Upload a new artifact

```bash
curl -sS -X POST https://api.pidgin.sh/v1/items \
  -H "Authorization: Bearer $PIDGIN_API_KEY" \
  -H "X-Filename: <basename>" \
  -H "Content-Type: <mime-type>" \
  --data-binary @<path>
```

`<basename>` is the filename only (e.g. `report.html`, not `/tmp/report.html`).
`<mime-type>` MUST match the file — this is what makes the URL render in a browser instead of downloading. Pick from this table; fall back to `application/octet-stream` for unknown extensions:

| extension | content-type |
|-----------|--------------|
| `.html`, `.htm` | `text/html` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.webp` | `image/webp` |
| `.svg` | `image/svg+xml` |
| `.pdf` | `application/pdf` |
| `.json` | `application/json` |
| `.txt`, `.log` | `text/plain` |
| `.md` | `text/markdown` |
| `.csv` | `text/csv` |

The response on success is HTTP 201 with JSON like:

```json
{ "id": "itm_…", "url": "https://<sub>.pidgin.sh/<random6>/<filename>", "version": 1, "size_bytes": 1234, "content_type": "text/html" }
```

Print **only** the `url` value to the user. Remember the `id` — you'll need it if the user asks you to update or delete the same artifact later in this conversation.

## Update an existing artifact (new version, same URL)

When the user wants to revise something you already uploaded in this session, reuse the `id` you saved:

```bash
curl -sS -X PUT https://api.pidgin.sh/v1/items/<id> \
  -H "Authorization: Bearer $PIDGIN_API_KEY" \
  -H "X-Filename: <basename>" \
  -H "Content-Type: <mime-type>" \
  --data-binary @<path>
```

Same body shape. The response includes `version: 2` (or 3, 4, …). The `url` field is unchanged — share that. Old versions stay reachable at `<url-without-filename>/v<N>/<filename>` (build the versioned URL yourself if the user asks for one — pidgin does not return it).

## List recent artifacts

If the user asks "what have I uploaded?" or "find the X I shared earlier":

```bash
curl -sS https://api.pidgin.sh/v1/items?limit=20 \
  -H "Authorization: Bearer $PIDGIN_API_KEY"
```

Returns `{ "items": [...], "next_cursor": "…" | null }`. Each item includes `id`, `url`, `current_filename`, `size_bytes`, `created_at`, `updated_at`. Show the user a compact summary (filename + url), not the raw JSON.

## Delete an artifact

Whole item (all versions):

```bash
curl -sS -X DELETE https://api.pidgin.sh/v1/items/<id> \
  -H "Authorization: Bearer $PIDGIN_API_KEY"
```

Single version (item must have at least 2 versions — pidgin returns 409 if it's the last one):

```bash
curl -sS -X DELETE https://api.pidgin.sh/v1/items/<id>/versions/<n> \
  -H "Authorization: Bearer $PIDGIN_API_KEY"
```

Both return HTTP 204 (empty body) on success. Confirm the deletion to the user with one short sentence.

## Errors

On any non-2xx response the body is JSON of the form `{ "error": "<code>", "message": "<human readable>" }`. Surface the `message` to the user verbatim. Do not paraphrase, do not retry. Common cases:

- **401** — `PIDGIN_API_KEY` is missing, expired, or revoked. Tell the user to recreate one at https://pidgin.sh/dashboard/keys.
- **402** — storage quota exceeded. Tell the user the message verbatim; they can free space by deleting older items.
- **411** — `Content-Length` header missing. This shouldn't happen with `curl --data-binary @<path>`; if it does, the file is unreadable.
- **413** — file too big for the user's plan. Message includes the byte cap.
- **409** — when deleting a single version of an item with only one version. Use `DELETE /v1/items/<id>` instead.
- **404** — wrong item id, or the item belongs to a different user.

When invoked, do the smallest thing the user asked for — one upload, one update, one list — and stop. Don't proactively delete or list unless asked.
