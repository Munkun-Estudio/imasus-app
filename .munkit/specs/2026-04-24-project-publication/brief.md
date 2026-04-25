# Spec 12 — Project Publication

## What

The publication phase of a project: a multi-step wizard that guides participants
through reflecting on their work, then produces a Behance-style public case
study page reachable by anyone without a login.

This spec also ships two related IA fixes agreed during the spec 11 → 12
transition:

1. **Projects on the workshop show page** — all projects in a workshop are
   listed there, with the current participant's own project visually
   distinguished. Projects are no longer found only by knowing the URL.
2. **`/projects` index decommissioned for participants** — the index becomes an
   admin/facilitator tool with no nav entry; participants discover projects via
   the workshop page and (once spec 7 lands) via Home.

## Why

The process log (spec 11) gives participants a place to document work in
progress. Publication turns that work into a portfolio piece — a public case
study that outlives the workshop and can be shared with anyone. It is the
natural culmination of the participant journey and the primary output the
IMASUS project uses to show impact.

The workshop-projects fix removes a real navigation gap: after spec 11
participants had no visible path back to their project. The workshop page is the
right contextual container because projects belong to a workshop and participants
already orient around it.

## Scope

### Model changes: `Project`

- `status` already exists with value `draft`; add `published` as a valid value.
- Add `publication_updated_at` — timestamp, set every time the public page
  fields are saved (first publish and any subsequent re-save). Displayed on the
  public page as "last updated".
- Add `slug` — string, unique, generated from `title` on first publish
  (parameterized, collision-resolved with `-2`, `-3` suffix). Null until
  published; immutable once set. Unique index scoped to non-null values:
  `WHERE slug IS NOT NULL`.
- Add public-page content fields (optional in draft, required on publish):
  - `hero_image` — `has_one_attached :hero_image` (Active Storage; image only;
    max 20 MB). Croppable via the `croppable` gem — participants define a crop
    region before the image is stored as a variant.
  - `process_summary` — `has_rich_text :process_summary` (Action Text / Trix).
    Single rich text body. The wizard pre-populates it with H2-headed sections
    (Problem / Process / Insights / Outcome) and any selected log content;
    participants edit freely in the composition step.
- Publish validation: `hero_image` and `process_summary` must be present before
  status can move to `published`. Conditional on `status == 'published'` so
  draft saves continue to work without them.
- `published?` convenience predicate: `status == 'published'`.
- `Project#publishable_by?(user)` — true when user is a member or admin, and
  project is draft.
- `Project#republishable_by?(user)` — true when user is a member or admin, and
  project is published.
- Slug generation: private model method, called from `before_validation` on
  publish transition. `title.parameterize`, uniqueness-checked, `-2`/`-3`
  suffix on collision, max 100 characters. Generated once; never regenerated.

### Routes

```ruby
# Authenticated: publication wizard (members only)
resources :projects do
  resource :publication, only: [:new, :create, :edit, :update],
                         controller: "project_publications"
end

# Public: published project page (no auth)
resources :published_projects,
          only: [:show],
          path: "published",
          param: :slug
```

- `GET  /projects/:id/publication/new`   — start wizard (draft projects only)
- `POST /projects/:id/publication`       — submit final step, attempt publish
- `GET  /projects/:id/publication/edit`  — re-enter wizard on a published project
- `PATCH /projects/:id/publication`      — re-save public page fields
- `GET  /published/:slug`               — public project page (no auth)

### Publication wizard (`ProjectPublicationsController`)

A five-step flow followed by a composition step. Steps are rendered as a single
multi-section form with progress indication, or as sequential pages — decide
during implementation based on Turbo frame feasibility. The key constraint is
that log entry selection (steps 3–5) must show the participant's actual log
entries alongside the text prompt.

**Step 1 — Welcome / workflow**
Friendly framing: "Let's turn your process into a public project." Brief
explanation of what publication means (public URL, portfolio piece) and how the
flow works before participants start: reflect on prompts, reuse process-log
evidence, then edit the final story in one composition editor. If the project has
log entries, show how many are available to reuse; if not, explain that the
participant can still publish from their answers or go back and add log entries
first. CTA to begin.

**Step 2 — Problem**
Prompt: "Your team selected [Challenge name]. After working on it, how would
you describe the problem in your own words?"
Text area (plain text or simple rich text). Pre-fills `## Problem` section in
`process_summary`.

**Step 3 — Process**
Prompt: "These are the notes and images you logged during the workshop. How
would you describe the steps you took?" 
Alongside the text area, participants see their log entries (body excerpt +
thumbnails) and can select entries or individual media to embed. Selected items
will appear as Trix attachment blocks in the `## Process` section of
`process_summary`. Hint: "You can edit and reorder these in the next step."

**Step 4 — Insights**
Prompt: "What did you discover or learn? What surprised you?"
Same pattern: text area + log entry/media picker. Pre-fills `## Insights`
section.

**Step 5 — Outcome**
Prompt: "What did you produce, propose, or prototype?"
Same pattern: text area + log entry/media picker. Pre-fills `## Outcome`
section.

**Composition step**
A full Trix editor pre-populated with the assembled `process_summary` (H2
sections + participant text + embedded log blocks). Participants can edit,
expand, trim, and reorder content freely. Above the editor: hero image upload
with crop affordance. Below: submit button ("Publish your work").

On final submit (`POST`):
- Validates `hero_image` attached and `process_summary` present.
- Sets `status: 'published'`, `publication_updated_at: Time.current`, generates
  slug (if nil), saves.
- On success: redirect to `GET /published/:slug` with a localised flash.
- On validation failure: re-render composition step with inline errors (422).

