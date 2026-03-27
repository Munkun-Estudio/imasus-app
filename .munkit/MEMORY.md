# Project Memory

Context that AI agents should know when working on this project.
Edit this file as you learn things worth preserving across sessions.

## Overview

IMASUS App is the student-facing workshop application for the IMASUS project. It supports imagineering-based learning and solution development, helping students and facilitators work through large challenges in a structured, collaborative, and reflective way.

## Key Patterns

- Prefer standard Rails conventions and built-in primitives before adding gems or external services.
- Use Munkit specs to frame non-trivial product, workflow, or architectural changes before implementation.
- Keep the UI accessible, calm, and workshop-friendly rather than dashboard-heavy or startup-generic.
- Keep pull requests small, reviewable, and explicit about what changed, how it was tested, and what remains open.

## Gotchas

- `munkit` is a gem dependency in this repo, not just a globally installed CLI.
- This repository is intended to be public, so Munkit tooling is sourced from public git repositories instead of private package feeds.
- The project license is intentionally undecided for now; do not invent one.

## Terminology

- Imagineering: the Diane Nijs-inspired approach used in IMASUS workshops to connect imagination, experience design, and challenge-led innovation.
- Challenge: a large social, civic, or systemic problem that workshop participants are working to understand and address.
- Facilitator: the teacher, mentor, or organizer guiding students through the workshop process.
- Workshop cycle: the structured sequence of activities that moves a cohort from exploration to concept development.

## Tech Stack

- Ruby 3.4.7
- Rails 8.1 with PostgreSQL
- Hotwire with Importmap
- Solid Queue, Solid Cache, and Solid Cable
- Munkit and Munkit Symphony as development workflow tooling

## Boundaries

- Do not add uncommon dependencies without a clear need and explicit justification.
- Do not choose a license, deployment target, or product direction details that the team has not confirmed yet.
- Do not treat placeholder workshop copy or landing page content as final product content.
