# Notes: 2026-04-25-home-page

Scratch space and decision rationale for spec 7. Brief is the contract;
this file is the journal.

> **Numbering note.** The original plan in `context.md` numbers specs 1–14
> by *slot* — each number is bound to a specific feature (spec 7 =
> home-page, spec 8 = authentication, …). New specs not in that plan
> (bookmarks, request-a-spot) are referred to **by slug only** in this
> file. They will get plan numbers when added to `context.md`'s list.

---

## How this spec ended up at this scope

The original plan listed `home-page` as a single spec. During discussion
three adjacent features surfaced that the user wants but that don't all
fit cleanly together:

1. **Bookmarks** — touches materials, training, glossary, challenges, plus
   the participant home.
2. **`/settings` page + sidebar user menu / log-out affordance.**
3. **Public "Request a spot" flow** — initially conceived as a form +
   persistence + facilitator email; reframed during discussion as a
   per-workshop contact email.

Considered bundling all three into spec 7. Rejected because:

- The PR would be sprawling and contradict the "small, reviewable PRs"
  guideline in `CLAUDE.md`.
- Bookmarks alone is a foundational, multi-surface feature with its own
  shape (polymorphic association, toggle UI on four resource pages, an
  index).
- Request-a-spot's full flow (form + persistence + email) would entangle
  the home page with public-form mechanics that deserve their own spec.

Final breakdown:

- **Spec 7 (this one):** Home (4 variants) + sidebar user menu + locale
  relocation + locale persistence + `/settings` + `Workshop#contact_email`
  with per-workshop `mailto:` CTAs.
- **`bookmarks` (next, slug only):** Bookmark model, toggle UI on
  resources, `/bookmarks` index, integrate into participant home.
- **`request-a-spot` (follow-up, slug only):** May upgrade per-workshop
  `mailto:` CTAs to a real form with persistence and a facilitator
  notification email.
- **Spec 13 (in the original plan): `facilitator-tools`** — moderation,
  per-workshop scoping, activity feed, workshop edit surface (which
  becomes the natural home for editing `workshop.contact_email`).

The user menu, settings, and locale relocation stayed inside spec 7
because:

- The home rework requires a log-in/log-out affordance to make sense; the
  sidebar today has none.
- `/settings` is small (one page, one form, fields already in the schema
  except `preferred_locale`) and naturally pairs with the user menu's
  "Settings" entry.
- The locale switcher had to move once the user menu took its slot, and
  the new top-right placement is layout work, not a separate feature.

---

## Decision log

Choices we weighed during the discussion, recorded so a later reader can
understand *why* the brief looks the way it does. The "✅" entries are the
chosen options.

### "Request a spot" CTA — placement and mechanism

Original framing: a single hero CTA on the visitor home routing to a
`mailto:` (with the address held in a translation key so it could vary by
locale).

User pushed back: the per-locale framing was the wrong axis. Workshops
are run by different teams in different countries; the right axis is
**per workshop**, not per locale.

- (a) ~~Hero `mailto:` with a per-locale translation key.~~ Rejected.
- (b) ~~Tiny inline form in spec 7 emailing a fixed address.~~ Rejected
  earlier — halfway work that a future request-a-spot spec throws away.
- (c) ~~Full request-a-spot flow bundled into spec 7.~~ Rejected — bloats
  spec 7.
- (d) ✅ **`Workshop#contact_email` field; per-workshop `mailto:` CTA on
  each workshop card on the visitor home.** Chosen. Honest, scopes per
  workshop, and gives the visitor home a clear primary action.
- (e) ✅ **Hero CTA simplified.** "Request a spot" removed from the hero;
  the hero now offers "See workshops" (anchor scroll) + "Log in". The
  call to action lives on the workshop cards.
- (f) ✅ **No workshop edit UI in spec 7.** Values come from seeds; a real
  edit surface lives in spec 13 (facilitator-tools) or later.

### Locale persistence — store on `users` or stay URL-driven?

- (a) ~~URL-driven only; no `preferred_locale` column.~~ Rejected — the
  user wants persistence so a returning visitor lands in their language
  without a query param.
- (b) ✅ **`users.preferred_locale` column; surfaced in `/settings`;
  resolved by `ApplicationController#set_locale`.** Chosen. Clean,
  scoped, no UI fork.

Locale resolution order: `params[:locale]` (one-shot override) →
`Current.user&.preferred_locale` → `I18n.default_locale`.

