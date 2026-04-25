# Spec 13 — Facilitator Tools

## What

Operational tooling for facilitators (and admins) to run their workshops:
edit workshop metadata, view and remove workshop participants, soft-disable
misbehaving projects, and a per-workshop scope on the cross-cutting
`/projects` index. Adds the first real management surfaces beyond the thin
facilitator home variant shipped in spec 7.

## Why

After spec 12 (publishing) and spec 14 (public workshop listing), workshops
are real. Facilitators can invite participants, but they have no way to:

- Edit workshop metadata once it exists. Even `workshop.contact_email` (which
  spec 7 introduced and only seeds populate today) needs an editing surface
  so a workshop team can set their own contact address without a developer.
- Address moderation. The product context already names this responsibility
  (MEMORY.md: *"facilitators can moderate (disable participants or projects
  in case of conflict)."*) but the affordance does not exist.
- See their workshop's participants without scrolling the workshop show page
  cards.

Spec 13 closes those gaps with the smallest set of surfaces that match the
original plan entry — workshop edit, participant management, project
moderation, scoped projects index — and explicitly defers the bigger
deliverables that have piled up under the same name (activity feed, Trix
resource embeds) to follow-up specs.

## Scope

### Model changes: `Project` soft-disable

Reversible moderation flag.

- Migration adds two columns:
  - `disabled_at` — `datetime`, nullable. Set by `Project#disable!`.
  - `disabled_by_id` — `bigint`, nullable, foreign key to `users`. Records
    which staff member performed the action. Indexed.
- Active Record:
  - `belongs_to :disabled_by, class_name: "User", optional: true`.
  - `scope :active, -> { where(disabled_at: nil) }`.
  - `Project#disabled?` — `disabled_at.present?`.
  - `Project#disable!(by:)` — sets `disabled_at: Time.current` and
    `disabled_by: by`. Idempotent.
  - `Project#enable!` — clears both fields.
- Visibility / authorisation updates:
  - `editable_by?(user)` — additionally returns `false` when `disabled?`,
    even for members and admins. Re-enable first to edit.
  - `visible_to?(user)` — unchanged for admins and facilitators. For members,
    still true (read-only on the show page). For non-staff non-members,
    still false.
  - `publishable_by?` and `republishable_by?` — return `false` while
    disabled (because they call `editable_by?`).
- Public surfaces excluded from disabled projects:
  - Visitor home "Featured published projects" — query becomes
    `Project.active.published…`.
  - Public workshop listing (`/workshops/:slug` for visitors) — same scope.
  - `/published/:slug` — `Project.active.published.find_by!(…)` so a disabled
    published project returns 404 publicly.
- Authenticated workshop show page projects section: disabled drafts and
  publications still appear in the list **for members and staff**, marked
  with a "Disabled" chip; for other workshop participants, disabled
  projects are filtered out of the list.

### Routes

```ruby
resources :workshops, only: [ :index, :show, :edit, :update ], param: :slug do
  # existing nested member routes (agenda, invitations) stay
  resources :participants, only: [ :index, :destroy ],
            controller: "workshop_participants",
            param: :user_id
end

resources :projects do
  member do
    patch :disable
    patch :enable
  end
  # existing nested routes stay
end
```

- `GET  /workshops/:slug/edit`              — `workshops#edit`
- `PATCH /workshops/:slug`                   — `workshops#update`
- `GET  /workshops/:slug/participants`       — list
- `DELETE /workshops/:slug/participants/:user_id` — remove participation
- `PATCH /projects/:id/disable`              — soft-disable
- `PATCH /projects/:id/enable`               — re-enable

### Authorisation

A new helper on `Workshop`:

```ruby
# @return [Boolean] true when +user+ may edit / moderate this workshop
def manageable_by?(user)
  return false if user.nil?
  return true  if user.admin?
  user.facilitator? && participants.include?(user)
end
```

`manageable_by?` is the single authorisation gate for spec-13 surfaces:

| Action                              | Allowed when                                    |
|-------------------------------------|--------------------------------------------------|
| `workshops#edit`, `#update`         | `workshop.manageable_by?(current_user)`          |
| `workshop_participants#index`       | `workshop.manageable_by?(current_user)`          |
| `workshop_participants#destroy`     | `workshop.manageable_by?(current_user)`          |
| `projects#disable`, `#enable`       | `project.workshop.manageable_by?(current_user)`  |
| `/projects` index (facilitator)     | scoped to `current_user.workshops` projects      |
| `/projects` index (admin)           | unchanged, all projects                          |

