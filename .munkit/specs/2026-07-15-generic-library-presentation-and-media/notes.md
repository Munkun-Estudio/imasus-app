# Notes: 2026-07-15-generic-library-presentation-and-media

## Initial discovery

- `MaterialsHelper` and material views encode the five narrative attributes,
  English fallback, tag facets, supplier metadata, and gallery layout.
- `MaterialAsset` and the importer/preprocessor/auditor tasks encode macro,
  microscopy, and video naming conventions tied to the partner source folders.
- Active Storage attachment continuity is part of the migration contract; moving
  blobs is unnecessary if record/attachment relationships can be remapped safely.
- Existing import tools contain useful classification and dry-run ideas but should
  become a profile-specific adapter over the generic import contract.

## Implemented contract

- Field definitions now require bounded presentation hints: `display` is
  `body`, `metadata`, or `hidden`, and `card` is boolean. Taxonomies explicitly
  opt into filtering. Manifest order is render order and missing optional values
  are omitted.
- Item types declare finite media roles (`image`, `video`, or `file`) with
  placement, cardinality, one optional cover, exact MIME types, and byte limit.
  Item assets use safe paths beside the manifest and localized alt text.
- `/library` and `/library/:slug` provide generic presentation while
  `/materials` and every current Material view remain compatibility surfaces.
  A non-Material manifest automatically selects the generic presentation.
- `library:sync` is dry-run by default and `APPLY=1` performs the transaction.
  It reports additions, changes, and retirements; validates actual asset MIME
  and size; checksums uploads; and retires records/assets instead of deleting.
- `LibraryItem` is an Action Text attachable, so Projects and process logs can
  persist stable signed references. Retired items remain directly addressable
  and render an archived reference state. Bookmark URLs remain unchanged while
  fallback-locale labels follow title updates.

## Validation

- Full suite: 913 runs, 3967 assertions, 0 failures, 0 errors.
- Focused non-Material request coverage swaps in `content/example-library.yml`
  and renders the Worksheet card, field metadata/body, and taxonomy without
  application-code changes.
- RuboCop: 236 files, no offenses. Brakeman: no warnings.
- Migration rollback and re-apply succeed while data remains legacy-compatible.
- Browser review at 1440×1000 covered `/library` and one generic detail page;
  layout, filters, card order, headings, gallery controls, metadata, and links
  were coherent. The development database contains historical Active Storage
  rows whose local disk files are absent, so those images showed broken-source
  placeholders; this is pre-existing local fixture state, not a renderer error.
