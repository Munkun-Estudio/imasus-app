# Projects and teams

## What

The first authoring surface in IMASUS App: participants form a team (solo or
group), pick a framing challenge, and open a draft `Project` against a workshop.
This spec delivers the core `Project` object, `ProjectMembership`, creation
flow, membership management, and draft-level CRUD — everything needed before
the process log (spec 11) and publication flow (spec 12) can attach to a real
project.

- A `Project` model belonging to a workshop, optionally linked to a challenge,
  carrying a title, description, and the language the team is writing in.
- A `ProjectMembership` join between `Project` and `User`, unique per pair,
  with no role hierarchy — all members are equal editors.
- Flat routes: `/projects`, `/projects/new`, `/projects/:id`,
  `/projects/:id/edit`, plus nested membership routes.
- A project is **draft** throughout this spec. No publishing, no public URL —
  those belong to spec 12. The publishable state field is introduced here but
  only `draft` is valid.
- Single-language per project. The language defaults to the workshop's
  country language (`es` / `it` / `el`) and can be overridden by the team
  (e.g. mixed teams writing in English). Locale-tabs translation (as used by
  challenges / glossary) is **not** used — project content is authored once.

## Why

Challenges, materials, training, and the glossary are all inputs; projects are
where participants synthesise them into a deliverable. Until a `Project`
exists, nothing in the broader workshop journey — log entries, reflections,
prototype photos, the published project page — has a home to live on.

The team model is equally load-bearing. The imagineering approach privileges
collective work: participants self-organise into small interdisciplinary
teams. Making team composition flexible (users can belong to multiple
projects, teams can reshape mid-workshop) matches how the workshops actually
run, and is cheaper than modelling a rigid "one project per participant" rule
we'd later have to unwind.

Getting projects into place now unblocks specs 7 (role-aware home dashboard
threading the project flow), 11 (process log), 12 (publication), 13
(facilitator tools), and 14 (public listing). Every one of those needs a
`Project` to point at.

## Acceptance Criteria

### Data model

- [ ] `Project` with:
      - `workshop_id` — `belongs_to :workshop`, required.
      - `challenge_id` — `belongs_to :challenge, optional: true`.
      - `title` — string, required (presence).
      - `description` — text, optional in draft (only required once
        publication is built in spec 12).
      - `language` — string, required, inclusion `%w[en es it el]`, defaults
        to the workshop's language (derived from workshop country:
        spain→es / italy→it / greece→el; fallback `en`).
      - `status` — string, required, inclusion `%w[draft]` for now. Values
        like `published` land with spec 12; the column exists so we don't
        have to migrate again.
- [ ] `ProjectMembership` with:
      - `project_id`, `user_id` — both `belongs_to`, required.
      - Unique composite index on `(project_id, user_id)`.
- [ ] `Project has_many :memberships, dependent: :destroy`, `has_many :members,
      through: :memberships, source: :user`.
- [ ] `User has_many :project_memberships, dependent: :destroy`, `has_many
      :projects, through: :project_memberships`.
- [ ] Default scope / ordering: none; controller-level `order(created_at:
      :desc)` for lists.
- [ ] A `Project#visible_to?(user)` predicate returning true when the user is
      a member, a facilitator of the project's workshop, or an admin.
- [ ] A `Project#editable_by?(user)` predicate returning true when the user
      is a member or an admin (facilitators are read-only at draft;
      spec 13 will extend this).

### Creation flow

- [ ] `GET /projects/new?workshop_id=:id` shows a minimal creation form:
      title (required), optional challenge (select from the ten, localised
      question as label), language defaulted from workshop, with an explicit
      override. The workshop is inferred from the query param and the
      participant must belong to it (`WorkshopParticipation`); otherwise
      redirect with a localised flash.
- [ ] `POST /projects` creates the project **and** the creator's
      `ProjectMembership` in a single transaction. On success, redirect to
      the project show page with a localised flash.