Non-manageable users hitting these routes get a redirect with the existing
localised "not authorised" alert (`errors.access_denied`).

### Workshop edit

`WorkshopsController#edit` and `#update`.

- Editable fields:
  - **Translated**: `title_translations`, `description_translations`. Use
    the project's locale-tabs pattern (current `I18n.locale` first; then
    `en → es → it → el`).
  - **Plain**: `location`, `partner`, `starts_on`, `ends_on`,
    `contact_email`.
- Not editable in this spec:
  - `slug` — changing it would invalidate URLs already shared.
  - `agenda_*` rich-text — four Trix editors are real work; agenda editing
    is its own future spec.
- Form validation: re-uses existing model validations
  (`ends_on_not_before_starts_on`, translated-presence, contact_email
  format).
- Edit links surface:
  - On the authenticated workshop show page: an "Edit workshop" link in
    the heading area, visible only when `manageable_by?` is true.
  - On the facilitator and admin home variants: each workshop card gains
    a small "Edit" link next to "Open workshop" / "Invite participants",
    visible only when manageable.

### Workshop participants list

`WorkshopParticipantsController#index, #destroy`.

- `GET /workshops/:slug/participants` renders one row per
  `WorkshopParticipation`. Columns:
  - Avatar (initials), name, email
  - Institution (if present), country
  - Project memberships in this workshop (count + project titles inline or
    via tooltip)
  - "Joined on" — `WorkshopParticipation.created_at`, locale-formatted
  - Action: **"Remove from workshop"** (`DELETE`)
- Removal semantics:
  - Destroys the `WorkshopParticipation` record only. Existing
    `ProjectMembership`s and the `User` record are untouched. The user
    keeps any projects they're on; they're just no longer "in" this
    workshop until re-invited.
  - Confirmation via the existing Turbo modal pattern (a delete-confirm
    dialog mirroring the glossary delete flow).
  - The current user cannot remove themselves (the action is hidden /
    disabled). An admin user is not removable from this surface.
