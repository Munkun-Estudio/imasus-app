# Notes: 2026-04-25-facilitator-tools

Scratch space and decision rationale for spec 13. Brief is the contract;
this file is the journal.

> **Numbering note.** Follow-up specs (`activity-feed`,
> `trix-resource-embeds`, `workshop-agenda-edit`) are referred to **by
> slug only** in this spec; they're new specs that aren't in
> `context.md`'s original 1–14 plan and will get plan numbers when
> added there.

---

## How this spec ended up at this scope

The original `context.md` row for spec 13 lists four things: workshop
management, participant invitation UI, project moderation (disable
participant/project), view all projects in a workshop. Across spec
implementations, three further items piled up under "facilitator tools":

- Workshop edit surface (spec 7 deferred contact_email editing here).
- Activity feed (spec 7 originally proposed an event strip on the
  facilitator home and was deferred).
- Trix toolbar embeds for materials/training (spec 12 deferred this
  from `process_summary` editor work).
- Per-workshop facilitator scoping on `/projects` (spec 12 deferred).
- Decision on `WorkshopParticipation` for facilitators (spec 7
  deferred).

Considered bundling everything. Rejected because each of these is a
real workstream:

- Activity feed is its own surface (facilitator home strip + per-workshop
  page). Synthesizable with no new model, but layout, sorting, and
  i18n add up.
- Trix resource embeds are real Action Text custom-attachment work — JS
  toolbar buttons, server-side card rendering, locale strings, policy
  for which materials/training items are embeddable. Big.

Final breakdown captured in the brief: spec 13 carries the four
original items (workshop edit folded into "workshop management") plus
the `/projects` scope and the `WorkshopParticipation` decision.
Everything else moves to its own follow-up spec.

---

## Decision log

Choices weighed in the discussion that produced this spec, with the
chosen option marked.

### Project moderation — soft-disable / hard-delete / both

- (a) ✅ **Soft-disable only.** Reversible flag (`disabled_at`,
  `disabled_by_id`). Members keep read access on the project show page
  with a banner; lose edit and publish CTAs. Public URLs 404. Hard
  delete is not part of the moderation surface — admins can still
  destroy projects via the existing project destroy flow if needed.
- (b) ~~Hard delete with confirmation.~~ Rejected — destructive,
  irreversible, doesn't match a "moderate first, restore later"
  workflow.
- (c) ~~Both.~~ Rejected — adds a second moderation action with a
  different mental model. Not needed for MVP.

### Workshop edit — admin-only or facilitator-too?

- (a) ~~Admin only.~~ Rejected — country-team facilitators run their
  own workshops and need to fix details (contact email, dates) without
  routing through admin.
- (b) ✅ **Admin + workshop's facilitators.** A facilitator who
  participates in this workshop (`WorkshopParticipation`) can edit it.
  Admin still has cross-workshop access. The `Workshop#manageable_by?`
  helper encodes this for spec 13 surfaces.

### Participant removal — orphan projects or leave them?

- (a) ✅ **Projects stay, only the `WorkshopParticipation` is destroyed.**
  Removing a participant from a workshop is an organizational action,
  not a project moderation action. The user keeps their existing
  project memberships.
- (b) ~~Cascade through `ProjectMembership`.~~ Rejected — would make a
  removal action also delete user-authored content, which is a
  separate (and bigger) decision. Project content is moderated via the
  project disable flow.

### Activity feed in spec 13?

- ~~Include here.~~ Rejected. Activity feed is its own surface
  (facilitator-home strip plus per-workshop page) and synthesises from
  multiple tables (`Project.created_at`,
  `Project.publication_updated_at`, `LogEntry.created_at`). Layout +
  sort + i18n + tests are non-trivial.
- ✅ **Defer to a follow-up spec, slug `activity-feed`.**

### Trix material/training embeds in spec 13?

- ~~Include here.~~ Rejected. Real Action Text custom-attachment work:
  JS toolbar buttons, server-side card rendering, choice of which
  resources are embeddable, persistence of the embed payload. Each
  axis has design choices that deserve focused thought.
- ✅ **Defer to a follow-up spec, slug `trix-resource-embeds`.**

### Workshop participation model — split or keep single join?

- ✅ **Keep single role-agnostic join.** `WorkshopParticipation`
  associates a user with a workshop; `User#role` carries the role
  flavor. Spec 7's facilitator home, the spec-13 `manageable_by?`,
  workshop edit, and participant management all work cleanly with the
  current model. No consumer is asking for a split.
