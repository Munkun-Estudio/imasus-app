# Project Memory

Context that AI agents should know when working on this project.
Edit this file as you learn things worth preserving across sessions.

## Overview

IMASUS App is the participant-facing workshop application for the IMASUS project. It supports imagineering-based learning and solution development, helping participants (students and young professionals) and facilitators work through large challenges in a structured, collaborative, and reflective way.

## Key Patterns

- Prefer standard Rails conventions and built-in primitives before adding gems or external services.
- Use Munkit specs to frame non-trivial product, workflow, or architectural changes before implementation.
- Keep the UI accessible, calm, and workshop-friendly rather than dashboard-heavy or startup-generic.
- Keep pull requests small, reviewable, and explicit about what changed, how it was tested, and what remains open.
- All user-facing strings go through `t(...)` from day one. Four locales: en, es, it, el.
- Action Text (Trix) for rich content in log entries and published project pages. Material/training embeds via toolbar buttons.
- Translatable model fields use JSONB columns named `<attribute>_translations` backed by the `Translatable` concern. Reuse the concern for every translatable model (glossary, materials, challenges). See DECISIONS.md (2026-04-17).
- Turbo-modal confirmation pattern: layout exposes a top-level `<turbo-frame id="modal">`; a dedicated GET action renders a partial wrapped in that frame. Cancel/backdrop/Escape dismiss via `modal_controller.js`. Prefer this over `data-turbo-confirm` for accessible, styled confirmations.
- Overlay slots: `application.html.erb` carries two layout-level Turbo Frame slots — `modal` (confirm-and-dismiss flows, e.g. glossary delete) and `preview` (peek-and-dismiss flows, e.g. material preview sidebar). Both dismiss by clearing `innerHTML`; their respective Stimulus controllers (`modal_controller`, `preview_sidebar_controller`) handle Escape, backdrop click, and focus restore. Add a new slot only when the interaction semantics differ meaningfully — otherwise reuse. Links inside a slot that should navigate the full page need `data-turbo-frame="_top"` to break out of the frame.
- Multi-locale forms use a locale-tabs pattern: current `I18n.locale` is default-active and first in tab order; remaining locales follow the fixed `en → es → it → el` sequence. Panels stay in the DOM so unsaved input in inactive tabs is preserved.
- Team membership model (spec 10): `ProjectMembership` is role-less — all members are equal editors. `Project#editable_by?` grants write access to members + admins; facilitators get read-only via `visible_to?`. Destroying the last `ProjectMembership` auto-destroys the project via an `after_destroy` callback. Language defaults to `workshop.communication_locale` via `after_initialize`.
- Sidebar information architecture (post spec 6): three zones — **Hub** (`00 Home`, white), **Community** (`01 Workshops`, dark-green), and **Resources** group with small-caps label (`02 Materials` light-blue, `03 Training` navy, `04 Challenges` mint, `05 Glossary` light-pink). Red is reserved as a sparingly-used accent, not used in the sidebar. The sidebar is identical for all roles; Home (`/`) is the only role-aware surface. See `DECISIONS.md` (2026-04-22) for rationale.
- Materials Drive asset nomenclature: SMEs author material media in Drive with one folder per material (e.g. `Lifematerials-Kapok/`, `Pyratex-Musa-1/`). Folder name lowercased equals `Material#slug`. Inside: `<Folder>.png|jpg` is the macro (hero); `<Folder>-m1`…`-mN.tif|jpg` are microscopies ordered from max-zoom (`m1`) to min; `<Folder>.mp4` is the video. Pre-processing before import: TIF/PNG → JPG, downscale macros to 3000–4000 px, microscopies to 2000–3000 px, then ImageOptim. The repo task `material_assets:prepare` writes an importer-ready mirror with the same folder/file basenames; `material_assets:import` attaches that processed tree. Originals stay on Drive.

## Gotchas

- `munkit` is a gem dependency in this repo, not just a globally installed CLI.
- This repository is intended to be public, so Munkit tooling is sourced from public git repositories instead of private package feeds.
- The project license is intentionally undecided for now; do not invent one.
- Greek locale code is `el` (ISO 639-1), not `gr`.

## Terminology

- Imagineering: the Diane Nijs-inspired approach used in IMASUS workshops to connect imagination, experience design, and challenge-led innovation.
- Challenge: one of 10 industry challenges (C1–C10) used to focus team work during workshops.
- Participant: a workshop attendee — a student or young professional. The `:participant` role covers both groups. Do not use "student" as a role name in code or UI.
- Facilitator: the teacher, mentor, or organizer guiding participants through the workshop process.
- Workshop: a physical event (Greece, Italy, or Spain) with pre/during/after digital activity in the app.
- Project: the central collaborative object — created by a participant, optionally with team members, accumulates log entries, and culminates in a published public page.
- Published project: a Behance-style public case study summarising a project's process and results. The verb is "publish a project"; do not use "published page" or "published prototype".

## Tech Stack

- Ruby 3.4.7
- Rails 8.1 with PostgreSQL
- Hotwire with Importmap
- Solid Queue, Solid Cache, and Solid Cable
- Munkit and Munkit Symphony as development workflow tooling
- See `DECISIONS.md` for confirmed stack additions (Action Text, S3, Fly.io, etc.)

## Deployment

- Production target is Fly.io app `imasus-app` in `cdg` (Paris; closest available EU region to Spain), reachable first at `https://imasus-app.fly.dev`.
- Continuous deployment runs from GitHub Actions on pushes to `main` via `flyctl deploy --remote-only` and requires the repository secret `FLY_API_TOKEN`.
- Production uploads use a private Tigris bucket through Active Storage's S3-compatible `amazon` service. Tigris secrets are set by `flyctl storage create`; the app accepts Fly's `BUCKET_NAME` and AWS-style `AWS_S3_BUCKET`.
- Initial Fly launch uses `ACTIVE_JOB_QUEUE_ADAPTER=async` and does not set `SOLID_QUEUE_IN_PUMA` because the production Solid Queue tables still need explicit schema provisioning.
- Fly sets the primary `DATABASE_URL`; production `cache`, `queue`, and `cable` database configs fall back to that same URL unless `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, or `CABLE_DATABASE_URL` are explicitly provided later.

## Boundaries

- Do not add uncommon dependencies without a clear need and explicit justification.
- Do not choose a license or product direction details that the team has not confirmed yet.
- Do not treat placeholder workshop copy or landing page content as final product content.
- Evaluation/grading of projects is explicitly out of scope.
- No in-app notifications — transactional emails only (registration, password recovery, invitation).
