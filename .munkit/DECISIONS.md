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
