# Notes: 2026-04-17-glossary

Scratch space for working through this spec. Delete when done.

---

## Decided

Local, spec-scoped decisions. The curator UI block and the JSONB translatable-fields approach have been promoted to `DECISIONS.md`. These remaining choices are implementation-level and reflected directly in the AC in `brief.md`.

- **Category schema:** `category` is a plain string column with an inclusion validation. Initial values: `methodology`, `application`, `industry`, `science`. Kept flexible — a fifth category is a one-line change to the validator, no migration. Rejected alternatives: enum (rigid), `GlossaryCategory` model (overkill for four fixed-ish values).
- **Seed source:** `db/seeds/glossary_terms.yml`. Hand-curated YAML with ≥ 10 entries covering the four categories, `en` filled and at least stub values for `es`, `it`, `el`. Re-running the seed is idempotent (find-or-initialize by slug). Rejected: CSV (bad fit for multi-locale nested values), extraction from training markdown (research work, deferred).
- **Popover scope:** training modules, materials, and workshop help/guidance texts. The helper is applied explicitly in those three surfaces — not globally to every Action Text render — so the rules stay predictable.
- **Popover activation:** click only. Hover was rejected because it creates mobile/tablet conflicts (touch devices emulate hover unreliably) and interferes with text selection on desktop. Focus-activation without click would surprise keyboard users expecting Enter/Space. Click with full keyboard reachability (Tab to focus, Enter/Space to open, Escape to dismiss, outside-click to dismiss) covers pointer, touch, and keyboard cleanly.

## Ideas

-

## Research

-
