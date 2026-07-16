# Notes: 2026-07-15-configurable-prompts-and-glossary

## Initial discovery

- `Challenge` fixes the C1–C10 code format, numeric ordering, four categories,
  English base locale, and seed path in the model.
- `GlossaryTerm` fixes four categories and derives its stable slug from the
  English term; the highlighter loads all terms globally.
- Both models already use JSONB translations and idempotent YAML seed workflows,
  which can inform the generic manifest/import contract.
- Projects, logs, bookmarks, and links may retain references after content is
  removed; retirement semantics are required before replacement.

## Open questions

- Assess whether prompt/glossary content should remain database-backed after
  manifest sync or be read directly from disk; editing and historical references
  favour a persisted representation.
