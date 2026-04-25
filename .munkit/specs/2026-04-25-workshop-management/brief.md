# Spec — Workshop Management

## What

Three small but related changes that round out the workshop entity's
edit surface and lifecycle:

1. **Drop `workshop.partner`** — single-string field that misrepresents
   multi-partner workshops; description copy already covers this.
2. **Inline agenda editing** — fold the per-locale Trix agenda into the
   existing workshop edit form so facilitators see one "Edit workshop"
   form rather than discovering a second hidden surface.
3. **Workshop creation by admins and facilitators** — add
   `workshops#new, #create` plus a "New workshop" CTA on the
   `/workshops` index. The creator is auto-attached as a workshop
   facilitator on save so they can manage the workshop they just
   created.

A small visual polish on the show-page button row rides along since the
new edit form keeps that surface coherent.

This spec is **not** in the original 1–14 plan in `context.md` — it's a
follow-up that grew out of facilitator-tools (spec 13) and the
workshop-agenda-edit deferral. Refer to it by slug
(`workshop-management`).

## Why

After spec 13, facilitators can edit a workshop, list its participants,
and moderate projects. Two gaps remained:

- **Agenda editing** had been deferred to a future
  `workshop-agenda-edit` spec on the assumption it deserved its own
  page. UX testing reframed that — facilitators don't know the
  storage split between metadata (JSONB-translated) and agenda
  (Action Text per-locale) exists, and adding a second "Edit agenda"
  button on top of the already-crowded show page increases cognitive
  load for no UX benefit. Folding the agenda into the existing
  workshop edit form (one form, one button, three fields per locale
  tab — title, description, agenda) hides the implementation split
  from the user.
- **Workshop creation** had no UI. Workshops were seed-only. Adding
  new workshops (e.g. for new partner regions) required a developer.
  Allowing facilitators (and admins) to create workshops directly
  unblocks the team and matches the operational reality where
  country-team facilitators are the ones standing up new workshops.

The `partner` field removal is opportunistic — we're touching the edit
form, the schema concern is tiny, and the field has been actively
misleading on the show page.

## Scope

### Schema change: drop `workshop.partner`

- Reversible migration: `remove_column :workshops, :partner, :string`.
- Removes the `validates :partner, presence: true` clause from
  `Workshop`.
- `Workshop.ready_for_listing` scope drops the `where.not(partner: nil)`
  clause. Newly-created workshops with a translated title +
  description and dates appear publicly without a partner gate.
- Seeds (`db/seeds/workshops.yml`) drop the `partner: …` keys; the
  loader (`Workshop.seed_from_yaml!`) drops the `partner` assignment.
- All views drop the partner badge / partner field /
  `t(...partner_with...)` interpolation. The footer's project-level
  partners list (already in `_footer.html.erb`) is unaffected.
- I18n cleanup: drop unused `*.partner` and `*.partner_with` keys from
  `en/es/it/el`.

### Workshop edit form — agenda fields per locale

The existing `workshops/edit.html.erb` translated section adds an
**agenda** field on each locale tab, alongside `title` and
`description`. Implementation:

- Trix editor per locale: `f.rich_text_area :"agenda_#{locale}"` (or
  the equivalent `text_area_tag` form helper that pairs with
  `has_rich_text :agenda_<locale>`).
- The locale-tabs widget (one tab per locale, current locale first,
  then `en → es → it → el`) becomes the single home for all
  locale-keyed fields. Each tab shows title + description + agenda
  for that locale.
- `workshop_params` permits the four agenda associations through
  Action Text's standard nested behaviour
  (`agenda_en, agenda_es, agenda_it, agenda_el`).
- The standalone read-only `/workshops/:slug/agenda` page is
  unchanged. The edit affordance is reachable only from the workshop
  show page (existing "Edit workshop" link); no separate
  "Edit agenda" button anywhere.

### Workshop creation

- Routes: `resources :workshops, only: [ :index, :show, :new, :create, :edit, :update ], param: :slug`.
- Authorisation: a new helper `Workshop.creatable_by?(user)` returning
  `true` when `user.admin? || user.facilitator?`. Wired into a
  `before_action :require_workshop_creator` on
  `WorkshopsController#new, #create`.
- Form: same locale-tabs structure as the edit form (title /
  description / agenda per locale, then details, then contact). Slug
  is **not** displayed on the form.
- Slug generation:
  - On create, derive from the *title* in the first non-blank locale
    (preference order: `en → es → it → el`).
  - `title.parameterize`, max 100 chars.
  - Collision-resolved with `-2`, `-3` suffix.
  - Implemented as a private model method called from
    `before_validation :assign_slug, if: -> { slug.blank? }`.
- Creation transaction: `Workshop.create!` followed by
  `WorkshopParticipation.create!(user: current_user, workshop: @workshop)`
  inside `Workshop.transaction { ... }`. Both rollback together.
- Success redirects to the new workshop's show page with a localised
  flash. Failure re-renders `:new` with `status: :unprocessable_content`.
- The auto-attached `WorkshopParticipation` is created for **any**
  creator role — admins and facilitators alike. Admins benefit from
  it in display (the workshop appears in their facilitator-style
  surfaces) without any extra logic. The participant-count helper
  (spec 13) already filters by role, so admin attachment doesn't
  inflate participant counts.

### "New workshop" CTA on `/workshops` index

- Visible to `current_user&.admin? || current_user&.facilitator?` only.
- Position: top-right of the page heading area.
- Routes to `new_workshop_path`.