- [ ] On validation failure, re-render `new` (422) with inline errors — no
      full-page reload, Turbo-native behaviour is fine.
- [ ] The "New project" affordance appears on the workshop show page
      (`/workshops/:slug`) for any workshop participant, carrying
      `workshop_id` through the query param. It does **not** appear on the
      public workshop listing for visitors.

### Project show & edit

- [ ] `GET /projects/:id` renders the draft page: title as heading, language
      badge, challenge card if linked (reuses `app/views/challenges/_card.html.erb`),
      description (`simple_format`), members list, and a footer strip of
      affordances visible only to editors (edit, add member, leave project).
- [ ] Access guard: 404 for visitors; redirect-with-flash for authenticated
      users who are not in `visible_to?`. Facilitators and admins see the
      same read surface plus an informational "facilitator view" chip.
- [ ] `GET /projects/:id/edit` and `PATCH /projects/:id` are guarded by
      `editable_by?`. The edit form updates title, description, challenge,
      and language. Validation failures re-render `edit` (422).
- [ ] `DELETE /projects/:id` is allowed for members only (admin separately).
      It destroys memberships via `dependent: :destroy`. Redirect to
      `/projects` with a localised flash. No "soft delete" — draft projects
      are cheap to recreate.

### Membership management

- [ ] `POST /projects/:id/memberships` creates a membership. The `user_id`
      must be a participant of the project's workshop and not already a
      member. Any existing member can add others; facilitators and admins
      cannot (they join via the workshop, not by invitation).
- [ ] `DELETE /projects/:id/memberships/:id` removes a membership.
      Allowed paths:
      - a member removing themselves ("leave project"),
      - an admin removing anyone.
      Not allowed: one member removing another. Keeps the social contract
      simple; avoids a kick-the-cofounder footgun in small teams.
- [ ] If the last member leaves, the project is **destroyed** in the same
      transaction (no orphaned draft projects). A localised flash explains
      the outcome.
- [ ] The "Add member" affordance on the project show renders an inline
      `<select>` of the workshop's participants who are not yet members,
      plus a submit button. No autocomplete / search in MVP — team sizes
      are small.

### Listing

- [ ] `GET /projects` shows the current user's projects, grouped by workshop,
      newest first. Empty state points to the workshop they belong to so
      they can start one.
- [ ] Admins visiting `/projects` see all projects grouped by workshop.
      Facilitators see projects for workshops they facilitate (for MVP, any
      facilitator user sees all projects — per-facilitator assignment lands
      with spec 13; record the assumption in notes and acceptance-check as
      "all facilitators see all projects").

### I18n

- [ ] All UI strings (headings, labels, buttons, flashes, empty states,
      error prefixes) go through `t(…)`. `en` filled; `es`, `it`, `el` can
      be stubs.
- [ ] The project's **authored content** (`title`, `description`) is
      rendered as stored regardless of `I18n.locale`; only the chrome
      localises.
- [ ] Language labels for the `language` field render via `t(…)` under
      `projects.languages.{en,es,it,el}`.

### Navigation

- [ ] The sidebar's Hub group stays as-is (Home only). "Projects" is **not**
      added to the sidebar in this spec — it's a role-conditional surface
      that belongs on Home (spec 7). For now, entry points are:
      - `New project` button on workshop show page,
      - `My projects` link inside the current-user dropdown (or equivalent
        post-login entry point added by spec 8 — confirm in notes).

### Tests (Minitest — tests gate implementation)

- [ ] Model:
      - `Project` presence/inclusion validations; language default resolution
        from workshop country; `visible_to?` / `editable_by?` across roles.
      - `ProjectMembership` uniqueness (composite); destroying project cascades.
      - Destroy-last-member auto-destroys project.
