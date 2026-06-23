# Static archive export

## What

Add a read-only Rails export pipeline for the forthcoming IMASUS static
archive. The task writes a versioned JSON contract and asset manifest to an
explicit output directory. It exports public workshops, active published
projects, materials, challenges, and glossary terms, plus the public asset
metadata required by the Bridgetown importer.

## Why

The Rails application will be retired after the completed workshops are
archived at `app.imasus.eu`. The static site needs a repeatable source of truth
that does not depend on Rails routes, a production database connection at
runtime, or Active Storage redirect URLs.

## Acceptance Criteria

- [ ] `bin/rails static_archive:export[OUTPUT_DIR]` writes `manifest.json` and
      section data files to the requested directory and refuses to overwrite a
      non-empty destination by default.
- [ ] Only `Project.active.published` projects are exported, with public
      workshop, challenge, member, hero media, process summary, and referenced
      attachment data.
- [ ] Materials, challenges, glossary terms, and public workshop metadata are
      exported with translations and ordered asset metadata where applicable.
- [ ] Every exported asset has a direct object URL, blob key, MIME type, byte
      size, checksum, and usage record; no emitted URL uses Rails Active Storage.
- [ ] Embedded Action Text attachments are rewritten through manifest URLs and
      missing references fail the export.
- [ ] Tests cover project scoping, material asset ordering, member privacy, and
      rich-text attachment rewriting.

## Out of Scope

- Logging into Fly or listing/copying bucket objects.
- Importing content into Bridgetown or deploying Netlify.
- Exporting users, email addresses, invitations, private projects, private log
  entries, bookmarks, or admin data.
- Migrating Tigris to a different object store.
