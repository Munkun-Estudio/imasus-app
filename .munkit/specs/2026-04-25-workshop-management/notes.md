# Notes: 2026-04-25-workshop-management

Scratch space and decision rationale. Brief is the contract; this file is
the journal.

> **Numbering note.** This spec is **not** in `context.md`'s 1–14
> plan — it grew out of UX review of spec 13 and supersedes the
> deferred `workshop-agenda-edit` slug. Refer to it as
> `workshop-management` only.

---

## How this spec ended up at this scope

Three independent threads landed together because they all touch the
workshop edit form:

1. **Agenda editing.** Originally deferred to a `workshop-agenda-edit`
   spec on the assumption it deserved its own page (four Trix editors
   are real work). UX review reframed: facilitators don't know about
   the metadata-vs-agenda storage split (JSONB-translated vs Action
   Text per-locale). A second "Edit agenda" button on top of the
   already-crowded show page was rejected as a UX leak from
   implementation. Folding agenda fields into the existing per-locale
   tabs (title + description + agenda per tab) removes the need for a
   second surface.

2. **Workshop creation.** Workshops were seed-only. Adding a new
   workshop required a developer. The user (correctly) flagged that
   this blocks the operational reality where country-team
   facilitators run their own workshops.

3. **`partner` field removal.** Single-string field for what is
   actually multi-partner reality (e.g. Spain = Munkun + INMA). The
   show-page badge was misleading. Description copy already covers
   "who runs this." Removed opportunistically because we're touching
   the edit form anyway.

Considered splitting into two specs (`workshop-agenda-edit` +
`workshop-creation`). Rejected because they share the edit form, the
locale-tabs widget, the auth helpers, and the i18n surface. One spec,
one PR, one set of tests.

---

## Decision log

### Agenda editing — own page or fold into existing form?

- (a) ~~Dedicated `/workshops/:slug/edit_agenda` page with four Trix
  editors stacked or in a separate locale-tabs widget.~~ Rejected —
  surfaces the storage split to facilitators, adds a second route,
  doubles the auth gate.
- (b) ✅ **Fold into the existing `workshops/edit` form's per-locale
  tabs.** Each tab now shows title + description + agenda for that
  locale. One button, one form, one auth gate.

### Storage shape — keep four `has_rich_text` columns?

- ✅ **Keep.** The per-locale `has_rich_text :agenda_<locale>` design
  predates this spec and works with Action Text's translation
  story (which is "no built-in support; do it per locale"). Migrating
  to a single Action Text body with locale separators would be a
  hack. No change.

### Workshop creator role — admin only / admin + facilitator?

- (a) ~~Admin only.~~ Rejected — country-team facilitators run their
  own workshops; routing every new workshop through admin is friction.
- (b) ✅ **Admin or facilitator role.** Any user with
  `role: facilitator` can create a workshop, regardless of whether
  they have any prior `WorkshopParticipation`.

The role check (`current_user.facilitator? || current_user.admin?`)
gates the *ability to create*; the auto-attached
`WorkshopParticipation` after create gives them management on the
workshop they just made. Facilitators don't need a pre-existing
workshop to bootstrap.

### Slug strategy on create

