# Notes: 2026-04-25-workshops-public-listing

Scratch space for working through spec 14. Brief is the contract.

---

## User answers that shaped the spec

- Existing workshop routes become public. No separate `/public/workshops` route
  namespace.
- Public workshop detail pages are included. The mental model is a small
  Eventbrite-style page that organizers can share to publicize a workshop.
- Agenda content is not public.
- All workshops appear publicly, including those with zero published projects.
- Workshop detail pages show all published projects, not a capped preview.
- Request-a-spot is avoided in this spec to prevent overlap with the concurrent
  home-page work and the later dedicated request-a-spot flow.
- Published project cards may show participant/team names. Spec 12 already makes
  team names public on published project pages.

## Collision guard

The user is concurrently working with Claude on branch `spec/7-home-page`. That
branch owns `.munkit/specs/2026-04-25-home-page/brief.md` and `notes.md` and
touches home/sidebar/settings surfaces.

Spec 14 should avoid:

- editing `.munkit/specs/2026-04-25-home-page/*`
- adding or changing the visitor home request-a-spot CTA
- relocating layout chrome such as locale switcher or user menu
- touching `/settings`

Expected spec 14 touch points are likely:

- `app/controllers/workshops_controller.rb`
- `app/views/workshops/index.html.erb`
- `app/views/workshops/show.html.erb`
- `app/views/workshops/_projects.html.erb` or a new public projects partial
- workshop/project helpers for public card rendering if needed
- workshop controller tests and locale files

## Current code shape at spec-writing time

- `resources :workshops, only: [ :index, :show ], param: :slug` already exists.
- `GET /workshops/:slug/agenda` exists as a member route.
- `WorkshopsController` currently has `before_action :require_login` for all
  actions.
- `workshops#show` currently assumes `current_user` is present when computing
  `@attending` and `@user_project_ids`.
- `app/views/workshops/_projects.html.erb` currently calls
  `project.editable_by?(current_user)`, which must not run for visitors without
  guarding the visitor path.
- `published_project_path(slug:)` is the public project URL from spec 12.

## Implementation shape to consider

Keep the route names stable and make access conditional:

- `before_action :require_login, only: [ :agenda ]` in `WorkshopsController`.
- Invitation routes stay protected by `WorkshopInvitationsController`.
- In `show`, load public data for everyone:
  `@published_projects = @workshop.projects.published...`
- For logged-in users, additionally load the authenticated project list needed
  by spec 12 (`@projects`, `@attending`, `@user_project_ids`).
- For visitors, render a public published-projects section and skip auth-only
  affordances.

Potential ordering:

```ruby
published_projects = @workshop.projects
                              .where(status: "published")
                              .includes(:members, :challenge, hero_image_attachment: :blob)
                              .order(publication_updated_at: :desc, created_at: :desc)
```

If `Project.published` scope exists, use it instead of repeating
`where(status: "published")`.

## Design notes

- Public workshop detail should feel like a concise event page, not a dashboard.
- Keep the public detail centered on workshop context first, then participant
  outputs.
- Published project cards can be richer than authenticated draft cards because
  they are public portfolio entries: title, hero thumbnail, team, challenge, last
  updated.
- For visitors, the agenda absence should feel intentional. Avoid showing a
  disabled agenda button.
- For workshops with no published projects, use calm copy such as "Published
  projects will appear here after the workshop."

## Test reminders

- Add unauthenticated request tests for `/workshops` and `/workshops/:slug`.
- Keep or update existing tests that expected `/workshops` to require login.
- Add an unauthenticated request test proving `/workshops/:slug/agenda` still
  requires login.
- Add a visitor rendering test that creates both draft and published projects in
  a workshop and asserts only the published project appears.
- Add a signed-in participant test proving the spec 12 all-projects behaviour
  still appears.
- Add a workshop-with-no-published-projects test for the public empty state.
- Add locale-key coverage by relying on existing i18n test patterns if present.

## Open Questions

None after user follow-up on 2026-04-25.

## Implementation notes

- `WorkshopsController` now only requires login for `agenda`; `index` and
  `show` are public.
- Visitor workshop detail uses a dedicated public published-projects partial.
  It renders only `Project.published` records and does not call
  `editable_by?(current_user)` or expose draft cards.
- Signed-in workshop detail keeps the spec 12 `_projects` partial, including
  own-project highlighting, draft visibility rules, agenda link, and facilitator
  invitation affordance.
- Workshop index now shows a published-project count and hides agenda links for
  visitors.
- Request-a-spot and home-page surfaces were intentionally untouched to avoid
  colliding with `spec/7-home-page`.
- Verification: `bin/rails test test/controllers/workshops_controller_test.rb
  test/controllers/published_projects_controller_test.rb
  test/controllers/projects_controller_test.rb` and full `bin/rails test` both
  passed on 2026-04-25.