- [ ] Controller (Projects):
      - `new` requires the participant to belong to the workshop.
      - `create` creates project + creator membership in one transaction;
        failure rolls back both.
      - `show` guard matrix: visitor (404 unless public later), non-member
        participant (403/redirect), member (200), facilitator (200 read-only),
        admin (200).
      - `edit` / `update` guard matrix.
      - `destroy` allowed for members and admins; facilitator forbidden.
      - `index` returns current user's projects for participants; all
        projects for admin/facilitator.
- [ ] Controller (Memberships):
      - `create` with a non-workshop-participant `user_id` → rejected.
      - `create` with an existing membership → rejected (idempotent-ish:
        422 with clear message).
      - `destroy` as self → allowed; as another member → forbidden; as admin →
        allowed.
      - Last-member leave auto-destroys the project.
- [ ] System test (Turbo / flow):
      - From workshop show: click "New project", fill title, pick challenge,
        submit, land on project show with creator as sole member.
      - From project show: invite another workshop participant, see them
        appear in the members list.
      - Facilitator visits project show: sees "facilitator view" chip, no
        edit / invite affordances.

### YARD

- [ ] `Project` and `ProjectMembership` public API documented (associations,
      predicates, scopes if any). English.
- [ ] `ProjectsController` and `ProjectMembershipsController` actions carry
      a one-line purpose tag each.

### Docs

- [ ] Mark spec 10 ✅ in `.munkit/context.md` "Implementation Plan" once
      merged.
- [ ] `.munkit/MEMORY.md`: note the "members-equal, no owner role" pattern
      under **Key Patterns** if we haven't captured it elsewhere.
- [ ] `.munkit/DECISIONS.md`: log the decisions made during spec scoping:
      multi-membership allowed, pick-from-workshop invitations, flat URLs,
      single-language projects, draft-visibility extended to facilitator +
      admin.

## Out of Scope

- **Publication** — draft → published lifecycle, slug/public URL, the
  Behance-style public page. All of that belongs to spec 12.
- **Process log** — `LogEntry` with Action Text, timeline, photo/video
  uploads. Belongs to spec 11. Projects only need to exist for it to attach.
- **Facilitator tooling** — per-workshop facilitator assignment, moderation,
  "disable project" affordance, workshop-wide project listing for
  facilitators. Spec 13.
- **Public listing** — public index of workshops and their published
  projects. Spec 14.
- **Cover image / hero imagery** — projects in draft are text-only. Images
  arrive via the log (spec 11) and publication (spec 12).
- **Comments / feedback** — no in-app comment stream on projects in MVP.
- **Project templates / duplication** — not needed for IMASUS workflow.
- **Owner / role hierarchy within a team** — all members are equal; if we
  later need an owner concept, we can introduce a `role` column on
  `ProjectMembership`.
- **Cross-challenge projects** — one project → one challenge (optional).
  If a team pivots, they edit the link, not accumulate multiple.
- **Search / filtering** on `/projects` — team sizes and project counts are
  small; a chronological list is enough.

## Dependencies

- Spec 1 (`app-shell-and-navigation`) — layout, Tailwind, I18n plumbing.
- Spec 6 (`challenge-cards`) — optional `challenge_id`; `_card.html.erb`
  reused on the project show page.
- Spec 8 (`authentication`) — `User`, role helpers (`admin?`,
  `facilitator?`, `curator?`), login flow.
- Spec 9 (`workshops`) — `Workshop`, `WorkshopParticipation`, workshop
  show page where the "New project" CTA lives.

Downstream:

- Spec 7 (`home-page`) — participant dashboard threads the project flow
  (create team, start project, pick challenge, add log entries, publish).
- Spec 11 (`process-log`) — `LogEntry belongs_to :project`.
- Spec 12 (`project-publication`) — publishing wizard, `status` transitions,
  public URL.
- Spec 13 (`facilitator-tools`) — per-workshop facilitator assignment and
  project moderation.
- Spec 14 (`workshops-public-listing`) — public project pages per workshop.
