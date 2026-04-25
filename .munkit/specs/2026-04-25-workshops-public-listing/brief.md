# Spec 14 — Workshops Public Listing

## What

Make the existing workshops index and workshop detail routes public, so
organizers can share each workshop as a small Eventbrite-style public page. The
public surfaces list all workshops, show workshop metadata and description, and
show every published project for each workshop. Workshop agenda content remains
login-only.

## Why

Workshops are the public entry point for the IMASUS programme. The app already
has public materials, training, challenges, glossary pages, and published
project pages, but the workshop container itself is still locked behind login.
That makes it hard for organizers to publicize a workshop, share what happened,
and point visitors toward the projects that participants published.

This spec turns workshops into shareable public programme pages without
weakening the participant workspace. Visitors can browse workshops and published
outputs; logged-in participants, facilitators, and admins keep the richer
authenticated workshop behaviour introduced in specs 9 and 12.

## Scope

### Routes and access

Keep the existing route shape:

```ruby
resources :workshops, only: [ :index, :show ], param: :slug do
  member do
    get :agenda
  end

  resources :invitations, only: [ :new, :create ],
                          controller: "workshop_invitations"
end
```

- `GET /workshops` is public. No login required.
- `GET /workshops/:slug` is public. No login required.
- `GET /workshops/:slug/agenda` remains authenticated. Public visitors should
  be redirected to login or receive the existing unauthenticated response used
  elsewhere in the app.
- Nested invitation routes remain facilitator/admin-only and authenticated.
- Unknown workshop slugs still return `404`.
- Do not add parallel public routes such as `/public/workshops`; the public URL
  is the canonical `workshop_path`.

### Public workshops index

`GET /workshops` lists all workshops, including workshops with zero published
projects.

Each workshop card should show:

- title
- location
- partner
- date range
- short description excerpt
- count of published projects
- clear link to the workshop detail page

For logged-in users, keep the existing attendance indicator where relevant. For
visitors, suppress attendance-specific UI entirely.

The existing empty state can remain for defensive coverage, even though
production is expected to have seeded workshops.

### Public workshop detail

`GET /workshops/:slug` becomes the shareable public workshop page. It should feel
like a concise event page: enough context for an organizer to share the workshop,
and enough published work for an outside visitor to understand the output.

The page should show:

- title
- location
- partner
- date range
- description
- every published project for the workshop, newest first by
  `publication_updated_at` with a fallback to `created_at`
- project card metadata: project title, challenge badge if linked, team member
  names or initials, hero image thumbnail when present, and "last updated"
  date when available
- published project cards link to `published_project_path(slug:)`

For unauthenticated visitors:

- show only published projects
- do not show draft project cards
- do not show "Your workshop", "Your project", "Start a project", "Invite
  participants", or edit/admin affordances
- do not link to the agenda

For authenticated users:

- preserve the spec 12 workshop projects behaviour: all workshop projects are
  visible in context, draft project cards obey existing member/admin/facilitator
  access rules, and the current participant's own project remains visually
  distinguished
- preserve the facilitator/admin "Invite participants" affordance
- preserve the agenda link

The implementation may use one conditional section or separate public/auth
partials, but the public page must not leak draft project details.

### Agenda access

The workshop agenda remains a participant/facilitator workspace artifact, not
part of the public marketing page.

- `GET /workshops/:slug/agenda` still requires login.
- Public visitors should not see agenda links on index or detail pages.
- Authenticated users keep the existing agenda page and link.

### Request-a-spot CTA

Do not add a new request-a-spot CTA in this spec. Spec 7 may carry a provisional
visitor-home `mailto:` CTA, and a later request-a-spot spec will replace it with
a real flow. This spec should not touch that surface, to avoid colliding with
the concurrent `spec/7-home-page` branch.

### I18n and presentation

- All new UI strings go through `t(...)`.
- English is filled; `es`, `it`, and `el` are present at least as stubs,
  following the existing project convention.
- Reuse the existing light, editorial workshop styling. Do not turn the
  workshop page into a management dashboard.
- The public workshop detail should be shareable and legible without assuming
  the visitor knows IMASUS internals.
- Dates are rendered with the existing locale-aware workshop date helper.

### Queries and performance

- Avoid N+1 queries for workshop cards and project cards. Eager-load published
  projects with members, challenge, and hero image attachment where needed.
- All workshops are shown; do not filter out workshops without published
  projects.
- All published projects for a workshop are shown on the workshop detail page;
  do not cap the list.

## Acceptance Criteria

### Access

- [ ] `GET /workshops` returns `200` for unauthenticated visitors.
- [ ] `GET /workshops/:slug` returns `200` for unauthenticated visitors.
- [ ] `GET /workshops/:slug/agenda` still requires login.
- [ ] Unknown workshop slugs return `404`.
- [ ] Nested workshop invitation routes still require an authorized
      facilitator/admin.

### Public index

- [ ] The public workshops index lists every workshop, including workshops with
      zero published projects.
- [ ] Each workshop card renders title, location, partner, dates, description
      excerpt, and published-project count.
- [ ] Visitor cards do not render attendance badges or auth-only CTAs.
- [ ] Signed-in users still see attendance state where applicable.

### Public detail

- [ ] The public workshop detail renders title, location, partner, dates, and
      description without login.
- [ ] The public detail lists every published project in that workshop, newest
      first.
- [ ] Published project cards show title, team member names or initials,
      challenge badge when present, hero thumbnail when present, and last updated
      date when present.
- [ ] Published project cards link to `/published/:slug`.
- [ ] Workshops with zero published projects show a calm empty state, not a
      blank grid.
- [ ] Visitors do not see draft project cards, project creation links, agenda
      links, participant-only badges, or facilitator/admin invitation links.

### Authenticated behaviour

- [ ] Signed-in participants still see the spec 12 project section behaviour:
      all workshop projects visible, own project distinguished, and draft cards
      linked only when allowed.
- [ ] Facilitators/admins still see the "Invite participants" affordance.
- [ ] Authenticated users still see the agenda link and can reach the agenda
      page.
- [ ] Existing `/projects` and `/published/:slug` behaviour is unchanged.

### I18n and tests

- [ ] All new strings exist in `en`, `es`, `it`, and `el`.
- [ ] Request/controller tests cover public access to index/detail, private
      access to agenda, hidden visitor-only auth affordances, and visible
      authenticated affordances.
- [ ] Tests cover that draft projects are not rendered for visitors, while
      published projects are.
- [ ] Tests cover workshops with no published projects.
- [ ] Tests cover all published projects appearing on detail, not just a capped
      subset.

## Out of Scope

- Public agenda pages.
- A request-a-spot form or new CTA surface. Leave this to the later
  request-a-spot spec and avoid the concurrent home-page branch.
- Workshop creation/editing UI.
- Public registration or open self-signup.
- SEO/Open Graph metadata beyond the existing title/meta-description pattern.
- Featured or curated workshop/project ordering. Workshop pages show all
  published projects using recency.
- Hiding workshops with no published projects.
- Changing published project page content or URL shape.
- Changing participant/facilitator project authorization rules.

## Notes

- Spec 9 created the authenticated workshop pages and agenda surface.
- Spec 12 made `/published/:slug` public and added published project discovery
  inside authenticated workshop pages.
- Spec 14 builds on those surfaces by making `workshops#index` and
  `workshops#show` public while keeping `workshops#agenda` private.
