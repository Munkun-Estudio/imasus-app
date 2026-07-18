# Configurable prompts and glossary

## What

Convert fixed Challenge cards into a configurable Prompts resource and move
Glossary terms, categories, ordering, and localized content behind documented
content manifests. Retain the current challenges and glossary as IMASUS content.

## Why

Challenge IDs, categories, and English-first glossary assumptions encode the
project methodology in application code. They are useful resource patterns, but
their taxonomy and copy must belong to an installation.

## Acceptance Criteria


- [x] Prompt and glossary manifests define stable IDs, ordering, localized labels
  and bodies, categories/tags, assets, and publication state.
- [x] The current C1–C10 assumptions and fixed category lists are removed from
  reusable models, helpers, views, loaders, and validations.
- [x] Listings, details, filters, project/log references, and bookmarks resolve
  content by stable IDs and handle retired content without breaking historical
  records.
- [x] Glossary links embedded in other modules resolve when Glossary is enabled
  and degrade to readable text when it is disabled or a term is absent.
- [x] Existing IMASUS prompt and glossary URLs/content remain compatible, with
  redirects where a generic public name changes a route.
- [x] Validation and regression tests cover localized content, invalid references,
  disabled modules, and the current IMASUS dataset.

## Out of Scope


- User-created taxonomies stored through an administration UI.
- General-purpose surveys, quizzes, or assessment engines.

## Notes

Depends on the configuration, locale, and module registry specs. Stable content
IDs must be separate from display labels and translated slugs.
