# Library content

Each installation defines its reusable catalogue in the `content.library` file
selected by its profile. IMASUS uses [`content/library.yml`](../content/library.yml);
the minimal profile provides a small worksheet example in
[`content/example-library.yml`](../content/example-library.yml).

The manifest is data, not executable configuration. It is parsed with safe YAML,
rejects aliases and unknown keys, and must declare `version: 1` and
`resource: library`.

## Stable item contract

Every item stored in `library_items` has:

- a stable, URL-safe `id` from the manifest, persisted as `slug`;
- an `item_type` that selects one of the manifest's finite schemas;
- localized `title` and `summary` values, including the fallback locale;
- structured `custom_fields` validated by that item type;
- normalized taxonomy relationships;
- a bounded list of labelled HTTP(S) links without embedded credentials;
- `published`, `position`, `created_at`, and `updated_at` metadata.

Identity, item type, publication and ordering are normal columns with indexes.
Taxonomy terms and relationships are normalized and indexed. Installation-only
fields live in JSONB, so adding a supported field to an item type does not need a
database migration.

Item IDs, item-type IDs, taxonomy IDs, term IDs, field IDs, and select-option IDs
use lowercase letters, numbers, hyphens, or underscores. Treat an item ID as a
public identifier: edit its content without renaming it.

## Item types and fields

An item type declares localized labels and a list of fields. Version 1 supports
only these field kinds:

| Kind | Accepted value |
| --- | --- |
| `string` | Plain text, at most 500 characters |
| `text` | Plain text, at most 50,000 characters |
| `url` | Absolute HTTP or HTTPS URL without credentials |
| `number` | Finite number |
| `boolean` | YAML `true` or `false` |
| `select` | One ID from the field's declared `options` |

Every field explicitly declares `localized`, `required`, `cardinality` as
`one` or `many`, `display` as `body`, `metadata`, or `hidden`, and whether it
appears on cards with `card`. Field order in the manifest is the render order.
Missing optional values are omitted. Localized values are mappings keyed by an enabled locale; a
required localized field must include a non-blank fallback-locale value.
Unknown fields, locales, option IDs, and taxonomy terms stop application boot or
seeding with their manifest location.

These values are content, never HTML. Views must use escaped text rendering;
only the `url` kind and validated `links` may become link destinations. The
contract does not support scripts, templates, arbitrary nested structures,
embedded credentials, or `data:` URLs.

## Taxonomies, items, and ordering

Taxonomies declare `one` or `many` cardinality, whether they appear as an index
`filter`, and a finite term list. Item
selections reference term IDs under their taxonomy ID. Items appear in manifest
order; the synchronizer persists that position.

Each item declares:

```yaml
- id: first-reflection
  item_type: worksheet
  published: true
  translations:
    en:
      title: First reflection
      summary: A short worksheet for a workshop.
  fields:
    audience: Participants
    instructions:
      en: Record one decision and explain it.
  taxonomies:
    topic: [reflection]
  links: []
  assets: []
```

## Images, videos, and downloads

An item type declares a finite `media` list. Each role specifies `kind`
(`image`, `video`, or `file`), `multiple`, `placement` (`gallery` or
`download`), whether it is the single card `cover`, an exact `allowed_types`
MIME list, and `max_bytes` (up to 500 MB). Gallery roles accept images and
videos; download roles accept files.

```yaml
media:
  - id: cover
    kind: image
    multiple: false
    placement: gallery
    cover: true
    allowed_types: [image/jpeg, image/png, image/webp]
    max_bytes: 10485760
```

Item assets refer to files stored beside the manifest. Paths must be relative,
must not contain `..`, and must exist. Alternative text is localized and must
include the fallback locale:

```yaml
assets:
  - role: cover
    path: library-assets/first-reflection.png
    alt:
      en: A participant writing in a reflection worksheet
```

The sync command detects the file's real MIME type, checks its size, computes a
checksum, and uploads it through the installation's configured Active Storage
service. The same convention therefore works with local disk in development and
the production object-storage service. Missing files, mismatched types, unsafe
paths, and oversized assets stop the dry run with their manifest location or
source path.

## Previewing and applying content changes

Always review the import plan first:

```bash
bin/rails library:sync
```

It validates the complete manifest and media sources and reports each `add`,
`change`, or `retire` operation without writing. Apply that exact content with:

```bash
APPLY=1 bin/rails library:sync
```

The operation is idempotent. Re-running it with unchanged inputs reports no
changes. Items and taxonomy terms removed from the manifest are unpublished;
managed assets are marked retired but their attachment and blob are preserved.
Nothing is silently deleted. Existing bookmarks retain their stored URL and
receive an updated fallback-locale label when a title changes.

`bin/rails db:seed` remains available for initial setup. It fills blank values
by default; set `SEED_LIBRARY=overwrite` or `SEED_OVERWRITE_CONTENT=1` for an
intentional refresh. For routine Library updates, prefer the reviewable sync
workflow above.

## Public URLs and references

Generic installations use `/library` and `/library/:slug`. The existing
`/materials/:slug` addresses remain valid for IMASUS and old bookmarks. A
retired item is removed from indexes but its detail URL remains available with
`noindex`, so references do not break.

`LibraryItem` is also an Action Text attachable. Project descriptions and
process-log rich text can store its stable signed identity and render a generic
reference card. The card reads the current title and summary and marks retired
content as archived; content updates do not invalidate the stored reference.

## IMASUS compatibility and rollout

The migration renames the physical Materials tables to generic Library tables
without changing primary keys or foreign keys. `Material`, `Tag`,
`MaterialTagging`, and `MaterialAsset` remain Ruby adapters, so current routes,
edit forms, exporters, import identities, and media tasks keep working.
PostgreSQL compatibility views retain the old table names during a rolling
deployment. Material URLs keep their existing slugs.

Active Storage blobs and files are not copied. The migration adds equivalent
`LibraryItemAsset` attachment rows pointing to the same blob IDs and retains the
legacy aliases for rollback. Material bookmarks become `LibraryItem` bookmarks
keyed by the stable slug; the application continues to recognize the legacy
bookmark type while mixed versions may be running.

Before retiring any legacy columns or attachment aliases, run:

```bash
bin/rails library:verify_migration
```

The verifier compares manifest identities, record and relationship counts,
legacy and generic localized values and fields, attachment tuples, and bookmark
resolution. Any difference exits with an error.

Rollback is supported while the Library contains only the three legacy Material
taxonomies and `material` items. `bin/rails db:rollback` syncs generic edits back
to legacy columns, restores numeric Material bookmark keys, preserves the shared
blobs, removes generic attachment aliases, and renames the tables back. Once an
installation adds a non-Material item or taxonomy, the migration deliberately
refuses rollback because that data cannot fit the old schema.

The frozen `db/seeds/materials.yml` and `db/seeds/material_tags.yml` inputs and
`script/convert_material_seeds_to_library` document the mechanical conversion;
new installation content should be edited only in its Library manifest.
