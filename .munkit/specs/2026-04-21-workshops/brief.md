# Workshops

## What

Turn the workshop stub introduced by the authentication spec into the real
workshop domain and participant-facing workshop surface. This spec fleshes out
the currently confirmed IMASUS workshop seed with proper metadata, slug-based
routes, an authenticated workshops index, a richer workshop detail page, and a
dedicated agenda page per workshop.

The auth spec already shipped a minimal `Workshop` + `WorkshopParticipation`
pair so invitations have somewhere to attach participants. This spec does not
restart that work; it extends it into the actual workshop experience that
projects will hang off next.

## Why

Projects, teams, facilitator moderation, and the later public workshops listing
all depend on workshops being real objects instead of invitation-only stubs.
Participants need a clear place in the app to understand which workshop they
belong to, where and when it happens, what partner hosts it, and what the local
agenda looks like before they start project work.

This is also the right next slice in the sequence: unlike challenge cards or
the home page, workshops sit directly on the critical path to specs 10, 13, and
14.

## Acceptance Criteria

### Data model

- [ ] Reuse the existing `Workshop` and `WorkshopParticipation` models from spec
      8; do not replace them with a new structure.
- [ ] `Workshop` grows from the auth stub to carry the fields needed by the
      actual product surface: `slug`, `location`, `partner`, `starts_on`,
      `ends_on`, plus translatable JSONB fields for `title` and `description`,
      and locale-aware rich agenda content.
- [ ] `title_translations` and `description_translations` reuse the existing
      `Translatable` concern pattern (`*_translations` columns with locale-aware
      readers and fallback through `I18n.fallbacks`).
- [ ] Workshop agenda is stored as locale-aware rich text so facilitators can
      author it with Trix in a later spec. A pragmatic shape such as one Action
      Text field per locale is acceptable; do not force agenda into plain-text
      JSONB if that blocks rich authoring later.
- [ ] Validations: presence of `slug`, `location`, `partner`, `starts_on`,
      `ends_on`; uniqueness of `slug`; `starts_on <= ends_on`; title and
      description must be present in at least one locale, but English is not
      required. Agenda may be blank.
- [ ] `WorkshopParticipation` remains the join model for participants attached
      to a workshop. Existing invitation flows continue to work unchanged.

### Seeds

- [ ] Workshops are seeded from a dedicated workshop seed source rather than
      hand-written rows in `db/seeds.rb`.
- [ ] Seed data is idempotent and keyed by workshop slug.
- [ ] For the first implementation pass, only the Spain workshop is seeded as
      canonical content. Greece and Italy remain deferred until their workshop
      details are confirmed.
- [ ] The Spain workshop seed carries the currently known date,
      `2026-04-28`, plus description and agenda content derived from the
      facilitator docs. Where the two-session webinar/in-person split is not yet
      confirmed as separate dated events, the model should tolerate that
      uncertainty without inventing extra dates.
- [ ] Seeds tolerate locale-sparse source material. If a workshop only has
      Spanish, Italian, or Greek copy, seed it without warnings or placeholder
      English filler.
- [ ] Existing participant invitations and workshop participations still point
      at the same workshop rows after reseeding in development.

### Routing and access

- [ ] Workshop URLs use `slug`, not numeric ids.
- [ ] Routes:
      `GET /workshops` (index),
      `GET /workshops/:slug` (detail),
      `GET /workshops/:slug/agenda` (agenda page).
- [ ] These pages require login. Public workshops discovery remains deferred to
      spec 14 (`workshops-public-listing`).
- [ ] The nested facilitator/admin invitation flow under
      `/workshops/:workshop_id/invitations` continues to work against the same
      workshop records; no regression to spec 8.

### Workshops index

- [ ] `GET /workshops` renders an editorial list/grid of the seeded workshops
      for signed-in users.
- [ ] Each workshop card shows enough orientation context to choose a workshop:
      title, location, partner, dates, a short description excerpt, and a clear
      link to open the workshop.
- [ ] If the current user participates in a workshop, that state is surfaced in
      the index ("Your workshop", "Attending", or equivalent calm language).
- [ ] Empty-state handling exists even though production is expected to have at
      least the seeded Spain workshop.

### Workshop detail

- [ ] `GET /workshops/:slug` renders a proper workshop page for signed-in users.
- [ ] The page includes: title, location, partner, dates, description, and a
      clear link to the agenda page.
- [ ] The page is the primary landing target after participant invitation
      acceptance.
- [ ] Facilitator/admin users still see the "Invite participants" affordance on
      the workshop page; participants do not.
- [ ] The page is shaped as workshop orientation, not as a management dashboard.
      Keep it calm, editorial, and legible for mixed-discipline participants.

### Agenda page

- [ ] `GET /workshops/:slug/agenda` renders the workshop-specific agenda as a
      dedicated page, not just a paragraph buried on the detail page.
- [ ] Agenda content is locale-aware through the same app-wide locale system,
      with graceful fallback to another available locale when the current one is
      missing.
- [ ] The agenda page links back to the workshop detail page and carries a
      meaningful page title.
- [ ] Agenda content is rendered as rich text suitable for Trix-authored
      headings, lists, and structured programme copy.

### I18n and presentation

- [ ] All workshop UI strings go through `t(...)` with `en` filled and
      `es`/`it`/`el` at least stubbed.
- [ ] User-facing workshop prose follows the project's established multilingual
      pattern, while allowing workshop-specific content to exist in only one
      local language when that is the source material.
- [ ] Dates are presented in a readable, locale-aware way on index and detail.

### Tests

- [ ] Model tests cover validations, slug uniqueness, date ordering, locale-aware
      translated readers, and participation associations.
- [ ] Seed tests cover idempotent loading of the current workshop seed set,
      starting with the Spain workshop.
- [ ] Request/controller tests cover:
      `/workshops` requires login and renders seeded workshops for signed-in
      users;
      `/workshops/:slug` and `/workshops/:slug/agenda` 404 on unknown slugs;
      locale switching changes rendered translated content when a locale value is
      present.
- [ ] Role/UI tests cover the invitation CTA being visible to facilitator/admin
      users and hidden for participants.

### YARD and docs

- [ ] Public methods added to `Workshop` and any workshop helper are documented
      in English.
- [ ] `.munkit/specs/2026-04-21-workshops/notes.md` records the baseline carried
      forward from spec 8 and any decisions around seed shape or agenda
      rendering.

## Out of Scope

- Public workshops listing for unauthenticated visitors. That belongs to spec
  14.
- Facilitator CRUD for creating/editing workshops in-app. This spec assumes the
  three known workshops are seeded content.
- Project creation, team membership, or browsing projects inside a workshop.
  That belongs to spec 10.
- Challenge assignment, process log, or publication flows.
- Attendance tracking, workshop phases/states, or grading/evaluation features.
- In-app facilitator editing UI for workshop agendas. This spec only needs the
  storage/rendering shape so spec 13 can expose Trix authoring later.

## Notes

- Baseline already in repo from spec 8:
  `Workshop(title, location, slug?)`, `WorkshopParticipation`, invitation routes,
  invite service, basic controller/tests, and placeholder views.
- Keep the spec honest about that starting point: implementation should extend
  the stub rather than rewrite the world.