### Workshop show — small visual polish

The current row of three buttons ("Invitar participantes",
"Editar taller", "Participantes") is functional but visually flat.
Re-group into a tighter cluster:

- Primary action: "Editar taller" (visible to managers).
- Secondary group: "Participantes" + "Invitar participantes" (both
  visible to managers).
- Visual hierarchy: subtle border or muted background distinguishing
  the primary from the secondaries. No new buttons. No new actions.

This is intentionally a lightweight visual pass — the page's
information architecture stays the same.

### I18n

- All new strings (creation form labels, "New workshop" CTA, agenda
  field label, success / failure flashes) added to the four locale
  files.
- English fully filled. Spanish translated where copy is short.
  Italian and Greek carry English placeholders for longer copy plus
  translated short labels, marked with `# TODO: translate (workshop-management)`.
- Existing partner-related strings removed from all four locales.

### Authorisation summary

| Action                              | Allowed when                                       |
|-------------------------------------|-----------------------------------------------------|
| `workshops#new`, `#create`          | `current_user.admin? || current_user.facilitator?` |
| `workshops#edit`, `#update`         | `workshop.manageable_by?(current_user)` (unchanged) |
| Show "New workshop" CTA on `/workshops` | Same as `workshops#new`                       |

## Out of Scope

- **Workshop destroy** — cascades to projects, log entries,
  participations. Real schema-cascade discussion needed; defer.
- **Workshop slug renames after create** — slug is immutable for the
  same reason `Project#slug` is.
- **Draft / published workshop state** — facilitators fill the form
  and submit once. A workshop with translated title + description +
  dates is publicly visible immediately.
- **Workshop creation by participants** — out of scope by design.
- **Agenda revision history** — single mutable Action Text body per
  locale.
- **`Workshop#manageable_by?` for facilitators not in the workshop** —
  unchanged from spec 13. Only the workshop's own facilitators (and
  admins) can edit / moderate; creators are auto-attached so they
  qualify immediately.
- **Activity feed, Trix material/training embeds** — still their own
  follow-up specs.

## Acceptance Criteria

### Drop `partner`

- [ ] Migration removes the column reversibly.
- [ ] `validates :partner, presence: true` no longer present in
      `Workshop`.
- [ ] `Workshop.ready_for_listing` no longer references `partner`.
- [ ] All workshop views (`index`, `show`, `edit`, `_published_projects`)
      no longer render a partner badge or label.
- [ ] `db/seeds/workshops.yml` no longer carries `partner` keys, and
      `Workshop.seed_from_yaml!` no longer assigns `partner`.
- [ ] Locale files no longer contain unused `*.partner` /
      `*.partner_with` keys.
- [ ] `bin/rails test` and `bundle exec rubocop` are clean after the
      change.

### Inline agenda editing

- [ ] The workshop edit form's per-locale tabs each contain title,
      description, **and** agenda inputs.
- [ ] Submitting the form persists agenda content to the matching
      `agenda_<locale>` Action Text body.
- [ ] The standalone `/workshops/:slug/agenda` show page renders the
      newly-saved content for the right locale.
- [ ] Non-managers redirected from `/edit` (existing behaviour from
      spec 13) — agenda editing inherits the same gate.

### Workshop creation

- [ ] `GET /workshops/new` renders for an admin.
- [ ] `GET /workshops/new` renders for a facilitator regardless of
      whether they have any prior `WorkshopParticipation`.
- [ ] `GET /workshops/new` redirects participants and visitors with
      access-denied / login.
- [ ] `POST /workshops` with valid params persists the workshop and
      creates a `WorkshopParticipation` linking the creator. The
      creator can immediately reach `GET /workshops/:slug/edit`.
- [ ] Slug is auto-generated from the title (preferring the
      `en → es → it → el` order); a second workshop with the same
      title-derived slug gets a `-2` suffix; a third gets `-3`.
- [ ] Submitting without a translated title in any locale or without
      dates re-renders `:new` with 422 and inline errors.
- [ ] After successful create, the user is redirected to the new
      workshop's show page with a localised flash.

### `/workshops` index CTA

- [ ] Admin sees the "New workshop" CTA.
- [ ] Facilitator sees the "New workshop" CTA.
- [ ] Participant does not see the CTA.
- [ ] Visitor does not see the CTA.

### Show-page polish

- [ ] No new buttons added on the show page.
- [ ] Existing buttons re-grouped per the brief; visual hierarchy
      distinguishes primary (Edit) from secondaries (Participants /
      Invite).

### I18n

- [ ] All new copy through `t(...)` in en/es/it/el.

### Decisions

- [ ] `DECISIONS.md` records the rationale for dropping
      `workshop.partner` and for folding agenda editing into the
      existing workshop edit form.

## Dependencies

- Spec 9 (`workshops`) — `Workshop`, `WorkshopParticipation`,
  per-locale `has_rich_text :agenda_*`.
- Spec 12 (`project-publication`) — slug-with-suffix pattern reused
  for workshop slug generation.
- Spec 13 (`facilitator-tools`) — `Workshop#manageable_by?`,
  workshop edit form, "Edit workshop" affordance.

### Downstream

- **`activity-feed`** — still pending.
- **`trix-resource-embeds`** — still pending.
- **`workshop-agenda-edit`** — **superseded** by this spec. Drop the
  `<%# TODO(workshop-agenda-edit) %>` markers from the workshop edit
  form and the spec-13 notes when this lands.