The top-right locale switcher remains **one-shot**: clicking a locale
sets `?locale=…` for the navigation but does not persist. Users wanting
to flip their stored language go to `/settings`. This keeps the switcher
predictable for users who want to peek without committing.

### Avatar — initials vs uploaded image

- ✅ **Initials only.** Confirmed. Profile pictures aren't planned. If
  they become a feature, the avatar component should accept an attachment
  and fall back to initials.

### Recent activity feed — in spec 7 or deferred?

- (a) ~~Add a 5–10 item activity strip to facilitator + admin home.~~
  Synthesizable from `Project.created_at`,
  `Project.publication_updated_at`, `LogEntry.created_at`. No new model.
- (b) ✅ **Defer.** The user agreed to keep spec 7 thin on the
  facilitator/admin side. Activity ships in spec 13
  (`facilitator-tools`) where moderation and participant lists live.

When activity does ship, it's per-event lines (project created /
published / log entry added) — not log-entry content. That's
synthesizable without an `Activity` model; revisit when spec 13 lands.

### Profile link in the user-menu flyout — drop / build / defer

- (α) ✅ **Drop the link entirely.** Chosen. We have no profile pages
  today and "Settings" already covers self-edit.
- (β) ~~Ship a minimal read-only profile page in spec 7.~~ Rejected —
  extra surface, no current consumer.
- (γ) ~~Defer indefinitely.~~ Same outcome as α.

Revisit when project member avatars become clickable, or when public
participant profiles become a feature.

### Secondary line under the user's name

- (i) ✅ **Institution** with role-label fallback. Already collected at
  registration; closest analog to "workspace" in the reference UI; falls
  back to `t("roles.<role>")` when missing (admins and seeded users).
- (ii) ~~Role only.~~ Rejected, internal-jargon-flavoured.
- (iii) ~~Workshop name.~~ Rejected, breaks for multi-workshop
  participants and for admins.
- (iv) ~~Name only.~~ Rejected, the trigger feels thin without a
  secondary line.

### Locale switcher — where does it go?

- ✅ **Top-right of the application layout.** Picked by the user against
  my initial recommendation to keep it in the sidebar above the user
  menu. Reasons: cleaner sidebar footer, well-understood location, single
  surface for everyone.
- ~~Sidebar above user menu.~~ Crowded.
- ~~Inside the user-menu flyout only.~~ Invisible to logged-out visitors.
- ~~`/settings` only.~~ Same problem.

Implementation note: preserve the existing
`data-controller="locale-switcher"` attribute and any Stimulus behaviour;
only the position and surrounding markup change.

### `/admin/dashboard` — delete or alias?

- ✅ **Delete.** The current `Admin::DashboardController#index` is a stub
  and the matching view is a placeholder. Aliasing would preserve a route
  nobody links to. If a downstream concern surfaces an incoming bookmark,
  add a redirect later.

One-way door noted.

### `/settings` — single page vs tabs

- ✅ **Single page, four labelled sections** (Account / Password /
  Profile / Preferences). Tabs are nicer at scale but premature for ~8
  fields.

### Featured published projects — curation primitive?

- ✅ **No curation.** Featured = most recent 6, scope
  `Project.where(status: "published").order(publication_updated_at: :desc).limit(6)`.
  Adding a `featured` boolean or curation model is editorial-CMS scope
  creep.

### Home controller structure — one controller, four templates

- ✅ **One controller, four partials.** `HomeController#index` branches
  on `Current.user&.role`. Considered four separate controllers; rejected
  because roles are mutually exclusive and shared chrome reuses easily as
  partials.

### Number cap on featured published projects

Picked **6** to fit a 2x3 or 3x2 grid. Could be 4 or 8. Not load-bearing.

---

## Things to verify during implementation

- `grep -rn 'admin_root\|admin/dashboard'` before deleting the controller
  and view; confirm no callers.
- Confirm the existing `data-controller="locale-switcher"` still resolves
  once the markup moves into `application.html.erb`.
- The `links` column on `users` is currently unused by the registration
  form. Settings will be the first writer. Confirm format expectations
  with the user (free text? newline-separated? JSON?). Leaning free
  textarea, stored raw.
- `Current.user.workshops` for facilitators — see open question below.
- Counts for facilitator/admin workshop cards (`participants_count`,
  `draft_projects_count`, `published_projects_count`): one query per card
  is acceptable for current scale. Revisit only if N+1 shows up on real
  data.
