# Configurable locales and localized rich text

## What

Make the ordered set of supported locales and the default locale configurable,
and replace locale-specific application fields with a reusable localized rich
text representation where content is installation-defined. Migrate existing
workshop agendas without losing rich text or attachments.

## Why

English, Spanish, Italian, and Greek are repeated in validations, forms, models,
content loaders, and storage columns. Every adopter should be able to choose its
languages without changing schema or application code.

## Acceptance Criteria


- [x] Enabled locales, their display labels, ordering, and the default/fallback
  locale come from validated installation configuration.
- [x] Locale selectors, validations, routes, forms, mailers, and content loaders
  contain no fixed four-locale assumption.
- [x] A reusable localized rich text abstraction supports configured locales and
  has deterministic fallback and missing-content behaviour.
- [x] Existing `agenda_en`, `agenda_es`, `agenda_it`, and `agenda_el` content and
  attachments migrate safely, with a verified rollback path.
- [x] Existing IMASUS locale URLs and behaviour remain compatible after migration.
- [x] Tests cover one locale, the current four locales, an additional locale, and
  fallback/missing translation cases.

## Out of Scope


- Machine translation or translation-management workflows.
- Localising administrator-authored operational data that is intentionally
  single-language.

## Notes

Depends on `Application configuration foundation`. The storage design should be
usable by guides, library items, prompts, and glossary entries without forcing
all of those domains into one model.
