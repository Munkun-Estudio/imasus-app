# Notes: 2026-04-26-bookmarks

## Model design

Single `Bookmark` table — no polymorphic FK. Columns: `user_id`, `bookmarkable_type` (string), `resource_key` (string), `label`, `url`, `created_at`. Unique index on `[user_id, bookmarkable_type, resource_key]`.

`bookmarkable_type` values: `"Material"`, `"GlossaryTerm"`, `"TrainingModule"`, `"Challenge"` — plain strings, not tied to `model.class.name`.

`resource_key` semantics:
- AR-backed resources (Material, GlossaryTerm, Challenge): record ID as string, or `challenge.code` for challenges.
- TrainingModule anchors: composite `"#{slug}/#{section}/#{locale}/#{anchor_id}"` — the only stable identifier since training modules are filesystem POROs, not AR records.

## Training module anchor rendering

The renderer post-processing step (add sequential IDs to `<p>` tags, inject bookmark icon markup) should live in `TrainingModule::Renderer` or a dedicated `TrainingModule::BookmarkAnnotator` — decide at implementation time based on how large the change is.

Headings already carry Kramdown-generated IDs. Paragraphs need synthetic sequential IDs: `p-1`, `p-2`, etc.

## Turbo / JS approach

**No `<turbo-frame>` wrappers on training pages.** Turbo Streams target elements by `id` directly — no frame needed for a button swap. Each bookmark icon button gets a unique `id` (e.g. `bookmark-toggle-heading-introduction`, `bookmark-toggle-p-3`); the stream responds with `turbo_stream.replace` on that ID. Eliminates any frame-discovery overhead on long pages.

Challenge cards already use `turbo_frame_tag dom_id(challenge)` — that existing frame is the stream target for challenge bookmarks.

`bookmark_controller.js` (Stimulus): builds form data (type, resource_key, label, url) and submits. Flips icon state optimistically; Turbo Stream confirms or reverts. Keep it focused — no state management beyond the toggle.

## Challenges — no show page

Challenge cards have no show page. Stored URL anchors to the card: `challenges_path(anchor: challenge.code.downcase)`. Each `<article>` in `_card.html.erb` needs `id: challenge.code.downcase` added so the anchor resolves. Weaker recovery link than a dedicated page, but sufficient.

## Resolved decisions

- Anchor-level bookmarks are per-passage, not per-module page. Decided by user.
- Bookmarks entry point: User menu + Home page only. No sidebar nav entry — preserves identical-sidebar-for-all-roles rule.
- Auth: visitors cannot bookmark. Participants, Facilitators, Admins all can. No role gate beyond authentication.