`edit`/`update` skip slug generation, update `publication_updated_at` on every
save, do not reset it to nil.

### Published project page (`PublishedProjectsController#show`)

- No auth required. Uses the standard application layout (sidebar intact —
  Materials, Training, Challenges, and Glossary are public resources and remain
  accessible to visitors).
- URL: `GET /published/:slug`.
- Content order:
  1. Hero image (full-width, aspect-ratio constrained).
  2. Project title + workshop name + challenge badge (if linked) + team member
     names + "Last updated [date]".
  3. Process summary (rendered Action Text, with embedded log blocks).
- Logged-in members and admins see a discreet "Edit publication" link near the
  title; no one else does.
- `404` on unknown slug or draft project.

### Workshop show page — projects section

`GET /workshops/:slug` gains a **Projects** section below the workshop
description and above the agenda link.

- Query: `Project.where(workshop:).includes(:members, :memberships, :challenge).order(created_at: :desc)`.
- Each project card: title, member initials avatars, challenge badge (if
  linked), status chip (`Draft` / `Published`).
  - Published project → card links to `published_projects_path(slug:)`.
  - Draft project → card links to `project_path(id)` for members and admins;
    visible but not linked for non-member workshop participants and facilitators.
- The current participant's project card is visually distinguished (accent
  border or "Your project" badge).
- Empty state: workshop participants see a "No projects yet" message with a
  "Start a project" CTA; facilitators and admins see a plain message.
- "Start a project" button relocates into the projects section header, replacing
  its former standalone position on the page.
- Non-member workshop participants can see all project cards but cannot open
  draft projects (redirected if they navigate directly to `/projects/:id`).

### `/projects` index — admin/facilitator only

- Participants redirected to their workshop page with a localised notice.
- No nav entry, no sidebar link, no dropdown.
- Admin sees all projects; facilitator sees all projects (per-workshop scope
  deferred to spec 13).

### I18n

- All wizard step copy, labels, prompts, flash messages, and public page chrome
  through `t(...)`. English filled; `es`, `it`, `el` stubbed.
- Wizard prompt copy (challenge name, step headings) localised. Authored content
  (`process_summary`) rendered as stored.

### Authorization

| Action | Who |
|--------|-----|
| `publication#new` / `#create` | Members and admins; project must be draft |
| `publication#edit` / `#update` | Members and admins; project must be published |
| `published_projects#show` | Anyone |
| Workshop projects section | Any authenticated user with workshop access |
| `/projects` index | Admin and facilitator only |

## Out of Scope

- Block-based page builder with drag-and-drop section reordering (deferred;
  the single Trix body is the MVP; sections are implicit H2 headings).
- Unpublishing / reverting to draft.
- Trix toolbar embeds of materials or training references (deferred to spec 13).
- Comments, reactions, or social sharing widgets on the public page.
- SEO metadata and Open Graph tags.
- Per-workshop facilitator scoping on `/projects` index (deferred to spec 13).
- Non-member participants reading draft project show pages (they see cards in
  the workshop; opening a draft they don't belong to is out of scope).

## Acceptance Criteria

- [ ] A project member can open the publication wizard from the project show
      page when the project is in `draft` status.
- [ ] The wizard presents five steps (Welcome, Problem, Process, Insights,
      Outcome) followed by a composition step with a pre-populated Trix editor.
- [ ] Steps 3–5 show the project's log entries and allow selecting entries or
      media to embed in `process_summary`.
- [ ] The composition step shows the hero image upload with a crop affordance
      (croppable gem) and the assembled Trix editor.
- [ ] Submitting the composition step with `hero_image` and `process_summary`
      present moves the project to `published`, generates a slug, sets
      `publication_updated_at`, and redirects to the public page.
- [ ] Submitting without required fields re-renders the composition step with
      inline errors; no status change occurs.
- [ ] The public page at `/published/:slug` renders without login, showing the
      hero image, project metadata, and `process_summary`.
- [ ] The public page displays "Last updated [date]" using `publication_updated_at`.
- [ ] A logged-in member or admin sees an "Edit publication" link on the public
      page.
- [ ] Editing a published project updates `process_summary`, `hero_image`, and
      `publication_updated_at` without regenerating the slug.
- [ ] The workshop show page lists all projects in that workshop, newest first.
- [ ] A participant's own project is visually distinguished in the workshop list.
- [ ] A published project shows a "Published" chip and links to the public page.
- [ ] A draft project card is visible to all workshop participants but only
      linked for members and admins.
- [ ] Empty state on the workshop projects section shows a "Start a project" CTA
      for workshop participants and a plain message for facilitators.
- [ ] `GET /projects` redirects participants with a localised notice; admin and
      facilitator can reach it.
- [ ] `GET /published/:unknown-slug` returns 404.
- [ ] `GET /published/:slug` for a draft project returns 404.
- [ ] All UI strings present in en, es, it, and el.

## Dependencies

- Spec 3 (`image-hosting-strategy`) — Active Storage / S3 for `hero_image`.
- Spec 10 (`projects-and-teams`) — `Project`, `ProjectMembership`,
  `editable_by?`, `visible_to?`.
- Spec 11 (`process-log`) — `LogEntry` records shown in wizard steps 3–5;
  cascade destroy already specced.

Downstream:

- Spec 7 (`home-page`) — participant dashboard can rely on `project.published?`
  and `project.slug`.
- Spec 13 (`facilitator-tools`) — Trix toolbar embeds for materials/training
  in `process_summary`; facilitator moderation.
- Spec 14 (`workshops-public-listing`) — public workshop page links to published
  projects via `published_projects_path(slug:)`.
