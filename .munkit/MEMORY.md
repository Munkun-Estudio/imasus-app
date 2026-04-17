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
- Multi-locale forms use a locale-tabs pattern: current `I18n.locale` is default-active and first in tab order; remaining locales follow the fixed `en → es → it → el` sequence. Panels stay in the DOM so unsaved input in inactive tabs is preserved.

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
- Published page: a Behance-style public case study summarising a project's process and results.

## Tech Stack

- Ruby 3.4.7
- Rails 8.1 with PostgreSQL
- Hotwire with Importmap
- Solid Queue, Solid Cache, and Solid Cable
- Munkit and Munkit Symphony as development workflow tooling
- See `DECISIONS.md` for confirmed stack additions (Action Text, S3, Fly.io, etc.)

## Boundaries

- Do not add uncommon dependencies without a clear need and explicit justification.
- Do not choose a license or product direction details that the team has not confirmed yet.
- Do not treat placeholder workshop copy or landing page content as final product content.
- Evaluation/grading of prototypes is explicitly out of scope.
- No in-app notifications — transactional emails only (registration, password recovery, invitation).
