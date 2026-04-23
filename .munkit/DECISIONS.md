# Decisions

Architectural decisions for this project. Append-only log.

Record decisions with: `munkit decide "Decision title"`

---

<!-- Decisions will be appended below -->

## 2026-03-27: Start from the default Rails 8 stack with PostgreSQL

The project needs the shortest path to a maintainable public foundation, and the Rails defaults already cover the application, background job, cache, and realtime primitives we expect to need first.

## 2026-03-27: Use git sources for Munkit gems in this public repository

This repository is meant to be public, so private GitHub Packages authentication would create friction for contributors and CI. Using public git sources keeps Munkit tooling available without changing the gem-based workflow.

## 2026-03-27: Use GitHub Project 6 for Symphony tracking

Symphony in this repository should target the GitHub Project at https://github.com/orgs/Munkun-Estudio/projects/6 unless the team explicitly changes tracker strategy later.

## 2026-04-16: Four locales from day one — en, es, it, el

All user-facing strings go through `t(...)` from the first feature. Locale files: en (base), es, it, el (Greek, ISO 639-1). Training module content is already structured per locale. Translatable model fields approach (suffixed columns vs JSONB) deferred to the spec that needs them first.

## 2026-04-16: Action Text (Trix) for log entries and published project pages

Rich text with embedded material cards and training module references. Students use a toolbar button to quote/embed materials and reference training passages. Structured fields are used for project metadata; Action Text is used for narrative content (log body, public page process summary).

## 2026-04-16: AWS S3 via Active Storage for image and media hosting

The IMASUS project already uses AWS for the newsletter. S3 is the storage backend for Active Storage. CDN and image optimisation strategy (CloudFront, imgproxy, or similar) to be decided in a dedicated spec before image-heavy features are built.

## 2026-04-16: Deploy to Fly.io with PostgreSQL

Fly.io as the production host for the Rails app with a managed PostgreSQL instance.

## 2026-04-16: Project is the central collaborative object

A Project belongs to a workshop, has one or more members (students), accumulates log entries, and can be published as a public page. The log belongs to the project, not the individual. No private notes. No separate "Team" model — the project's membership list is the team.

## 2026-04-16: Three roles — admin, facilitator, student

Admin creates facilitators. Facilitators create/manage workshops, invite students, and can moderate (disable students/projects). Students self-register via invitation link. No evaluation/grading features.

## 2026-04-16: Invitation-only student registration

Facilitator enters student emails → app sends invitation email with token link → student lands on registration form pre-associated with the workshop. No open self-registration.

## 2026-04-16: Visibility — open within workshop, published projects are public

Within a workshop, all participants see all projects but only edit their own. Published projects get a public URL visible to anyone without login. Materials, training modules, glossary, and challenges are public content.

## 2026-04-16: Adapt Rails agent skills from igmarin/rails-agent-skills (MIT)

10 skills lifted and adapted for Minitest + Munkit workflow, stored under `.munkit/skills/`. Attribution in NOTICE and README. See CLAUDE.md for the catalog.

## 2026-04-16: Use S3 proxy URLs and mini_magick for image variants

S3 matches the existing AWS footprint, proxy URLs keep the app CDN-ready, and mini_magick is the pragmatic processor choice for the current contributor/CI environment because ImageMagick is already available while vips is not.

## 2026-04-17: Translatable model fields — JSONB columns via a `Translatable` concern

All translatable model attributes (glossary terms, materials, challenges, and anything similar downstream) are stored as JSONB columns named `<attribute>_translations`, each holding `{ en: "...", es: "...", it: "...", el: "..." }`. A reusable `Translatable` concern exposes locale-aware readers backed by those columns, with `I18n.fallbacks` applied on missing keys. This supersedes the deferral in the 2026-04-16 "Four locales from day one" entry. Rejected alternatives: locale-suffixed columns (one column per locale per field — explodes as translatable fields grow across glossary, materials, and challenges; every new translatable field requires a migration per locale); the `mobility` gem (backend-swapping abstraction is unnecessary complexity when we know we want JSONB and have no intention of switching). First implementation lands in the glossary spec (spec 5); materials (spec 4) and challenges (spec 6) must reuse the same concern.

