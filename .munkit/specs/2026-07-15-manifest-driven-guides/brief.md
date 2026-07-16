# Manifest driven guides

## What

Generalise the current Training section into a Guides module whose collections,
ordering, labels, cover assets, and localized documents are declared by a content
manifest. Migrate the four current training slugs to an IMASUS manifest.

## Why

Training content is loaded from a hardcoded canonical English list and fixed
slugs. Adopters need to supply any number of guides and translations through a
documented folder convention without changing loaders or controllers.

## Acceptance Criteria


- [ ] A documented manifest and directory convention defines guide identity,
  order, localized title/summary/body, assets, and publication state.
- [ ] The loader validates duplicate IDs, missing required files, unsafe paths,
  unsupported locales, and malformed front matter with actionable messages.
- [ ] Guide listing, detail, navigation, and bookmarks are driven by manifest
  data and the module registry, with configured labels rather than Training-only
  copy.
- [ ] Locale fallback follows the shared locale contract and clearly distinguishes
  unavailable content from fallback content.
- [ ] The existing four IMASUS guides, URLs, assets, and ordering are preserved or
  covered by explicit redirects and regression tests.
- [ ] An example profile demonstrates adding and removing a guide using content
  files only.

## Out of Scope


- A browser-based guide editor.
- Executable content extensions or arbitrary templates supplied by adopters.

## Notes

Depends on the configuration, locale, and module registry specs.
