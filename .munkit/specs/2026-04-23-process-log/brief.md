# Spec 11 — Process Log

## What

A chronological log of entries belonging to a project. Participants add log entries during the workshop to document their process — what they tried, observed, discussed, or decided. Each entry has a rich-text body (Action Text / Trix) and can include one or more photo or video attachments uploaded by participants.

Log entries are the primary creative output during the workshop. They feed the published project page (spec 12).

## Why

Without a log, the Project is a shell: it has a title and a challenge but no content. The process log is the workshop's main digital activity — participants need a place to capture thinking-in-action as it happens. The log also provides the raw material for publication: participants will draw from entries when composing the public page.

## Scope

### Model: `LogEntry`

- `belongs_to :project`
- `belongs_to :author, class_name: "User"` — the member who created the entry; set at create time, never changed
- `has_rich_text :body` — Action Text body, required
- `has_many_attached :media` — photos/videos; optional; max 10 per entry, 50 MB per file
- `created_at` used as the displayed timestamp; no separate field
- Validations: `body` present; `author` and `project` present
- Author must be a current project member at create time (controller-level guard, not model)

### Routes

Nested under projects:

```ruby
resources :projects do
  resources :log_entries, only: [:index, :new, :create, :destroy]
end
```

No edit/update — entries are appended, not revised. The destroy action is available to the entry author or an admin.

### Views

**Log index (`projects/:id/log_entries`)**

- Linked from the project show page ("Process log" link/button)
- Reverse-chronological list of all entries (newest first)
- Each entry card: author avatar initials + name, relative timestamp, formatted rich-text body, attached media thumbnails
- Images: Active Storage variant thumbnail (click-to-expand not required for MVP)
- Videos: `<video controls>` element
- Empty state: friendly prompt with "Add first entry" CTA for members; plain message for facilitators
- "Add entry" button visible to project members only; hidden for facilitators and visitors

**New entry form (`projects/:id/log_entries/new`)**

- Trix editor for body (required)
- File upload field (multiple; accept image/jpeg, image/png, image/webp, video/mp4, video/quicktime)
- Submit + cancel back to log index

### Authorisation

| Action | Who |
|---|---|
| index | Anyone `visible_to?` the project (members, facilitators, admins) |
| new / create | Project members only (`editable_by?`) |
| destroy | Entry author OR admin |

### Media

- Active Storage backed (S3 in production; disk in dev/test)
- Image thumbnails via `image_tag` with an Active Storage variant (800×600, jpeg)
- Videos rendered as `<video controls>` — no transcoding for MVP
- File type and size validation in the model

## Out of Scope

- Material embed / training reference Trix toolbar buttons (deferred to spec 12 or a follow-on)
- Editing existing entries
- Reactions, comments, or threading
- Pagination (workshop scale makes this acceptable; add if needed)
- Real-time log updates via Turbo Streams — a page reload is fine for MVP

## Acceptance Criteria

- [ ] A project member can open the process log from the project show page.
- [ ] The log shows all entries in reverse-chronological order with author name, relative timestamp, and rich-text body.
- [ ] A project member can create a new entry with a rich-text body; on submit it appears at the top of the log.
- [ ] A member can attach up to 10 photos/videos to an entry; images render as thumbnails; videos render as `<video controls>`.
- [ ] A facilitator sees all entries but sees no "Add entry" affordance and cannot submit a new entry.
- [ ] A non-member, non-facilitator is redirected away from the log (access denied).
- [ ] An unauthenticated user is redirected to the login page.
- [ ] The entry author can delete their own entry; other members cannot; admins can delete any entry.
- [ ] Deleting a project cascades to its log entries.
- [ ] All UI strings are present in en, es, it, and el.

## Notes

- Depends on spec 3 (Active Storage / S3) and spec 10 (projects and teams).
- The `LogEntry` model should live at `app/models/log_entry.rb`; the controller at `app/controllers/log_entries_controller.rb`.
- `Project#editable_by?` and `Project#visible_to?` from spec 10 are the access-control primitives; reuse them without duplicating logic.
- Relative timestamps: use Rails `time_ago_in_words` helper wrapped in a `<time datetime="...">` element for accessibility.
- Spec 12 (project-publication) will embed a curated selection of log entries in the public page; keep `LogEntry` plain enough that it can be referenced without transformation.