## 2026-04-21: Participant invitation form drops the password-confirmation field

In the participant invitation acceptance flow (`GET/PATCH /participant_invitations/:token/edit`), the registration form asks for a password once, not twice. The controller auto-copies `password` into `password_confirmation` in `participant_accept_params` when the confirmation is blank, so `has_secure_password`'s confirmation validation still passes. This applies **only** to the participant invitation flow, where the user is typing a brand-new password against a token that already proves ownership of the invitation email; asking participants to retype the password added friction without a meaningful safety benefit. The facilitator invitation form (`/facilitator_invitations/:token/edit`) and the password-reset edit form (`/password_resets/:token`) both still require explicit confirmation, because those flows are used by people who manage other users and the extra confirmation is worth the friction. If the flow ever needs to re-enable the confirmation field for participants, the relevant places are `app/views/participant_invitations/edit.html.erb` and the `participant_accept_params` helper in `app/controllers/participant_invitations_controller.rb`.

## 2026-04-17: Glossary curator UI — admin + facilitator, inline Turbo Frames

Admin and facilitator have symmetric CRUD rights on glossary terms (create, edit, delete any term). No approval workflow, no soft-delete, no audit log — we trust curators. Routing reuses a single `resources :glossary_terms` surface with role-guarded actions; no separate `/admin/glossary` namespace. Role-gated affordances (Add / Edit / Delete buttons) render on the public `/glossary` and `/glossary/:slug` pages, invisible to participants and unauthenticated visitors. Edit and delete are inline via Turbo Frames (each term row is a frame; Edit swaps to a form in place). Create uses a dedicated `/glossary_terms/new` page because the 4-locale × multi-field form is too tall to fit inline without disrupting the index layout. Delete confirmation is a Turbo modal (not `data-turbo-confirm`), consistent with the app's calm/editorial tone and providing an accessible confirm dialog. The multi-locale form uses **locale tabs**: the user's current `I18n.locale` is the default-active tab and sits first in the tab order; the remaining locales follow the fixed `en → es → it → el` sequence, skipping whichever is current. Unsaved changes in inactive tabs are preserved while editing.

## 2026-04-22: Sidebar information architecture — Hub + Workshops + Resources

The sidebar is restructured from a flat 7-item paint-chip into a semantic layout with three zones:

- **Hub:** `00 Home` (white / bordered swatch).
- **Community:** `01 Workshops` (dark-green).
- **Resources** (group, with small-caps label): `02 Materials` (light-blue), `03 Training` (navy), `04 Challenges` (mint, new), `05 Glossary` (light-pink).

`Log` and `Prototype` are dropped as top-level items: log entries live inside a project, and publishing is a phase of a project (not a separate surface). Published projects surface via the Workshops index and the public Home's featured strip.

Palette changes from spec 1: Materials moves from red to light-blue (red was too bold for a resource item). Red is no longer used in the sidebar; it stays reserved as an accent (per `context.md` brand guidance). Mint moves from the now-dropped Prototype slot to the new Challenges slot.

This change ships with spec 6 (`challenge-cards`) because adding Challenges is what forced the IA rethink. Rejected alternative: a standalone IA-refactor spec — cleaner diff but would have left `challenge-cards` momentarily wedged into the old 7-swatch layout.

## 2026-04-22: Drop "Prototype" as a product noun — use "Project" / "Published project"

