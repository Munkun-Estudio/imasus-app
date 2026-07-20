# Generic library presentation and media

## What

Render, filter, import, and attach media to generic Library Items according to
their item-type schemas. Provide safe reusable card/detail components and a
content import workflow while matching the current Materials experience for the
IMASUS profile.

## Why

A generic schema is only useful if adopters can present their own fichas and
media without writing templates or one-off importers. The current views and
assets assume IMASUS Material fields and categories.

## Acceptance Criteria


- [x] The renderer supports the v1 field kinds with accessible list/card/detail
  output, safe rich text and links, deterministic ordering, and missing-value
  behaviour.
- [x] Configured library labels, facets, filters, sorting, empty states, and
  metadata replace Materials-specific copy and category assumptions.
- [x] A documented idempotent import/sync command validates manifests, reports
  additions/changes/removals, and does not silently delete published data.
- [x] Image and file conventions support local development and the configured
  Active Storage service, including alt text, allowed types/sizes, and missing
  asset diagnostics.
- [x] Project/log references and bookmarks render generic items and remain valid
  across content updates or retired items.
- [x] Visual/request/system regression coverage shows the IMASUS library retains
  its current content and essential interaction, and an example item type works
  without application-code changes.

## Out of Scope


- A drag-and-drop schema designer or in-browser bulk content editor.
- Remote third-party content federation.

## Notes

Depends on `Generic library schema` and the shared configuration, locale, and
module contracts. Glossary-aware field rendering is optional and must respect
the module registry.
