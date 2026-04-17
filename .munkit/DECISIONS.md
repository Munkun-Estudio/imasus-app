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

## 2026-04-17: Glossary curator UI — admin + facilitator, inline Turbo Frames

Admin and facilitator have symmetric CRUD rights on glossary terms (create, edit, delete any term). No approval workflow, no soft-delete, no audit log — we trust curators. Routing reuses a single `resources :glossary_terms` surface with role-guarded actions; no separate `/admin/glossary` namespace. Role-gated affordances (Add / Edit / Delete buttons) render on the public `/glossary` and `/glossary/:slug` pages, invisible to participants and unauthenticated visitors. Edit and delete are inline via Turbo Frames (each term row is a frame; Edit swaps to a form in place). Create uses a dedicated `/glossary_terms/new` page because the 4-locale × multi-field form is too tall to fit inline without disrupting the index layout. Delete confirmation is a Turbo modal (not `data-turbo-confirm`), consistent with the app's calm/editorial tone and providing an accessible confirm dialog. The multi-locale form uses **locale tabs**: the user's current `I18n.locale` is the default-active tab and sits first in the tab order; the remaining locales follow the fixed `en → es → it → el` sequence, skipping whichever is current. Unsaved changes in inactive tabs are preserved while editing.
