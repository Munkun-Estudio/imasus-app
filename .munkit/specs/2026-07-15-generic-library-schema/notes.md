# Notes: 2026-07-15-generic-library-schema

## Initial discovery

- `Material` mixes stable catalogue data, supplier fields, a fixed availability
  enum, five translated narrative fields, three tag facets, ordering, and media
  convenience methods.
- Related tables and code include `MaterialTagging`, `Tag`, `MaterialAsset`,
  project/log references, bookmarks, source parsing/export, confirmed variants,
  and multiple media maintenance tasks.
- Existing slugs are stable and deliberately do not change when names change;
  the generic contract should preserve this useful invariant.
- The seed workflow is idempotent and preserves edited records by default via
  `SeedPolicy`; migration/import should retain that explicit overwrite policy.

## Open questions

- Select the boundary between indexed common columns and JSONB custom fields
  using actual filter/query requirements, then record the schema decision.
- Inventory foreign keys and indirect string references before designing the
  compatibility migration.