- ~~Introduce a separate join for facilitators (e.g.
  `WorkshopFacilitator`).~~ Rejected for now — adds churn without a
  consumer. Re-open if a future spec needs facilitator-specific
  metadata (e.g. role-on-workshop, hours, etc.).
- This is recorded in `DECISIONS.md` as part of this spec's PR.

---

## Things to verify during implementation

- Existing `Project.published` callers must move to `Project.active.published`
  (or whatever combined scope we settle on) so disabled projects stop
  leaking out:
  - Visitor home featured projects (spec 7).
  - Public workshop listing (spec 14, `_published_projects.html.erb`).
  - `PublishedProjectsController#show` (spec 12).
- The authenticated workshop show page projects section: confirm that
  `Project#visible_to?` handles disabled drafts the way the brief
  describes (members see them with the Disabled chip; non-member
  workshop participants do not).
- `editable_by?` returning false for disabled projects also blocks
  publishing/republishing. The publication wizard already calls
  `publishable_by?` / `republishable_by?` which call `editable_by?`,
  so the change flows through automatically; verify by re-reading
  `ProjectPublicationsController` before claiming done.
- The "remove participant" action should reuse the project's existing
  Turbo modal pattern (`<turbo-frame id="modal">` + a delete-confirm
  partial). Look at the glossary delete flow and the project delete
  flow as templates.
- Workshop edit form's translated fields — reuse the locale-tabs
  pattern from challenges and glossary edit (per MEMORY.md).
- Disable/enable affordances are mutually exclusive; only one shows at
  a time on the project show page based on `disabled?`.
- The `/projects` index test for facilitator scoping should set up
  multi-workshop data (a workshop the facilitator is in vs one they
  are not) to exercise the scope.
- Admin redirect on `/admin/dashboard` is gone (spec 7); confirm
  `/projects` index is still admin/facilitator only post-spec-12.

---

## Implementation shape to consider

Order of slices for TDD landing:

1. `Project` soft-disable schema + model (`disabled_at`,
   `disabled_by_id`, `Project.active`, `disable!`/`enable!`,
   `editable_by?` returns false when disabled).
2. Filter public surfaces through `Project.active` (visitor home,
   workshop public listing, `/published/:slug`).
3. `Workshop#manageable_by?` helper + tests.
4. `WorkshopsController#edit, #update` + view + locale tabs.
5. Edit-link affordance on workshop show + facilitator/admin home cards.
6. `WorkshopParticipantsController#index, #destroy` + view + remove
   confirmation.
7. `ProjectsController#disable, #enable` member actions + view banner +
   show-page affordances.
8. `/projects` index facilitator scope.
9. I18n sweep across the four locale files.
10. Self-review (`rails-code-review`), browser smoke check.

Two model touches that should land together (3+4) so workshop edit
isn't visible without authorisation in place.

---

## Open questions

None — all six discussion items resolved before writing the brief.

## Out-of-spec markers to leave in code

So follow-up specs can find their seams:

- The facilitator and admin home cards: a `<%# TODO(activity-feed): per-workshop activity strip here %>` near the workshop card body.
- The publication wizard's `process_summary` Trix editor: a `<%# TODO(trix-resource-embeds): wire toolbar buttons for material/training references %>` near the editor invocation.
- ~~The workshop edit form: a `<%# TODO(workshop-agenda-edit) %>` near the form's bottom.~~ **Superseded by the `workshop-management` spec**, which folded per-locale agenda editing directly into the workshop edit form. The TODO marker was removed when that spec landed.

---

## TDD / workflow reminders

Per `CLAUDE.md` the order is **Tests → Implementation → YARD → Docs →
Self-review (`rails-code-review`) → PR**. The spec is large enough that
the test plan should walk slice by slice — model tests for the
soft-disable behaviour, controller tests for each new action, system
tests for the moderation banner / disable button toggling, integration
tests for the `/projects` scope, locale-key coverage matching project
practice, and the public-404 assertion for `/published/:slug` on a
disabled project.

Testing notes:

- Use Minitest (project default).
- The disable/enable action should be tested via `patch
  disable_project_path(project)` or whatever route helper Rails
  generates from the member route declaration.
- Public-404 tests should explicitly assert response status 404, not
  just rely on routing.
- Browser smoke check before opening the PR: log in as the seeded
  Elena facilitator, edit the spain workshop, remove and re-invite a
  participant, disable / re-enable a project, and confirm the visitor
  home + public workshop page exclude the disabled project.
