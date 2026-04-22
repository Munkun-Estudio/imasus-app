# Projects and teams — notes

Open questions, resolved-but-nuanced decisions, and scratch work. The brief
is the contract; this file is the workbench.

## Resolved (2026-04-22, during scoping with Pablo)

- **Team composition.** A user can belong to multiple projects within the
  same workshop. Rationale: participants may rethink their framing and start
  over with a different team; rigid "one project per user" would force us
  to delete history or block legitimate reshaping. Unique constraint is on
  `(project_id, user_id)`, not on `(workshop_id, user_id)`.
- **Adding members.** Members are picked from the project's workshop's
  participants (i.e. users with a `WorkshopParticipation`). No email
  invitations from the project surface; invitations are a workshop-level
  concern handled by facilitators (see `workshop_invitations` built in
  spec 9).
- **Challenge link.** Optional at creation so a team can form first and
  scope the framing challenge afterwards. Spec 12 (publication) will decide
  whether `challenge_id` becomes required at publish time.
- **URL shape.** Flat (`/projects/:id`) rather than nested under workshop
  (`/workshops/:slug/projects/:id`). Matches how materials and challenges
  are already modelled; nesting adds routing weight without a clear payoff
  because projects are navigated from a participant's dashboard, not
  breadcrumb-browsed from the workshop tree.
- **Draft visibility.** Members + workshop facilitator + admin. Facilitators
  need read access anyway for spec 13 so adding it now is free.
- **Language.** Single-language per project. Default = workshop's country
  language (`es` / `it` / `el`); overridable per project (e.g. a mixed team
  writing in English). No locale-tabbed authoring like challenges / glossary.

## Open questions — flag before implementing

- **ID vs slug in URLs.** MVP uses numeric `:id` for `/projects/:id`.
  Publication (spec 12) will likely introduce a public slug. Question:
  do we introduce `slug` now (nullable, populated on publish) or bolt it on
  in spec 12? Leaning **bolt on later** — we don't know the slug rules
  yet (include workshop? lowercase title? random hash?) and squatting a
  nullable column pre-answers a decision we haven't made.
- **Owner / creator tracking.** The brief keeps membership role-less, but
  we might still want `created_by_id` on `Project` for audit trails —
  cheap to add later via migration once we see a real need. Not adding in
  this spec.
- **"My projects" entry point.** Spec 8's login flow redirects to the
  sidebar-gated home. This spec needs an entry to `/projects` that's
  discoverable for authenticated users without polluting the public
  sidebar. Options:
  - Adding a user-dropdown next to the logout control (if one exists).
  - Putting a participant-only card on Home (spec 7) pointing to
    `/projects`. **Preferred** — aligns with the role-aware Home scope
    already captured in `DECISIONS.md`.
  - A top-of-page "Your projects" breadcrumb on workshop show.
  Action: verify the post-login landing in the current codebase and pick
  during implementation. If we need a nav item, confirm with Pablo first
  since the sidebar IA was just renegotiated.
- **`language` selector UX on project edit.** A bare `<select>` is easiest,
  but we should check whether non-native locale names read well
  (e.g. "Ελληνικά" vs "Greek (el)"). Lean: show the endonym + the ISO code.
- **Facilitator "facilitator view" chip.** The brief mentions a chip to
  signal read-only. Open: should this be a generic banner above the page
  ("You are viewing as facilitator — actions are disabled") to avoid
  subtle confusion? Decide during UI pass.
- **Destroy ergonomics.** `DELETE /projects/:id` wipes all memberships
  and log entries (once spec 11 lands). MVP says hard-delete; add a
  confirm prompt (Turbo confirm dialog) so a single stray click can't
  nuke days of work. Encode in the view, not the model.
- **Facilitator scope.** We assume *all* facilitators see *all* projects
  for MVP because per-workshop facilitator assignment is not yet modelled.
  Revisit in spec 13; until then `Project#visible_to?` treats
  `facilitator?` as a workshop-agnostic read grant.

## Design / UI — think-through

- Project show page layout: a single-column read surface mirroring the
  material / challenge detail feel (title, metadata row, body, sidebar
  with members + challenge card). Reuse whatever we settled on in spec 9
  for the workshop show page shell.
- Members list: avatar (initials) + name + "leave" affordance for self.
  No role badges. Keep chrome light.
- New-project form: minimal — title + optional challenge + language.
  Description input appears on edit, not create, so participants don't
  feel they need to write a summary before they have a team formed.
  Rationale: lower the activation threshold.
- Empty states: the `/projects` empty state should nudge participants to
  their workshop page ("You're in IMASUS Greece — start a project there →").

## Testing notes

- **Fixtures.** We'll need project and project-membership fixtures for
  controller tests. Check `test/fixtures/workshops.yml` / `users.yml` for
  the participant + facilitator + admin identities to wire against.
- **Transaction test.** Creating a project must atomically create the
  creator's membership. Assert: if the membership save fails (e.g. stubbed
  validation error), no project row lingers.
- **Role matrix helper.** Spec 9's tests likely introduced a helper for
  logging in as each role. Reuse it; don't fork.
- **System test** for the happy path is valuable but slow. One full flow
  (workshop → new project → invite teammate → leave) is enough; the rest
  stays at controller level.

## Downstream reminders (so we don't forget)

- When spec 12 adds publication, `status` should move from
  `draft → published` through a state-machine-ish setter; this spec only
  enshrines `draft` so the column exists.
- When spec 11 adds `LogEntry`, its `belongs_to :project` should mirror
  the visibility matrix (`visible_to?`). Centralise the predicate on
  `Project` so log entries delegate rather than re-implement.
- When spec 13 adds per-workshop facilitator assignment, tighten
  `Project#visible_to?` so a facilitator only sees workshops they
  facilitate. The current permissive behaviour is a deliberate MVP shortcut.
