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

- Decide whether the collection uses one top-level manifest or per-guide
  manifests after testing contributor ergonomics and validation messages.
- Preserve current URLs first; generic `/guides` naming can be an alias rather
  than a mandatory breaking route change.
