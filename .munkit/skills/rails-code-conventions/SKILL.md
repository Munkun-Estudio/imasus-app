---
name: rails-code-conventions
description: >
  A daily checklist for writing clean Rails code, covering design principles
  (DRY, YAGNI, PORO, CoC, KISS), per-path rules (models, services, jobs,
  controllers), structured logging, and comment discipline. Defers style and
  formatting to the project's configured linter(s). Use when writing, reviewing,
  or refactoring Ruby on Rails code, or when asked about Rails best practices,
  clean code, or code quality. Trigger words: code review, refactor, RoR,
  clean code, best practices, Ruby on Rails conventions.
---

# Rails Code Conventions

**Style source of truth:** Style and formatting defer to the project's configured linter. This skill adds **non-style behavior** and **architecture guidance** only. For Hotwire + Tailwind specifics, see `rails-stack-conventions`.

**Test framework:** this project uses **Minitest** (Rails default). All test guidance below assumes Minitest + fixtures. Do not introduce RSpec or FactoryBot.

## Linter — initial analysis

Detect → run → defer. Do not invent style rules.

- Ruby: this project uses RuboCop (`.rubocop.yml` at the repo root) → `bundle exec rubocop`.
- Frontend: check for `eslint.config.*`, `.eslintrc*`, `biome.json`, or a `package.json` lint script → run accordingly.
- **If no config is found:** note this to the user — do not default to any tool.

## Quick Reference

| Topic | Rule |
|-------|------|
| Style/format | Project linter(s) — detect and run as above; do not invent style rules here |
| Principles | DRY, YAGNI, PORO where it helps, CoC, KISS |
| Comments | Explain **why**, not **what**; use tagged notes with context |
| Logging | First arg string, second arg hash; no string interpolation; `event:` when useful for dashboards |
| Tests | Minitest + fixtures; `bin/rails test` to run; see **HARD-GATE** below |

## Design Principles

| Principle | Apply as |
|-----------|----------|
| **DRY** | Extract when duplication carries real maintenance cost; avoid premature abstraction |
| **YAGNI** | Build for current requirements; defer generalization until a second real use case |
| **PORO** | Use plain Ruby objects when they clarify responsibility; do not wrap everything in a "pattern" |
| **Convention over Configuration** | Prefer Rails defaults and file placement; document only intentional deviations |
| **KISS** | Simplest design that meets acceptance criteria and **tests gate** |

## Comments

- Comment the **why**, not the **what** (the code shows what).
- Use tags with **enough context** that a future reader can act: `TODO:`, `FIXME:`, `HACK:`, `NOTE:`, `OPTIMIZE:`.

```ruby
# BAD — restates the method name, adds zero value
# Finds the user by email
def find_by_email(email)
  User.find_by(email: email)
end

# GOOD — explains intent and tradeoff
# Uses find_by (not find_by!) so callers can handle nil explicitly;
# downstream auth layer is responsible for raising on missing user.
def find_by_email(email)
  User.find_by(email: email)
end
```

## Structured Logging

- **First argument:** static string (message key or human-readable template without interpolated values).
- **Second argument:** hash with structured fields (`user_id:`, `material_id:`, etc.).
- **Do not** build the primary message with string interpolation; put dynamic data in the hash.
- Include an **`event:`** key when the log line is meant to be filtered or dashboarded.

```ruby
# BAD — interpolation loses structure; cannot filter by file path in log aggregators
Rails.logger.info("Importing materials from #{path} — #{rows.size} rows")

# GOOD — static message, structured data, filterable fields
Rails.logger.info("materials.import.started", {
  event: "materials.import.started",
  source: "docs/materials-db.csv",
  count: rows.size
})
```

## Apply by area (path patterns)

Rules below apply **when those paths exist** in the project. If a path is absent, skip that row.

| Area | Path pattern | Guidance |
|------|--------------|----------|
| **ActiveRecord performance** | `app/models/**/*.rb` | Eager load in loops; prefer `pluck`, `exists?`, `find_each` over loading full records. When N+1s surface, fix eager loading before optimising lower down |
| **Background jobs** | `app/jobs/**/*.rb` | Clear job structure, queue selection, idempotency, structured error logging |
| **Error handling** | `app/services/**/*.rb`, `app/lib/**/*.rb`, `app/exceptions/**/*.rb` | Use domain exceptions with named classes; keep `rescue_from` narrow and specific; do not swallow exceptions silently |
| **Logging / tracing** | `app/services/**/*.rb`, `app/jobs/**/*.rb`, `app/controllers/**/*.rb` | Structured logging as above. Add trace spans only if the project has an APM — do not add instrumentation that has nowhere to go |
| **Controllers** | `app/controllers/**/*_controller.rb` | Strong params; thin actions that delegate to models or POROs; watch IDOR and PII exposure (see `rails-security-review`) |
| **Service objects** | `app/services/**/*.rb` | Single responsibility; class methods for stateless entry points, instance API when dependencies are injected; public methods first; bang (`!`) / predicate (`?`) naming as appropriate |
| **Minitest** | `test/**/*_test.rb` | Follow the Rails 8 scaffold layout: `test/models/`, `test/controllers/`, `test/integration/`, `test/system/`, `test/jobs/`, `test/mailers/`. Rails fixtures under `test/fixtures/`. System tests only when browser interaction is the real risk. One assertion concept per test. Use `setup` for shared state. Tests run in parallel by default — keep them isolated |
| **SQL security** | Raw SQL anywhere | No string interpolation of user input; use `sanitize_sql_array` / bound parameters; whitelist dynamic `ORDER BY`; document **why** raw SQL is needed |
| **Repositories** | `app/repositories/**/*.rb` | Avoid introducing repository objects unless raw SQL, caching, a clear domain boundary, or external service isolation justifies it. ActiveRecord is the default data boundary |

## HARD-GATE: Tests Gate Implementation

When this skill guides **new behavior**, the tests gate from `CLAUDE.md` still applies:

```text
Munkit Spec → TEST (write, run, fail) → IMPLEMENTATION → YARD → DOCS → CODE REVIEW → PR
```

No implementation code before a failing test. Run tests with `bin/rails test` (or a targeted file path). Confirm the failure reason is *feature missing*, not a typo, fixture gap, or setup error.

## Common Mistakes

| Mistake | Reality |
|---------|---------|
| Inventing style rules when a linter config exists | The project's configured linter is authoritative for style — do not add prose style rules |
| Assuming RuboCop when no config is checked | Detect first; note the absence to the user if no config is found |
| Reaching for RSpec idioms (`let`, `describe`, FactoryBot) | This project is Minitest + fixtures — translate, don't import |
| New `app/repositories/` for every query | ActiveRecord is the default data boundary unless there's a documented reason |
| Adding APM spans or structured `event:` keys without a consumer | Only instrument what a dashboard, alert, or on-call workflow actually reads |

## Integration

| Skill | When to chain |
|-------|---------------|
| `rails-stack-conventions` | Stack-specific: PostgreSQL, Hotwire, Tailwind |
| `rails-security-review` | Controllers, params, IDOR, PII |
| `rails-migration-safety` | Any schema change |
| `rails-code-review` | Full PR pass before merge |
