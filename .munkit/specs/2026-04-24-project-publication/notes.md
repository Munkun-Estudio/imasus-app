# Notes: 2026-04-24-project-publication

Scratch space for working through this spec. See brief.md for requirements.

---

## Context carried in from spec 11 → 12 discussion

- **Navigation gap confirmed:** after spec 11 there was no visible path back to a
  project for a participant. Workshop page chosen as the right contextual
  container; Home (spec 7) will reinforce this later.
- **`/projects` index:** survives as admin/facilitator-only. No nav entry for
  participants. IA decision recorded in DECISIONS.md (2026-04-24).
- **All projects visible in workshop:** consistent with context.md — within a
  workshop, all participants see all projects. Own project highlighted.
- **Non-member participants see draft cards but cannot open them.** `visible_to?`
  from spec 10 only covers members, facilitators, and admins. Non-member
  participants are explicitly out of scope for draft read access in this spec.

## Resolved during spec scoping

- **Single Trix body, not separate columns.** `problem_statement`, `key_insights`,
  and `outcome` are wizard prompts only — not stored fields. All narrative content
  lives in `process_summary` (Action Text), pre-populated with H2 sections.
  A structured block builder is deferred.
- **`published_at` replaced by `publication_updated_at`.** Updated on every
  publication save (first publish and re-saves). Displayed as "Last updated" on
  the public page. Rationale: visitors care when the page was last updated, not
  when it was first made public.
- **Sidebar stays on public page.** Materials, Training, Challenges, and Glossary
  are public resources — suppressing the sidebar would actively harm visitors.
- **Croppable gem for hero image.** Participants define a crop region before the
  image is stored as a variant. Avoids the "upload anything and hope" problem for
  a fixed-aspect-ratio hero.
- **Admin included in `publishable_by?` / `republishable_by?`.** Admins may need
  to publish or update a publication for support/moderation reasons.
- **Route path fix (Codex review):** `path: "published"` added to the
  `published_projects` resource declaration to produce `GET /published/:slug`.
- **Partial unique index on slug:** `WHERE slug IS NOT NULL` — allows many null
  draft slugs; only enforces uniqueness once a slug is generated.
- **Log entry selection in wizard steps 3–5:** participants select whole entries
  (body excerpt + attached media); individual image/video picking within an entry
  is deferred.

## Open questions

- **Wizard as single page vs. sequential Turbo frames:** the brief leaves this to
  implementation. Single-page with JS show/hide is simpler; Turbo frames per step
  is more robust on slow connections. Recommend deciding based on whether log
  entry selection UX feels manageable in a single scroll.
- **Slug URL shape:** `/published/:slug` chosen (unambiguous, no route conflicts).
  Revisit only if participants find the URL unwieldy for sharing.

## Implementation notes

- `slug` migration: add `null: false` constraint after backfilling, or use a
  partial unique index `WHERE slug IS NOT NULL` and allow null on the column.
  Partial index is cleaner for the mixed draft/published lifecycle.
- Slug generation: private model method + `before_validation` on publish
  transition. `title.parameterize`, uniqueness check, `-2`/`-3` suffix, max 100
  chars. Generated once; never regenerated.
- Keep `PublishedProjectsController` entirely separate from `ProjectsController`
  — different auth semantics, different layout concerns.
- Eager-load `memberships`, `members`, and `challenge` in the workshop projects
  section to avoid N+1.
- `project.hero_image.attached?` guard before rendering in templates.
- Publish validation conditional on `status == 'published'` — draft saves must
  not require publication fields.
- `publication_updated_at` is set in the controller on every successful save of
  publication fields, not via a model callback, to keep intent explicit.
- `croppable` gem: check compatibility with Active Storage variants and
  mini_magick (the project's confirmed image processor). Verify before
  implementation begins.

## Design / UI think-through

- Wizard steps: progress bar or numbered step indicator (1 of 6) at the top.
  Each step should feel low-stakes — short prompt, enough space to write, log
  panel alongside for reference.
- Log entry picker (steps 3–5): card list with checkbox. Show entry date, author
  initials, body excerpt, and a thumbnail strip if media is attached. Keep it
  scannable.
- Composition step: two-column on desktop (hero image + crop tool on the left or
  top; Trix editor main area). Single column on mobile.
- "Your project" distinction in workshop cards: Mint accent border + small "Your
  project" badge. Avoid heavy banner that disrupts grid rhythm.
- Published chip: calm — Mint background, dark text. Draft chip: neutral grey.
- Public page: generous max-width centered layout. Hero image full-bleed at top.
  Metadata row (workshop, challenge, team, last updated) in muted type below
  title. Process summary rendered with standard Action Text styles.

## Testing notes

- **Model:** conditional validation — draft saves without publication fields pass;
  publish attempt without `hero_image` or `process_summary` fails with correct
  errors. Slug collision: publish two projects with identical titles, assert
  second gets `-2`. `publication_updated_at` set on create and update.
- **Controller (publication):** member reaches wizard on draft; redirected if
  project is already published (to edit path); non-member forbidden; facilitator
  forbidden; admin can reach both new and edit.
- **Controller (published_projects):** unknown slug → 404; draft project slug →
  404; published project → 200 without auth.
- **Workshop show:** projects section renders all workshop projects; own project
  card has distinguishing class/attribute; empty state renders correct CTA per
  role.
- **`/projects` redirect:** participant GET → redirect with notice; facilitator →
  200; admin → 200.

## Implementation resolved (2026-04-24)

- **Wizard simplified to single form for MVP.** The five-step wizard (Welcome →
  Problem → Process → Insights → Outcome) with log pickers is deferred. The
  published form goes straight to the Trix editor for `process_summary` plus
  a hero image upload. Prompt copy in the form heading and hint text sets
  context. The wizard flow is a follow-on when the builder UX is revisited.
- **`croppable` gem deferred.** Compatibility with mini_magick needs verification
  before adding. TODO comment placed in the hero image section of `_form.html.erb`.
  Hero image is a plain file upload for now.
- **Log picker not implemented.** Steps 3–5 of the wizard (select log entries/
  media to embed) are deferred along with the wizard itself.
- **`process_summary` strong params.** Permitted via `params.require(:project).permit(:hero_image, :process_summary)` — Rails 6+ handles Action Text field names directly.
- **`PublishedProjectsController` skips `require_login`.** Uses
  `Project.where(status: "published").find_by!(slug:)` — draft/unknown slugs
  raise `RecordNotFound` which ApplicationController turns into a 404.
- **`@user_project_ids` in workshop show.** Used by the `_projects` partial to
  detect the current user's own project without per-card queries.
- **`publish` status valid in existing test.** The old test "only draft is a
  valid status for now" was updated to reflect that `published` is now valid.

## Downstream reminders

- Spec 7 (Home) can rely on `project.published?` and `project.slug` being stable.
- Spec 13 (facilitator tools): Trix toolbar embeds for materials/training in
  `process_summary` — keep the Action Text field plain for now.
- Spec 13: tighten `visible_to?` for per-workshop facilitator scoping.
- Spec 14 (public workshop listing): links to published projects via
  `published_projects_path(slug:)`.
- If the block builder is revisited later, the H2-section structure in
  `process_summary` provides a natural migration path to discrete blocks.
