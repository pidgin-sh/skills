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

## About plans

Pidgin has two tiers. The **free** tier accepts **HTML uploads only** and its files expire 30 days after the last upload, with a 5 GB monthly bandwidth cap. The **paid** tier ($5/mo or $50/yr) accepts any file type, has no expiry, and no bandwidth cap. The user can upgrade at https://pidgin.sh/dashboard/billing.

If the user is on free and asks you to share a non-HTML artifact (PNG, PDF, plot, etc.), check their plan first via the preflight below — don't waste a request.

### Plan preflight (non-HTML uploads only)

For HTML uploads, skip this — they always succeed regardless of plan.

For non-HTML uploads, before the POST/PUT:

```bash
ME=$(curl -sS https://api.pidgin.sh/v1/me -H "Authorization: Bearer $PIDGIN_API_KEY")
ALLOW_NON_HTML=$(echo "$ME" | jq -r '.plan.allow_non_html')
```

If `$ALLOW_NON_HTML` is `false`, stop and tell the user:

> This file type ({content_type}) requires a paid pidgin plan. Free accepts HTML only.
> Upgrade at https://pidgin.sh/dashboard/billing, or convert the artifact to HTML.

Do not attempt the upload.

## Interactive responses (paid)

If the user wants the human to interact with an artifact and have you receive
the result programmatically (option pickers, forms, "review and approve" flows),
use the response-channel feature. Pidgin gives the served HTML a single JS
function — `window.pidgin.respond(payload)` — that POSTs a JSON payload back to
pidgin. You wait for that payload with a single blocking call.

This is **paid only**. Free users get 402 with `error: "channel_not_allowed"`.

### Plan preflight (response channels)

Before uploading with `--respond`, check `plan.allow_response_channel`:

```bash
ME=$(curl -sS https://api.pidgin.sh/v1/me -H "Authorization: Bearer $PIDGIN_API_KEY")
ALLOW_CH=$(echo "$ME" | jq -r '.plan.allow_response_channel')
```

If `$ALLOW_CH` is `false`, stop and tell the user:

> Interactive response channels require a paid pidgin plan. Upgrade at https://pidgin.sh/dashboard/billing.

### Upload with a channel

Add the `X-Pidgin-Channel: respond` header to a normal upload. The response gains a `channel` block:

```bash
curl -sS -X POST https://api.pidgin.sh/v1/items \
  -H "Authorization: Bearer $PIDGIN_API_KEY" \
  -H "X-Filename: ask.html" \
  -H "Content-Type: text/html" \
  -H "X-Pidgin-Channel: respond" \
  --data-binary @./ask.html
# → { "id":"itm_…", "url":"…", "version":1, "channel": { "handle":"ch_…", "expires_at":… }, ... }
```

Print the `url` to the user. Remember the `channel.handle`.

### Wait for the response

```bash
# Long-poll. Loop until status is non-open or you give up.
while :; do
  RES=$(curl -sS -w "\n%{http_code}" "https://api.pidgin.sh/v1/channels/$HANDLE/wait" \
    -H "Authorization: Bearer $PIDGIN_API_KEY")
  CODE=$(echo "$RES" | tail -n1)
  BODY=$(echo "$RES" | sed '$d')
  if [ "$CODE" = "204" ]; then continue; fi
  if [ "$CODE" = "200" ]; then echo "$BODY"; break; fi
  echo "$BODY"; exit 1
done
```

The `200` body is one of:

```json
{ "status": "responded", "payload": <agent-defined JSON>, "responded_at": 1714991900 }
{ "status": "timed_out" }
{ "status": "superseded" }
{ "status": "abandoned" }
```

Branch on `status`. On `responded`, act on `payload`. On any other status, tell
the user the question is no longer waiting and stop.

### What the served HTML looks like

The artifact's HTML calls `window.pidgin.respond(payload)`. This is a non-normative example — adapt as needed:

```html
<!doctype html>
<html>
<head><title>Pick one</title></head>
<body>
<h1>Which design works best?</h1>
<button onclick="pick('A')">A: Minimalist</button>
<button onclick="pick('B')">B: Bold</button>
<button onclick="pick('C')">C: Classic</button>
<div id="status"></div>
<script>
async function pick(choice) {
  const result = await window.pidgin.respond({ choice });
  document.getElementById('status').textContent =
    result.ok ? 'Got it. Switch back to your terminal.' : 'This question is no longer waiting.';
}
</script>
</body>
</html>
```

**Important: include an explicit `<body>` tag.** HTML5 lets you omit it (browsers infer one), but pidgin's CDN injects the `window.pidgin.respond` shim by matching the literal `<body>` element in the source. Without it, `window.pidgin` is undefined at runtime and your buttons throw. The same applies to free-tier banner injection — always wrap your content in `<body>...</body>`.

You own all visuals — pidgin only provides `window.pidgin.respond`.

### Abandoning a wait

If you give up before the user answers:

```bash
curl -sS -X POST "https://api.pidgin.sh/v1/channels/$HANDLE/abandon" \
  -H "Authorization: Bearer $PIDGIN_API_KEY"
```

The user's tab will see "no longer waiting" on submit. Idempotent — safe to call once on cancellation.

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

| extension | content-type | tier |
|-----------|--------------|------|
| `.html`, `.htm` | `text/html` | free + paid |
| `.png` | `image/png` | paid only |
| `.jpg`, `.jpeg` | `image/jpeg` | paid only |
| `.gif` | `image/gif` | paid only |
| `.webp` | `image/webp` | paid only |
| `.svg` | `image/svg+xml` | paid only |
| `.pdf` | `application/pdf` | paid only |
| `.json` | `application/json` | paid only |
| `.txt`, `.log` | `text/plain` | paid only |
| `.md` | `text/markdown` | paid only |
| `.csv` | `text/csv` | paid only |

**When generating HTML, always wrap your content in an explicit `<body>...</body>`.** HTML5 lets you omit the body tag and most browsers infer one, but pidgin's CDN injects content (free-tier banner, paid-tier response-channel shim) by matching the literal `<body>` element in the source. Without it, the injection silently no-ops and any `window.pidgin.respond()` calls fail.

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
- **402** — two cases, distinguished by `error`:
  - `storage_quota_exceeded` — storage quota exceeded. Tell the user the message verbatim; they can free space by deleting older items.
  - `channel_not_allowed` — interactive response channels require paid. Surface the message verbatim.
- **411** — `Content-Length` header missing. This shouldn't happen with `curl --data-binary @<path>`; if it does, the file is unreadable.
- **413** — file too big for the user's plan. Message includes the byte cap.
- **409** — when deleting a single version of an item with only one version. Use `DELETE /v1/items/<id>` instead.
- **415** — file type not allowed by your plan. Free accepts HTML only. Surface the `message` verbatim — it includes the upgrade URL.
- **404** — wrong item id, or the item belongs to a different user.
- **410** (with `error: channel_closed`, `reason`) — channel is no longer open; check `reason` (`responded`, `timed_out`, `superseded`, `abandoned`).
- **403** (on `/respond`) — origin does not match the artifact's subdomain. Should not happen if the artifact is using the injected `window.pidgin.respond`.

When invoked, do the smallest thing the user asked for — one upload, one update, one list — and stop. Don't proactively delete or list unless asked.
