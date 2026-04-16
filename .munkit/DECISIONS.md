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