`Prototype` was a placeholder sidebar item with no model, route of substance, or spec behind it. The verb for publishing is **publish a project**; the noun for the result is **published project** (not "published page", not "published prototype"). Applies to UI copy, i18n keys, route names, and any `Project` lifecycle flags added in specs 10–12. The generic word "prototype" is still fine in training-module content, where it is used in the imagineering/design-research sense (e.g. "prototype a solution") — this decision is about the product-object vocabulary, not the domain vocabulary.

## 2026-04-22: Home is role-aware — visitor landing vs. participant dashboard

`/` is a single surface whose content differs by role:

- **Unauthenticated visitor:** marketing-ish landing (prompt cards, featured material, training carousel, CTAs, featured published projects).
- **Participant:** personal dashboard threading the project flow — create team, start project, select challenge, add log entries, publish project. Surfaces active projects, drafts, and quick entry points.
- **Facilitator / admin:** role-specific dashboards (managed workshops, participant invitations, moderation levers).

No separate "Dashboard" sidebar item. The sidebar stays the same for everyone; Home re-renders per role. This collapses the "Your work" surface the earlier seven-swatch layout was implicitly reserving and lets the sidebar stay at six items regardless of auth state. Dashboard scope lands in spec 7 (`home-page`), which is widened to cover all role variants rather than only the visitor landing.

## 2026-04-22: Challenges are read in a sidebar drawer — no standalone show page

Challenges are short (code + category + question + description) and are meant to be skimmed, not navigated. A dedicated show page adds a back-and-forth that's tedious for a list of ten.

- No `GET /challenges/:code` show route. The card's main click target is `GET /challenges/:code/preview`, which renders into the layout-level `<turbo-frame id="preview">` slot (reusing the materials preview sidebar pattern: `preview_sidebar_controller`, Escape/backdrop to close, `aria-modal="false"`).
- No preview eye-icon — the whole card is the click surface.
- Curator's "Edit" button inside the drawer breaks out with `data-turbo-frame="_top"` and uses the standalone `/challenges/:code/edit` page (inline card-swap on the index still works via the `Edit` button on each card).
- Deep-linking to a single challenge is deferred. Projects (spec 10) and published projects (spec 12) link to the index + drawer rather than to a dedicated URL; if a shareable per-challenge URL becomes necessary, we revisit with a server-rendered "index with drawer open" response.

Rejected alternatives:
- Keep show page + add a preview drawer: two surfaces for the same content, duplicate copy maintenance.
- Eye-icon preview (materials pattern copied verbatim): materials have a heavy show page (gallery, supplier, sensorials, tags) that justifies the two-tier read; challenges don't.

---

## 2026-04-23 — Spec 10: Projects and teams

### Multi-membership per workshop
A user can belong to multiple projects within the same workshop. Rationale: participants rethink framing mid-workshop; rigid "one project per user" would block legitimate reshaping or force deleting history. Unique constraint is on `(project_id, user_id)`.

### Members-equal, no owner role
`ProjectMembership` carries no role column. All members are equal editors (`editable_by?`). If a creator/owner concept becomes necessary later, add a `role` column to the join table rather than a separate `created_by_id` on `Project`.

### Flat routes, numeric ID
`/projects/:id` rather than nested under workshop. Matches materials/challenges. Spec 12 (publication) will introduce a public slug; until then numeric id is fine and the slug decision hasn't been made.

### Single language per project
Project content is authored once in one language (defaulted from `workshop.communication_locale`). No locale-tabbed authoring as used for challenges/glossary — project text is team-authored, not curated.

### Facilitator draft access is workshop-agnostic for MVP
`Project#visible_to?` grants all facilitators read access to all draft projects until spec 13 adds per-workshop facilitator assignment. This is a deliberate shortcut recorded here so spec 13 can tighten it cleanly.

### Last-member destroy via after_destroy callback
When the final `ProjectMembership` is destroyed, an `after_destroy` callback on the join model destroys the project. Chosen over a model-level callback on `Project` to keep the invariant close to the triggering action. No soft-delete — draft projects are cheap to recreate.
