# Notes: 2026-04-22-challenge-cards

Scratch space for working through this spec. Delete when done.

---

## Open Questions

- **Resources label wording.** Settled on "Resources" (small-caps) pending
  a sanity check in the UI. If the label reads too formal next to the
  playful paint-chip swatches, consider alternatives ("Support", "Learn",
  "Library") — check with the user before changing.
- **Category tint strength.** The mapping is locked (material→dark-green,
  design→navy, system→light-blue, business→light-pink), but the visual
  weight (solid fill vs. accent bar vs. tinted background) is TBD and
  should be decided by eye during implementation, not up-front in the
  brief. Target: "lighter siblings of the sidebar palette", not competing
  fills.

## Resolved

- **Component form:** ERB partial, not `ViewComponent`. No
  `view_component` gem in `Gemfile`; glossary (`app/views/glossary_terms/`)
  uses partials as the app's precedent. → `app/views/challenges/_card.html.erb`.
- **URL code casing:** lowercase (`/challenges/c1`), looked up
  case-insensitively against the uppercase stored `code`.
- **Sidebar item position and colour:** `04 Challenges`, mint
  (`bg-imasus-mint`), inside the Resources group. See
  `DECISIONS.md` (2026-04-22).
- **Category → palette mapping:** fixed. See brief's
  `ChallengeCard component` section.

## Research

- Challenge copy source: WIP DOCX/PDF referenced in `context.md`
  ("Content sources"). Placeholder `en` content is acceptable for this
  spec; the real text replacement is a separate data task once the source
  document is finalised.
- Glossary spec (`2026-04-17-glossary`) is the pattern precedent for:
  `Translatable` concern, locale-tabs form, inline Turbo-Frame edit,
  role-gated curator affordances. Read its `brief.md` / `notes.md` before
  reimplementing any of it.
- Sidebar IA decisions (2026-04-22) are in `DECISIONS.md` with rationale;
  MEMORY.md carries the concise pattern summary under "Key Patterns".
  If implementation drifts from either, fix the drift — do not work
  around it silently.
- Placeholder removals — inventory of everything touched by dropping Log
  and Prototype as top-level items:
  - `config/routes.rb`
  - `app/controllers/prototype_controller.rb`, `log_controller.rb`
  - `app/views/prototype/`, `app/views/log/`
  - `config/locales/{en,es,it,el}.yml` — `nav.log`, `nav.prototype` keys
  - `test/controllers/prototype_controller_test.rb`,
    `test/controllers/log_controller_test.rb`
  - `test/integration/shell_layout_test.rb` — assertions about the old
    seven-item layout
- Training-module content (`content/training-modules/**/toolkit.md`)
  uses "prototype" in the design-research sense — **do not** rewrite
  these. The 2026-04-22 decision is about product nomenclature, not
  domain vocabulary.
