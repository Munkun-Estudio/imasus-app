# imasus-app — Claude Code Instructions

This file is the entry point for AI coding agents working on this repository. It is complemented by [`AGENTS.md`](AGENTS.md), which documents the Munkit workspace protocol used for durable project context. Read `AGENTS.md` before making product- or architecture-shaping changes.

This project is developed in the open as a deliverable of an EU-funded initiative. Rigor and traceability matter: prefer small, reviewable changes; explain the *why* in commit messages; and keep the workflow below reproducible for external contributors.

---

## CROSS-CUTTING MANDATE: Tests Gate Implementation

**THIS IS NON-NEGOTIABLE AND APPLIES TO EVERY SKILL THAT PRODUCES CODE.**

**WORKFLOW:** Munkit Spec → TESTS → IMPLEMENTATION → YARD → DOCS → CODE REVIEW → PR

Tests are a **gate**. Implementation code **cannot** be written until:

1. The test **exists** (written and saved).
2. The test has been **run**.
3. The test **fails for the right reason** (feature missing, not a typo or setup error).

Only after all three conditions are met may implementation code be written. After the implementation passes, document the public Ruby API with YARD, update any affected docs (README, diagrams, spec notes), then self-review with `rails-code-review` before opening the PR.

**Why this matters:**

- A test that passes immediately proves nothing — you don't know if it tests the right thing.
- A test you never saw fail could be testing existing behaviour, not the new feature.
- Implementation written before the test is biased by what you built, not by what was required.

**Test framework:** this project uses **Minitest** (Rails default). When adapting guidance that references RSpec, translate idioms to Minitest; do not introduce RSpec.

---

## Workflow — From Spec to PR

1. **Munkit Spec.** Start from (or create) a spec under `.munkit/specs/<slug>/`. Read `brief.md` and `notes.md`. See `AGENTS.md` for the Munkit protocol.
2. **Tests.** Write the failing test(s). Run them. Confirm they fail for the right reason.
3. **Implementation.** Write the minimum code to pass the test. Refactor under green.
4. **YARD.** Document public Ruby classes and methods. Output in **English** unless the spec explicitly calls for another language.
5. **Docs.** Update README, diagrams, and spec `notes.md` with anything worth preserving.
6. **Code review.** Self-review with the `rails-code-review` skill. Chain other review skills below as applicable.
7. **PR.** Open a pull request. Link the spec. Summarise the *why*.

---

## Rails Code Quality Skills

When a task matches the "Use when" column, **read the corresponding `SKILL.md` file before acting** and follow its guidance. Skills live under `.munkit/skills/` so they are available to both Claude Code and Codex.

| Skill | Use when… | Location |
| --- | --- | --- |
| `rails-code-conventions` | Daily coding checklist: DRY / YAGNI / PORO / CoC / KISS; linter as style SoT; per-path rules | `.munkit/skills/rails-code-conventions/SKILL.md` |
| `rails-stack-conventions` | Writing new Rails code for the PostgreSQL + Hotwire + Tailwind stack | `.munkit/skills/rails-stack-conventions/SKILL.md` |
| `rails-migration-safety` | Planning or reviewing database migrations | `.munkit/skills/rails-migration-safety/SKILL.md` |
| `rails-security-review` | Checking auth, params, XSS, CSRF, SQLi | `.munkit/skills/rails-security-review/SKILL.md` |
| `rails-architecture-review` | Reviewing app structure, boundaries, fat models/controllers | `.munkit/skills/rails-architecture-review/SKILL.md` |
| `rails-code-review` | Reviewing Rails PRs, controllers, models, migrations — giving a review | `.munkit/skills/rails-code-review/SKILL.md` |
| `rails-review-response` | You have received review feedback and need to evaluate, respond to, or implement it | `.munkit/skills/rails-review-response/SKILL.md` |
| `yard-documentation` | Writing or reviewing YARD inline docs for public Ruby API | `.munkit/skills/yard-documentation/SKILL.md` |
| `refactor-safely` | Changing code structure without changing behaviour (characterisation tests, one-boundary-at-a-time) | `.munkit/skills/refactor-safely/SKILL.md` |
| `rails-bug-triage` | Investigating a bug, picking the right reproduction test, and planning the smallest safe fix | `.munkit/skills/rails-bug-triage/SKILL.md` |

These skills are adapted — not copied verbatim — from upstream sources; see **Attribution** below.

---

## Stack

- Ruby on Rails (see `.ruby-version` and `Gemfile`)
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- **Minitest** for testing
- RuboCop as the style source-of-truth (`.rubocop.yml`)
- Munkit for durable project context (`.munkit/`)

---

## Attribution

The Rails Code Quality skills under `.munkit/skills/` are adapted from [igmarin/rails-agent-skills](https://github.com/igmarin/rails-agent-skills) (MIT-licensed). Upstream attribution, the commit range the adaptations were derived from, and the list of modifications live in the project [`README.md`](README.md) and [`NOTICE`](NOTICE) — not in each SKILL file, to keep agent-facing files focused. Sections specific to workflows this project does not use (RSpec, DDD, PRDs, Jira ticket planning) have been removed or rewritten for Minitest + Munkit.

If you add, modify, or remove a skill, record the rationale in `.munkit/DECISIONS.md`.

---

## Guardrails

- Do not write implementation code before the corresponding test exists, has been run, and has failed for the right reason.
- Do not introduce RSpec, DDD scaffolding, or PRD/Jira workflows — those are explicitly out of scope for this project.
- Do not duplicate the Munkit protocol here; `AGENTS.md` is the source of truth.
- Do not edit upstream-adapted skills without updating their attribution header and, for substantive changes, adding a `.munkit/DECISIONS.md` entry.