- `_user_menu` partial position in the sidebar must stay below the nav
  list and not interfere with the existing scroll region
  (`overflow-y-auto`). The flyout anchors above the trigger and must not
  be clipped by the sidebar's own overflow.
- `default_url_options` — confirm whether the project already threads
  `locale` through generated URLs. If not, the `set_locale` change should
  not introduce a regression in URL generation.
- Seed values for `workshops.contact_email` — confirm with the user
  whether to use real addresses or placeholders pending workshop-team
  confirmation.

---

## Open questions to revisit

Only one genuinely open question remains:

- **Workshop membership model fitness for facilitators.** If a facilitator
  manages a workshop without participating, the current
  `WorkshopParticipation` join may be wrong. The user agreed to **defer
  this** — re-check when spec 13 (`facilitator-tools`) defines facilitator
  scoping more precisely. Spec 7 assumes a single
  `WorkshopParticipation` join for all roles, matching how spec 9 left
  things.

---

## Out-of-spec markers to leave in code

So follow-up specs can find the seams cleanly:

- The participant home where bookmarks will land: leave a
  `<%# TODO(bookmarks): bookmarks section here %>` placeholder so the
  follow-up spec has an obvious anchor.
- The per-workshop `mailto:` CTA on visitor workshop cards: leave a
  `<%# TODO(request-a-spot): consider replacing with a real form %>`
  comment so a future spec knows where the upgrade path lives.

---

## Implementation findings (recorded post-implementation)

Things worth preserving once the spec was actually built:

- **`current_user`, not `Current.user`.** The brief used `Current.user`
  when describing the role branch. The project's actual helper is
  `current_user` on `ApplicationController`. Implementation used the
  real helper; the brief copy is stale on that one detail.
- **`set_locale` integrates with the existing cookie path.** The brief
  lists three resolution sources (params, preferred_locale, default).
  Reality has four — the existing visitor cookie sits between
  preferred_locale and default. Cookie writes only happen when the
  request carries an explicit `?locale=` param now, so a stored
  preference is no longer silently overwritten.
- **`admin_root_path` had real callers.** Removing the admin namespace
  root broke `FacilitatorInvitationsController#update` (redirect
  target) and four tests. The redirect is now `root_path` (the
  role-aware home), tests that wanted "a protected admin-only page"
  switched to `admin_facilitators_path`.
- **N+1s caught in self-review.**
  - Visitor `Project.published` collection didn't eager-load
    `:workshop` even though the cards render `project.workshop.title`.
    Fixed by adding `.includes(:workshop)`.
  - Facilitator + admin workshop cards filtered the
    eager-loaded `:projects` collection with
    `workshop.projects.where(status: "draft").size`. The `.where` issues
    a fresh query each call. Switched to
    `workshop.projects.count { |p| p.status == "draft" }`, which uses
    the loaded array.
- **`User#current_password` virtual attr.** The settings form needs to
  re-render after a failed password change. Without
  `attr_accessor :current_password`, the form helper would raise
  trying to read the attribute back. The accessor is documented as
  transient.
- **i18n strategy for it/el.** Italian and Greek carry English
  placeholders for longer copy under the new keys, with a TODO comment
  flagging the section for the country teams. Spanish is fully
  translated. This matches the brief's I18n acceptance criterion.

---

## TDD / workflow reminders

Per `CLAUDE.md` the order is **Tests → Implementation → YARD → Docs →
Self-review (`rails-code-review`) → PR**. The spec is large enough that
the test plan should walk variant by variant — controller test for each
role, system tests for the user-menu interaction, integration tests for
`/settings`, locale resolution unit / integration tests, and at minimum a
routing test confirming `/admin/dashboard` no longer responds.

Testing notes:

- Use Minitest (project default).
- Stimulus user-menu interactions: prefer system tests with the existing
  Capybara setup. If headless flake shows up, fall back to asserting DOM
  attributes set by the controller (e.g. `aria-expanded`).
- Locale resolution: drive through controller / integration tests with
  fixtures or factory helpers covering (a) URL param wins, (b) stored
  preference applies in absence of param, (c) invalid params/values fall
  through silently, (d) default fallback for visitors.
- Seed-driven fields (`workshops.contact_email`) should be exercised by
  fixtures rather than relying on `db/seeds.rb` execution in test runs.

---

## Open Questions

(Populated above under "Open questions to revisit".)

## Ideas

(Populated above under "Out-of-spec markers" and "Things to verify".)

## Research

(Populated above under "Decision log".)