- (a) ~~Facilitator-supplied.~~ Rejected — bad URLs, typos, edits
  later (and we don't allow slug edits anyway, see spec 12).
- (b) ✅ **Auto-generate from title** (preferring `en → es → it → el`
  order for the source). `parameterize`, max 100 chars, collision
  dedupe with `-2`/`-3` suffix. Pattern matches `Project#assign_slug`
  from spec 12.

### Auto-attach creator — always or only facilitators?

- ✅ **Always.** Even if an admin creates a workshop, write
  `WorkshopParticipation`. The participant-count helper from spec 13
  filters by role (`count(&:participant?)`), so admin attachment
  doesn't inflate counts. Always-attaching is simpler than branching
  on role.

### Draft / published workshop state?

- ~~Add a workshop status enum or `published_at` flag.~~ Rejected.
  Facilitators fill the form once and submit. No half-state. A
  workshop with translated title + description + dates is publicly
  visible immediately.

### `partner` field removal — bundle here or separate?

- ✅ **Bundle.** Touching the edit form anyway; the migration is
  trivial; the field is actively misleading. A separate spec for one
  column drop would be overhead.

---

## Things to verify during implementation

- The workshop edit form already permits `title_translations: {},
  description_translations: {}` via `workshop_params`. Adding the
  four agenda associations needs care:
  Action Text writes through `agenda_en=` / etc. setters and persists
  via the rich-text association. Permit them in `workshop_params` and
  let Rails handle the rest. Verify a round-trip with all four
  locales filled.
- `Workshop.ready_for_listing` and the `seed_from_yaml!` cleanup
  remove rows that are not in the seed list **and** have no
  `WorkshopParticipation`. After we let facilitators create
  workshops, this cleanup will destroy any user-created workshop the
  next time seeds run if it has no participations. Harmless after
  the auto-attach lands (every new workshop has at least the
  creator), but worth a sanity check before the PR ships.
- After dropping `partner`, several tests will need updates:
  `workshop_test.rb` removes the `requires partner` assertion;
  `workshops_controller_test.rb` setup blocks should drop
  `partner: ...`; the same for `project_test.rb` setup and
  `published_projects_controller_test.rb` setup.
- The show-page button cluster — keep the existing classes / CSS as
  much as possible. The visual cleanup is grouping (e.g. wrapping
  secondaries in a `flex gap-2` container next to the primary)
  rather than redesigning the buttons themselves.
- Slug auto-generation: write a small unit test exercising
  `en → es → it → el` fallback. Don't depend on hash insertion
  order — pick the locale explicitly.

---

## Implementation slice order

Suggested TDD landing:

1. `partner` removal — schema, validation, scope, seeds, views, i18n,
   tests. Standalone slice; smallest blast radius first.
2. Agenda editing in `workshops#edit` — per-locale Trix in the tabs,
   `workshop_params` permits, success path test.
3. `Workshop.creatable_by?(user)` helper + tests.
4. `Workshop#assign_slug` private method + collision tests.
5. `WorkshopsController#new, #create` + auto-attach transaction +
   tests.
6. "New workshop" CTA on `/workshops` index.
7. Show-page button rearrangement (visual only).
8. I18n sweep across the four locale files (drop partner keys; add
   creation form + CTA + flash keys).
9. `DECISIONS.md` entry covering partner removal + agenda fold.
10. Self-review (`rails-code-review`), browser smoke, PR.

---

## Open questions

None — all six discussion items resolved before writing the brief
(role gate, slug strategy, attach-on-create, destroy out of scope, CTA
placement, no draft state, show-page polish in scope).

## Out-of-spec markers to remove

- `<%# TODO(workshop-agenda-edit) %>` placeholder in
  `app/views/workshops/edit.html.erb`. Drop it now that this spec
  ships agenda editing inline.
- The "Future agenda-edit spec" line in
  `.munkit/specs/2026-04-25-facilitator-tools/notes.md` should be
  retroactively annotated noting this spec supersedes it (light
  touch — one line).

## TDD / workflow reminders

Per `CLAUDE.md` the order is **Tests → Implementation → YARD → Docs →
Self-review (`rails-code-review`) → PR**. Dev seeds are not affected
(workshops seed via `db/seeds/workshops.yml` only); the demo Maria /
Elena seeded users are unaffected.

Browser smoke check before PR: log in as Elena (facilitator), click
"New workshop" from `/workshops`, fill the form, verify the new
workshop appears in the index, that Elena can immediately reach
`/workshops/<slug>/edit`, and that the agenda content saved via the
edit form renders on the read-only `/workshops/<slug>/agenda` page.
