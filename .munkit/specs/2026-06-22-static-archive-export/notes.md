# Notes: 2026-06-22-static-archive-export

## Ownership boundary

- `/Users/pablo/projects/imasus-app` owns the read-only Rails exporter and
  runs it against production.
- `/Users/pablo/projects/imasus-app-static` owns import, page generation, and
  Netlify deployment. Another Codex session is working there; do not edit that
  repository from this spec branch.
- The handoff artifact is a versioned export directory headed by
  `manifest.json`, with content section files and an asset manifest.

## Public-content scope

- Export `Project.active.published` only. Draft, disabled, and private project
  data remains excluded.
- Published project pages currently expose member name, institution, country,
  bio, and profile links; names are explicitly approved to remain public.
- Do not export account credentials, email addresses, invitation data,
  bookmarks, admin records, or raw private log entries.
- Project `process_summary` is Action Text and may embed Active Storage
  attachments. Those attachments need portable direct URLs in the export.

## Assets

- Production Active Storage uses the `amazon` service with `public: true` and
  `rails_storage_redirect`. A sampled Tigris object was directly reachable,
  returned `200`, `x-amz-acl: public-read`, and did not require Rails.
- The export must enumerate assets used by `MaterialAsset.file`,
  `MaterialAsset.poster`, `Project.hero_image`, and public Action Text embeds.
- Rails representation URLs and lazy variant processing cannot be part of the
  static contract. The export carries direct original URLs and metadata; any
  derivative policy belongs to the static import/deployment phase.
- A complete bucket inventory and cost report still require authenticated Fly
  access. `flyctl` was not authenticated in this environment when checked.

## Source-model findings

- Materials are `Material` records with translated JSONB fields, tags, and
  ordered `MaterialAsset` children (`macro`, `microscopy`, `video`). A video
  may have a separate poster attachment.
- Challenges and glossary terms store translations in JSONB under the shared
  `Translatable` concern.
- Workshop agendas are Action Text fields, one per locale; workshop metadata
  is otherwise model data.
- Training modules are filesystem content in `/Users/pablo/projects/imasus`.
  They are not exported from Rails in this spec.

## Environment

- This Rails repo currently needs `ASDF_RUBY_VERSION=3.4.7` when commands are
  run through asdf; the machine-wide default is Ruby 4.0.5.
- `bundle exec rails --version` succeeds under Ruby 3.4.7.

## Implementation progress

- Added `StaticArchiveExporter` and `static_archive:export[OUTPUT_DIR]`.
  The task writes section JSON files, `assets.json`, and `manifest.json`, and
  rejects a non-empty output directory.
- The asset URL builder is injectable for tests. Production defaults to
  `ActiveStorage::Blob#url`; test Disk storage needs either an injected URL or
  `ActiveStorage::Current.url_options`.
- Local tests cover public-project scoping, material asset ordering, direct
  asset URL injection, destination protection, Action Text rewriting, and the
  rejection of Rails Active Storage URLs.
- Action Text is rendered, parsed with Nokogiri, and each rendered attachment
  figure receives a manifest URL and `data-static-asset-id`. A mismatch between
  Action Text attachments and rendered figures fails the export.
- The exporter rejects any asset URL containing `/rails/active_storage/`.

## Open Questions

- Confirm the final output directory and transfer method once the static
  importer has selected its fixture/import format.
- Confirm whether public workshop agenda attachments exist in production and
  should be included in the first archive export.
