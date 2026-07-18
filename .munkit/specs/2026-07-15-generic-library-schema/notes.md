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

## Implemented contract

- `content.library` selects one strict v1 YAML manifest. The manifest owns item
  types, bounded field schemas, taxonomies, stable items, order, publication,
  localized title/summary, links, and custom field values.
- Field kinds are finite (`string`, `text`, `url`, `number`, `boolean`,
  `select`) and every field declares localization, required state, and one/many
  cardinality. Plain content is rendered escaped; URLs require credential-free
  HTTP(S).
- Indexed common columns live on `library_items`; custom fields and links are
  JSONB. Taxonomy terms and taggings remain normalized and indexed.
- The 63 IMASUS Material entries and 30 terms were mechanically converted into
  `content/library.yml`. The old seed inputs remain frozen as rollback/audit
  fixtures, with `script/convert_material_seeds_to_library` documenting the
  conversion.

## Compatibility migration

- The migration renames all four physical tables to `library_*`, preserves IDs
  and foreign keys, and backfills generic values while retaining legacy columns.
  Old table names remain auto-updatable PostgreSQL views for rolling deploys.
- `Material`, `Tag`, `MaterialTagging`, and `MaterialAsset` adapt the current UI,
  imports, exports, and media tasks to generic storage. Current `/materials/:slug`
  URLs do not change.
- No project or log database foreign key targets Materials. Any rich-content SGID
  continues resolving because the `Material` class and record IDs remain. Material
  bookmarks migrate from numeric `Material` keys to slug-based `LibraryItem`
  keys; legacy bookmark types remain recognized during overlap.
- Active Storage attachment joins are aliased from `MaterialAsset` to
  `LibraryItemAsset` with identical record and blob IDs. Blobs and files are
  never copied.
- Rollback syncs current generic values into legacy columns and restores legacy
  bookmark and attachment identities. It refuses once non-Material items or
  non-legacy taxonomies exist.

## Verification

- `bin/rails library:verify_migration` checks manifest identities, counts,
  localized and custom values, taxonomies/taggings, attachment tuples, and
  bookmark resolution before compatibility storage can be retired.
- Focused model, controller, profile, migration, manifest-safety, adapter, and
  verifier tests cover the transition.
- Verification on 2026-07-18: 897 application tests / 3,885 assertions and 22
  system tests / 140 assertions passed; RuboCop inspected 229 files with no
  offenses; Brakeman reported zero warnings; Importmap audit passed. Both the
  IMASUS seed (63 items, 30 terms) plus migration verifier and the minimal
  profile seed (one `worksheet` item with a generic taxonomy) passed. The real
  development dataset completed migration, rollback, re-migration, attachment
  alias verification, and stable-ID verification without loss.
