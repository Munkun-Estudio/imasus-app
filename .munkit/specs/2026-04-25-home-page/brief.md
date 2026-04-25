# Spec 7 — Home Page

## What

Replace the current static visitor-only `/` view with a role-aware Home that
serves four audiences from a single route — **visitor**, **participant**,
**facilitator**, and **admin** — and ship the auth-aware chrome that the
existing layout still lacks: a sidebar **user menu** (replacing the locale
switcher's footer slot with a bottom-of-sidebar flyout) and a minimal
**`/settings`** page. The locale switcher relocates to the top-right of the
application layout so it remains reachable for visitors and authenticated
users alike.

This spec also retires the standalone `/admin/dashboard` placeholder: admins
see their dashboard at `/`. `MEMORY.md` already states that `/` is the only
role-aware surface; spec 7 makes that real.

## Why

After spec 12, the participant journey (workshop → project → log → publish)
is complete end-to-end, but participants still have no orientation surface —
the current `/` is a beta marketing-style page with no role awareness, and
nothing threads the journey together. The workshop projects section spec 12
shipped is contextual, not personal; participants returning to the app have
no "where am I, what's next" view.

The visitor home matters too: the IMASUS workshops are the deliverable of
roughly two years of work and are open to participants beyond the host
School. The current `/` defers to imasus.eu, which underrepresents what the
app actually contains. A workshop-centric public surface gives external
visitors a meaningful preview and a clear path to "Request a spot".

The auth chrome (user menu, settings, log out) is overdue: the sidebar today
has no log-out affordance and no settings entry, and the existing `/admin`
namespace only houses a stub dashboard. Bundling the menu, the settings page,
and the home rework keeps the touched surfaces coherent in one PR.

## Scope

### Model changes

Two new columns. Migrations are reversible; seeds updated.

#### `workshops.contact_email` (string, nullable)

- Migration: `add_column :workshops, :contact_email, :string`.
- Validation: format `URI::MailTo::EMAIL_REGEXP`, only when present
  (`allow_blank: true`). Optional — workshops without an email are valid.
- Seeds: set a reasonable contact email for each of the three seeded
  workshops (Greece, Italy, Spain). Exact addresses confirmed with the
  workshop teams during implementation; placeholder seed values acceptable
  until then.
- Editing UI: **out of scope for spec 7**. Values come from seeds. A real
  workshop edit surface lives on a future facilitator/admin tool.

#### `users.preferred_locale` (string, nullable)

- Migration: `add_column :users, :preferred_locale, :string`.
- Validation: `inclusion: { in: I18n.available_locales.map(&:to_s),
  allow_nil: true }`. Nil means "use default".
- Persists across sessions; surfaced and editable on `/settings`.

### Routes

```ruby
root "home#index"

resource :settings, only: [ :edit, :update ], controller: "settings"

# Removed:
# - namespace :admin do
#     root to: "dashboard#index"
#   end
```

- `GET  /`              — `home#index` (role-aware; one controller, four templates)
- `GET  /settings/edit` — `settings#edit`
- `PATCH /settings`     — `settings#update`
- `/admin` — `root` removed. `admin/dashboard_controller.rb` and
  `app/views/admin/dashboard/` are deleted. `admin/facilitators` routes are
  retained.

### Home — `HomeController#index`

Single action; the controller branches on `Current.user&.role` and renders
one of four partials/templates inside a shared layout. No separate controllers
per role.

```
app/views/home/
  index.html.erb         # router: chooses the partial below
  _visitor.html.erb
  _participant.html.erb
  _facilitator.html.erb
  _admin.html.erb
```

#### Visitor variant — `_visitor.html.erb`

Shown when `Current.user` is nil. Workshop-centric public surface.

1. **Hero band**
   - Heading and lead copy framing IMASUS workshops + imagineering. Authored
     copy, fully localised.
   - Two CTAs: **"See workshops"** anchor-scrolls to the workshops section
     below. **"Log in"** → `new_session_path`.

2. **Workshops section** — primary content of the visitor page.
   - All `Workshop` records. For each workshop card: title, location,
     partner, dates, short description, link to public workshop page
     (`workshop_path(slug:)`).
   - When `workshop.contact_email` is present, the card includes a
     **"Request a spot"** CTA — a `mailto:` link to that address. When
     `contact_email` is nil, the CTA is omitted (silent fallback). A
     follow-up `request-a-spot` spec may upgrade this CTA to a proper
     form per workshop; the `mailto:` is the MVP.
   - Empty state suppressed — workshops are seeded data, this section
     always renders.

3. **Featured published projects**
   - Up to 6 most-recently-published projects, scope:
     `Project.where(status: "published").order(publication_updated_at: :desc).limit(6)`.
   - Reuses the same project card used in the workshop projects section
     (spec 12) where possible. Each links to `published_project_path(slug:)`.
   - Empty state: a calm placeholder block ("Workshop projects appear here
     when participants publish their work") — no card.

4. **Public resources teaser**
   - Four link cards: Materials, Training, Glossary, Challenges. Each is a
     short description + link to the index. Visual hierarchy is calmer than
     the workshop and project cards above.

5. **Footer band (kept)** — the existing layout `_footer.html.erb`. No
   change in this spec.

#### Participant variant — `_participant.html.erb`

Shown when `Current.user.role == "participant"`. Personal dashboard threading
the project flow.

1. **Greeting line** — `t(".greeting", name: Current.user.name)`. Single
   line, calm.

2. **Project cards** — one card per `Current.user.projects`, ordered by
   `updated_at: :desc`. Each card shows:
   - Title, workshop name, challenge badge if linked, member initials,
     status chip (`Draft` / `Published`), "last activity" relative timestamp.
   - **Journey-state CTAs:**
     - Draft, no log entries: primary **"Add your first log entry"** →
       `new_project_log_entry_path(project)`. Secondary "Open project" →
       `project_path(project)`.
     - Draft, with log entries: primary **"Continue your log"** →
       `project_log_entries_path(project)`. Secondary **"Publish"** →
       `new_project_publication_path(project)`.
     - Published: primary **"View public page"** →
       `published_project_path(slug:)`. Secondary **"Edit publication"** →
       `edit_project_publication_path(project)`.

3. **Workshops strip** — compact list of `Current.user.workshops`. Each
   chip: workshop title + location, links to the workshop show page.
   Rendered above project cards when the participant has zero projects
   (so the "where do I start" path is foregrounded), below project cards
   otherwise.

4. **Empty state — no projects yet**
   - Workshops strip foregrounded with prompt: "Choose a workshop to start
     your first project." Each workshop chip becomes the entry point;
     project creation lives on the workshop show page (spec 12).
   - If the participant has no workshop participations either (edge case;
     they were invited but the join didn't land) — show a static "Your
     facilitator will set up your workshop access" line. Rare but possible
     during invitation flow gaps.

5. **Public resources teaser** — same four cards as the visitor variant,
   but rendered with reduced visual emphasis (smaller, single row) since
   the participant is here for their own work, not browsing.

#### Facilitator variant — `_facilitator.html.erb`

Thin — operational tooling lands in spec 13 (`facilitator-tools`).

1. **Greeting line.**
2. **Your workshops** — `Current.user.workshops` (via
   `workshop_participations`). For each workshop card:
   - Title, location, dates.
   - Counts: participants, draft projects, published projects. Single
     query per workshop is acceptable; no caching.
   - CTA: **"Invite participants"** → `new_workshop_invitation_path(workshop)`.
3. **Public resources teaser** — reused.

Out of scope here (deferred to spec 13): per-workshop participant lists,
project moderation, viewing all log entries, recent-activity feeds.

#### Admin variant — `_admin.html.erb`

Replaces `/admin/dashboard`. Modest dashboard — admin operational depth
remains in `/admin/...` namespaced routes.

1. **Greeting line.**
2. **All workshops** — every workshop (admins are not scoped). Same card
   shape as the facilitator variant: title, location, dates, counts.
3. **Quick links band:**
   - **"Manage facilitators"** → `admin_facilitators_path`.
   - **"All projects"** → `projects_path` (admin/facilitator-only after
     spec 12).
4. **Public resources teaser** — reused.

### Sidebar user menu

Replace the existing locale switcher footer slot in
`app/views/shared/_sidebar.html.erb` with a user-menu component.

#### Trigger (always at the bottom of the sidebar)

- Logged in: avatar (initials from `Current.user.name`, dark-green circle,
  white text) + display name + secondary line + caret indicator. Click
  toggles the flyout.
  - **Display name:** `Current.user.name` (single line, truncated).
  - **Secondary line:** `Current.user.institution` if present;
    otherwise the localised role label
    (`t("roles.#{Current.user.role}")`).
- Logged out: a single **"Log in"** link styled as a subdued footer item;
  no flyout, no avatar.

#### Flyout (logged-in only)

A bottom-of-sidebar flyout opening upward (UI pattern only — contents are
project-specific, do not copy verbatim from the screenshots).

- **Identity header:** `Current.user.email`. Single line, truncated. No
  workspace or role chrome.
- **Settings** → `edit_settings_path`.
- **Log out** → `button_to "...", session_path, method: :delete`. Styled as
  a flyout item visually, even though it is a button (semantic for
  accessibility).
- Dismiss behavior:
  - Click outside the flyout / sidebar.
  - `Escape` key.
  - Trigger button click toggles closed.
  - Focus returns to the trigger on close.
- Stimulus controller: `user_menu_controller.js` — `connect`, `toggle`,
  `close`, `documentClick`, `keyup` for Escape, focus management.

The flyout is visual chrome; no Profile link (deferred indefinitely until a
real public participant profile exists).

### Locale switcher — relocate to top-right of layout

- Remove the locale-switcher block from `_sidebar.html.erb`.
- Add a new top-right element in `application.html.erb`. Position: fixed
  or absolute in the top-right of the main content area (to the right of
  the sidebar), aligned visually with the page heading row.
- Same link list as today: `url_for(locale: loc)` per available locale,
  active locale highlighted.
- Visible to logged-in and logged-out users.
- Does not appear in `public.html.erb` (mailer/PWA layouts are unaffected).
- Implementation note: keep the existing `data-controller="locale-switcher"`
  attribute and Stimulus behaviour if any; only the position and surrounding
  markup change.

### Locale resolution (ApplicationController)

`ApplicationController#set_locale` (a new `before_action`) resolves
`I18n.locale` per request in this order:

1. `params[:locale]` if present and in `I18n.available_locales` — explicit
   override for this navigation only. Always wins.
2. `Current.user&.preferred_locale` if present and valid — the
   authenticated user's stored preference.
3. `I18n.default_locale` — fallback for visitors and users without a
   preference.

The top-right locale switcher is **one-shot**: it sets `params[:locale]`
for the current navigation but does not persist. Persistent locale
preference changes happen via `/settings` only. This keeps the switcher
predictable for users who want to peek at another language without
flipping their stored preference.

`default_url_options` continues to thread `locale:` through generated URLs
when an override is active, matching existing behaviour.

### `/settings` — minimal user settings page

Single resource controller; serves only logged-in users.

- `before_action :require_login` (or equivalent), redirect to
  `new_session_path` when unauthenticated.
- `edit` renders a single form. `update` saves.
- Form sections:
  1. **Account** — `name`, `email`. `email` re-validates uniqueness and
     format on update.
  2. **Password** — `current_password` (required if either of the next two
     are present), `password`, `password_confirmation`. Saving an empty
     password block leaves the password unchanged.
  3. **Profile** — `institution`, `country` (using the same select used in
     `participant_invitations#edit`), `bio`, `links` (textarea, free-form;
     wiring the schema column that registration does not yet expose).
  4. **Preferences** — `preferred_locale` select with the four available
     locales. A "System default" option (nil) is included for users who
     don't want a stored preference.
- Success: redirect to `edit_settings_path` with a localised flash.
- Failure: re-render `edit` with inline errors.
- All strings localised in en, es, it, el (en filled, others stubbed per
  the project's standing pattern).

The settings page is intentionally **single-page**; no tabs, no separate
password page. Four labelled sections in one form is enough for the MVP.

### I18n

- All copy across home variants, user menu, locale switcher (now in the
  layout), settings page, and flash messages goes through `t(...)`.
- English content authored. `es`, `it`, `el` files stubbed with English
  strings, marked `# TODO: translate` per project convention.
- The "Request a spot" `mailto:` address lives in a translation key so it
  can vary per locale if needed; default value common across locales until
  a workshop-team override is needed.

### Authorization summary

| Surface                     | Who                          |
|-----------------------------|------------------------------|
| `/` visitor variant         | Unauthenticated               |
| `/` participant variant     | `Current.user.participant?`  |
| `/` facilitator variant     | `Current.user.facilitator?`  |
| `/` admin variant           | `Current.user.admin?`         |
| `/settings/edit`, `/settings` | Any authenticated user      |
| Sidebar user menu (flyout)  | Any authenticated user        |
| Sidebar "Log in" link       | Unauthenticated only          |
| Locale switcher (top-right) | Everyone                       |

### Removed / changed

- `app/views/home/index.html.erb` — replaced (current static beta page).
- `app/views/shared/_sidebar.html.erb` — locale switcher removed; user-menu
  partial added.
- `app/views/layouts/application.html.erb` — top-right locale switcher
  added.
- `app/controllers/application_controller.rb` — `set_locale` before-action
  added with the resolution order described above.
- `app/controllers/admin/dashboard_controller.rb` and
  `app/views/admin/dashboard/` — deleted.
- `config/routes.rb` — `namespace :admin` no longer defines a `root`.
- `db/migrate/...add_contact_email_to_workshops.rb` — new migration.
- `db/migrate/...add_preferred_locale_to_users.rb` — new migration.
- `db/seeds.rb` (or workshop seed) — populates `contact_email` for the
  three seeded workshops.

## Out of Scope

- **Bookmarks** — separate spec (next). Participant home will gain a
  bookmarks section then.
- **Request-a-spot real flow** — separate spec. Visitor CTA in spec 7 is a
  `mailto:` placeholder.
- **Featured curation primitive** — featured published projects are simply
  the most recent N. No `featured` flag, no admin curation UI.
- **Profile pages** — no public participant profiles. The sidebar flyout
  has no Profile link.
- **Training progress tracking** — no per-user state; no "continue where
  you left off" affordance on home.
- **Workshop date awareness** — no "starts in N days" badges or
  pre/during/after behavioural changes on home.
- **Recent activity feeds** — no facilitator/admin "X published their
  project" stream.
- **Per-workshop facilitator scoping** — facilitator home shows their
  `workshop_participations`; cross-workshop visibility rules remain spec 13
  territory.
- **Sidebar collapse / mobile drawer** — the user menu must work in the
  existing responsive shell but no responsive redesign in this spec.
- **Profile picture upload** — avatar is initials only.
- **Locale switcher persistence** — the top-right switcher remains
  one-shot. Persistent locale preference changes via `/settings` only.
- **Workshop edit UI** — `workshop.contact_email` values come from seeds
  for spec 7. A real edit surface lives on a future facilitator/admin
  tool.
- **Recent activity feed** — no per-event activity strip on facilitator
  or admin home in spec 7. Synthesizable later from existing tables when
  the surface is built.
- **`/admin/facilitators` and friends** — these continue to work
  unchanged. Only `/admin/dashboard` is retired.

## Acceptance Criteria

### Routing & controller

- [ ] `GET /` renders the visitor variant when no user is signed in.
- [ ] `GET /` renders the participant variant for a participant user.
- [ ] `GET /` renders the facilitator variant for a facilitator user.
- [ ] `GET /` renders the admin variant for an admin user.
- [ ] `GET /admin` (`admin_root`) is removed; `/admin/facilitators` still
      reaches the facilitators index.
- [ ] No regressions on existing routes (`/workshops`, `/projects`,
      `/published/:slug`, etc.).

### Visitor home

- [ ] Renders a hero band with localised copy and two CTAs:
      "See workshops" (anchor scroll) and "Log in".
- [ ] Lists every seeded workshop with title, location, partner, dates,
      and short description; cards link to the public workshop page.
- [ ] A workshop card with `contact_email` set shows a "Request a spot"
      CTA pointing at `mailto:<contact_email>`.
- [ ] A workshop card without `contact_email` omits the "Request a spot"
      CTA without rendering broken markup.
- [ ] Renders up to 6 most-recently-published project cards linking to
      `/published/:slug`. With zero published projects, shows a localised
      placeholder, not an empty grid.
- [ ] Renders four public-resource teaser cards (Materials, Training,
      Glossary, Challenges).

### Participant home

- [ ] Greets the participant by name.
- [ ] Lists each of `Current.user.projects` as a card with title, workshop,
      challenge badge (if linked), member initials, status chip, and a
      relative-time "last activity" line.
- [ ] A draft project with **zero** log entries shows the
      "Add your first log entry" primary CTA.
- [ ] A draft project with **at least one** log entry shows
      "Continue your log" as primary and "Publish" as secondary.
- [ ] A published project shows "View public page" as primary and
      "Edit publication" as secondary.
- [ ] A participant with **zero** projects sees their workshops strip
      foregrounded with a "Choose a workshop to start your first project"
      prompt.
- [ ] A participant with no workshop participations sees a localised
      "Your facilitator will set up your workshop access" message; no crash.

### Facilitator home

- [ ] Lists `Current.user.workshops` with counts of participants, draft
      projects, and published projects per workshop.
- [ ] Each workshop card has an "Invite participants" CTA reaching the
      existing `new_workshop_invitation_path`.
- [ ] No moderation, participant-list, or activity-feed surfaces appear.

### Admin home

- [ ] Lists all workshops (not scoped to memberships) with counts.
- [ ] Has a "Manage facilitators" link reaching `/admin/facilitators`.
- [ ] Has an "All projects" link reaching `/projects`.
- [ ] `/admin/dashboard` no longer exists; old links are not present in
      the codebase.

### Sidebar user menu

- [ ] When logged out, the sidebar footer shows a "Log in" link in place
      of the user menu.
- [ ] When logged in, the trigger shows initials avatar, display name, and
      institution (or role label fallback).
- [ ] Clicking the trigger opens a flyout above the trigger with: email
      header, "Settings" link, "Log out" button.
- [ ] Pressing Escape closes the flyout and returns focus to the trigger.
- [ ] Clicking outside the flyout closes it.
- [ ] "Settings" navigates to `/settings/edit`.
- [ ] "Log out" issues a DELETE to `/session` and redirects per existing
      session controller behaviour.
- [ ] Flyout is keyboard-reachable (Tab into trigger, Enter/Space to open,
      Tab through items).

### Locale switcher

- [ ] Removed from `_sidebar.html.erb`.
- [ ] Present in the top-right of `application.html.erb` and visible on
      every authenticated and unauthenticated page using that layout.
- [ ] Active locale highlighted; clicking another locale navigates with
      `?locale=...` preserving the current path.
- [ ] Mailer and PWA layouts unaffected.

### `/settings`

- [ ] Unauthenticated requests redirect to the login page.
- [ ] Form renders four sections — Account, Password, Profile, Preferences
      — with values pre-populated from the current user.
- [ ] Updating name and email persists changes; email re-validates format
      and uniqueness.
- [ ] Updating with empty password fields leaves the password unchanged.
- [ ] Updating with a new password requires `current_password` and a
      matching `password_confirmation`; mismatches re-render with errors.
- [ ] Updating institution, country, bio, and links persists each value
      (`links` accepts a free-form text body).
- [ ] Updating `preferred_locale` persists the choice and the user's
      next request without `?locale=` resolves to the stored value.
- [ ] Selecting "System default" (nil) clears any stored preference.
- [ ] On success, redirects to `edit_settings_path` with a localised
      flash.

### Locale resolution

- [ ] `params[:locale]` always wins for the current request when valid.
- [ ] Without `params[:locale]`, an authenticated user with
      `preferred_locale` set sees the application in that locale.
- [ ] Without `params[:locale]` and without a stored preference, the
      application falls back to `I18n.default_locale`.
- [ ] Unknown / invalid locale params and stored values are ignored
      without raising.

### I18n

- [ ] All UI strings present in en, es, it, and el. Non-en files may carry
      English content with `# TODO: translate`, matching existing project
      practice.

## Dependencies

- Spec 8 (`authentication`) — `Current.user`, role enum, session controller.
- Spec 9 (`workshops`) — `Workshop`, `WorkshopParticipation`,
  `workshop_invitations`.
- Spec 10 (`projects-and-teams`) — `Project`, `ProjectMembership`,
  member resolution.
- Spec 11 (`process-log`) — `LogEntry` count for "draft, no log entries"
  branching.
- Spec 12 (`project-publication`) — `published?` predicate, slug,
  `publication_updated_at`, `published_projects_path`.

### Downstream

- **`bookmarks` (next spec, not yet numbered in the plan).** Adds a
  bookmarks section to the participant home and a "Bookmarks" link in the
  sidebar (likely above the user menu). New spec, not in `context.md`'s
  original 1–14 list.
- **`request-a-spot` (follow-up spec).** May upgrade the per-workshop
  `mailto:` CTAs to a real form per workshop, with persistence and a
  facilitator notification email. Also a new spec not in the original
  plan.
- **Spec 13 — `facilitator-tools`.** Builds on the thin facilitator home:
  per-workshop participant lists, project moderation, activity feed,
  workshop edit surface (which becomes the natural home for editing
  `workshop.contact_email`).
