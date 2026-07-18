# Notes: 2026-07-15-manifest-driven-guides

## Initial discovery

- `TrainingModule::Loader::MODULE_SLUGS` fixes exactly four guides.
- `build_module_info` treats the English `training-module.md` file as canonical;
  missing English content therefore hides a guide even when another configured
  locale exists.
- Content already lives under `content/training-modules` with YAML front matter,
  so a manifest can evolve the existing approach instead of replacing it.
- Bookmarks identify this filesystem-backed content as `TrainingModule` and
  reconstruct rendered excerpts in `BookmarksHelper`.

## Open questions

- Resolved: use one top-level `manifest.yml`. It makes public order, section
  order, localized section labels, and duplicate IDs visible and reviewable in
  one place. Per-guide Markdown remains independently editable.
- Resolved: preserve `/training` and `/training/:slug/:section` as compatibility
  routes. The configured Guides label is presentation-facing; a generic route
  alias can be added later without forcing redirects now.

## Implementation

- `TrainingModule::Manifest` validates a strict, non-executable version 1 YAML
  contract. It rejects unknown keys, duplicate IDs, unsafe/missing document
  paths, missing public cover assets, unsupported locales, incomplete section
  maps, and malformed or contradictory front matter.
- The manifest owns guide and section order, publication state, covers,
  localized titles/summaries, document paths, and localized section labels.
  Legacy front-matter collection arrays are no longer consumed.
- `TrainingModule::Loader` remains the compatibility namespace for bookmark and
  route stability, but reads only the configured `content.guides` directory.
- Loader results retain requested and actual locales. Views show a fallback
  notice, locale selectors expose real translations, and passage bookmarks use
  the actual content locale.
- The Guides landing now renders manifest titles, summaries, and covers. Tabs,
  detail navigation, previous/next links, and bookmark previews use the same
  manifest-backed objects.
- `content/example-guides` plus the minimal profile proves an installation can
  add, order, hide, and remove guides with content files only.
- Validation: 35 focused tests (116 assertions), 875 Rails tests, 22 system
  tests, 211 RuboCop files, a valid minimal-profile diagnostic, clean gem and
  importmap audits, and Brakeman with zero security warnings.
