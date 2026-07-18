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

## Implementation

- Added strict profile-selected Prompt and Glossary manifests with stable IDs,
  localized category labels and bodies, file order, tags, optional public assets,
  and publication state.
- Kept both resources database-backed. Manifest synchronization preserves
  curator-edited translations by default while updating taxonomy and metadata.
- Entries removed from a manifest are unpublished rather than deleted. Direct
  historical URLs and stored Project/bookmark references continue to resolve.
- Preserved the IMASUS `/challenges` and `/glossary` routes and the existing
  C1–C10/glossary IDs as installation content, not reusable-code assumptions.
- Disabled Glossary integration leaves rendered source text readable and does
  not create embedded term links.
- Added adopter documentation in `docs/catalogs.md` and minimal example manifests.

## Validation

- Focused resource/configuration/controller/profile suite: 159 tests, 873
  assertions, no failures.
- Full Rails suite: 888 tests, 3,855 assertions, no failures.
- RuboCop and Brakeman pass. The gem audit exposed upstream sanitizer advisories;
  the lockfile now uses `loofah` 2.25.2 and `rails-html-sanitizer` 1.7.1.