- Linked from:
  - The authenticated workshop show page heading area (next to "Edit
    workshop").
  - The facilitator / admin home workshop card (a small "Participants
    (N)" link).

### Project moderation

Soft-disable / re-enable.

- Disable / enable affordances render on the project show page above the
  normal action bar, visible only when `project.workshop.manageable_by?`
  is true.
- A disabled project's show page:
  - Renders a clear banner ("This project is currently disabled by your
    facilitator. Public access is hidden.")
  - Hides edit / publish CTAs.
  - Members can still read; the banner stays.
- A disabled project's public URL (`/published/:slug`) returns 404.
- Re-enable restores prior state. If `status: "published"`, the public
  URL works again.
- Disable does not change `status`. A disabled draft remains a draft; a
  disabled published project stays at the published status but is
  publicly invisible.
- No "reason" / "note" field. No mailer to project members. No audit log
  beyond `disabled_by_id` / `disabled_at`.

### `/projects` index — facilitator scoping

- Admin: unchanged. Sees every project.
- Facilitator: scoped to
  `Project.where(workshop_id: current_user.workshop_ids)`.
- Participant: redirect unchanged (already in place from spec 12).
- Disabled projects appear in the index for both admin and facilitator,
  marked with a "Disabled" chip.

### Workshop participation model — decision

The deferred-from-spec-7 question gets a recorded answer:

> **Keep `WorkshopParticipation` as a single role-agnostic join.** The
> facilitator home (spec 7), workshop edit, participants list, and
> moderation all work cleanly treating `WorkshopParticipation` as
> "user is associated with this workshop" while `User#role` carries the
> role flavour. No consumer is asking for a split.

Recorded in `DECISIONS.md` as part of this spec's PR.

### I18n

- All wizard labels, action labels, banners, flash messages, and form
  copy through `t(...)`.
- English filled. `es`, `it`, `el` carry English placeholders for longer
  copy plus translated short labels, matching the spec-7 pattern.

## Out of Scope

These are *deliberately* deferred. Each is a meaningful piece of work that
deserves its own focus.

- **Activity feed** — facilitator/admin recent-activity strip on home and
  per-workshop, synthesizable from `Project`/`LogEntry` timestamps. Its
  own follow-up spec.
- **Trix resource embeds** — toolbar buttons in `process_summary` for
  embedding materials and training references as styled link cards. Real
  Action Text attachment work; its own follow-up spec.
- **Workshop agenda editing** — four Trix editors (one per locale).
  Significant editor scope. Future agenda-edit spec.
- **Workshop slug changes** — risky and not yet asked for.
- **User-level deactivation** — disabling a user globally (preventing
  login). Different surface; separate decision.
- **Disable reason / moderation note** — text field captured at disable
  time. Useful but not required for MVP moderation.
- **Mailer notifications** for moderation actions — no in-app
  notifications and no transactional moderation emails per project policy
  (MEMORY.md).
- **Workshop creation** — the three workshops are seeded; admin-side
  workshop creation is not requested.
- **Bulk operations** (bulk-remove, bulk-disable) — not requested.
- **Audit log beyond `disabled_at` / `disabled_by_id`** — single most
  recent action only; no history.
- **Hard delete from moderation** — admins keep the existing destroy flow
  on projects; moderators do not get a separate "delete forever" action.

## Acceptance Criteria

### Workshop edit

- [ ] An admin can reach `GET /workshops/:slug/edit` and submit
      `PATCH /workshops/:slug`, persisting changes to title (per locale),
      description (per locale), location, partner, dates, and
      `contact_email`.
- [ ] A facilitator who participates in the workshop has the same access.
- [ ] A facilitator who does **not** participate in the workshop is
      redirected with the access-denied flash.
- [ ] Participants and visitors are blocked from `/edit` and `/update`.
- [ ] Slug is not editable (the input is absent or disabled).
- [ ] An "Edit workshop" link appears on the workshop show page heading
      and the facilitator/admin home cards only when manageable.

### Workshop participants list

- [ ] Manageable users reach `GET /workshops/:slug/participants` and see
      one row per participation with name, email, institution, country,
      project memberships in this workshop, and joined-at date.
- [ ] A "Remove from workshop" action destroys the
      `WorkshopParticipation` and leaves the user's `User` record + their
      `ProjectMembership`s untouched.
- [ ] The current user cannot remove themselves; the action is hidden or
      disabled.
- [ ] An admin user is not removable; the action is hidden or disabled.
- [ ] Non-manageable requests redirect with access-denied.

### Project moderation

- [ ] Manageable users see "Disable" / "Enable" affordances on the
      project show page.
- [ ] `PATCH /projects/:id/disable` sets `disabled_at` and
      `disabled_by_id`; idempotent on a disabled project.
- [ ] `PATCH /projects/:id/enable` clears both fields.
- [ ] A disabled project's show page renders the disabled banner and
      hides edit / publish CTAs.
- [ ] `editable_by?(member)` returns false while disabled.
- [ ] `GET /published/:slug` returns 404 for a disabled published
      project.
- [ ] The visitor home "Featured published projects" excludes disabled
      projects.
- [ ] The public workshop show page excludes disabled projects.
- [ ] An admin or workshop facilitator can re-enable a disabled project
      and the public URL works again immediately.

### `/projects` index facilitator scope

- [ ] Admin sees every project.
- [ ] Facilitator sees projects only from workshops they participate in.
- [ ] Disabled projects render with a "Disabled" chip in the index for
      both admin and facilitator.

### I18n

- [ ] All UI strings present in en/es/it/el. Non-en files may carry
      English placeholders for longer copy with `# TODO: translate`,
      matching the spec-7 pattern.

### Decisions

- [ ] `DECISIONS.md` records the decision to keep
      `WorkshopParticipation` as a single role-agnostic join, with the
      reasoning.

## Dependencies

- Spec 8 (`authentication`) — `current_user`, role enum, `require_login`.
- Spec 9 (`workshops`) — `Workshop`, `WorkshopParticipation`,
  `workshop_invitations`.
- Spec 10 (`projects-and-teams`) — `Project`, `ProjectMembership`,
  `editable_by?`, `visible_to?`.
- Spec 12 (`project-publication`) — `Project.published`, `slug`,
  `published_projects_path`.
- Spec 14 (`workshops-public-listing`) — public visitor surfaces that
  spec 13 must filter to active projects only.

### Downstream

- **`activity-feed` (follow-up spec, slug only).** Synthesizable feed
  for facilitator/admin home and per-workshop pages.
- **`trix-resource-embeds` (follow-up spec, slug only).** Toolbar
  buttons for materials / training references in `process_summary`.
- **`workshop-agenda-edit` (follow-up spec, slug only).** Edit the four
  per-locale Action Text agendas.
