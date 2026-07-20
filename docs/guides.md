# Guide content

The Guides module reads a versioned `manifest.yml` from the directory selected
by `content.guides` in the active installation profile. An adopter can change
the collection, its order, translations, and documents without editing Ruby,
routes, or templates.

The minimal example lives in [`content/example-guides`](../content/example-guides)
and is selected by [`config/profiles/minimal.yml`](../config/profiles/minimal.yml).
The IMASUS installation uses
[`content/training-modules`](../content/training-modules).

## Directory convention

```text
content/my-guides/
  manifest.yml
  en/about.md
  getting-started/
    en/guide.md
    es/guide.md
  next-steps/
    en/guide.md
```

Document names and directory depth are conventions for contributors, not
hardcoded assumptions. Every Markdown path is declared explicitly in the
manifest. Paths must be relative, remain inside the configured guides
directory, and resolve to existing files.

## Manifest contract

```yaml
version: 1

about:
  en: en/about.md

sections:
  - id: guide
    labels:
      en: Guide

guides:
  - id: getting-started
    published: true
    cover: /images/guides/getting-started.jpg
    translations:
      en:
        title: Getting Started
        summary: A concise description shown in the guide listing.
        documents:
          guide: getting-started/en/guide.md
```

- `sections` defines navigation order and requires a label for every locale in
  the installation profile.
- `guides` order is the public listing and tab order. IDs are stable URL
  segments made from lowercase letters, numbers, and hyphens.
- `published: false` keeps a guide out of listing, detail, and navigation while
  allowing its content to stay in the repository.
- `cover` is an application-relative URL to an existing file under `public/`.
- `translations` can contain any subset of configured locales. Each translation
  owns its localized title, summary, and one document for every declared
  section.
- `about` is optional per locale in practice, but must contain at least one
  usable configured locale if the installation wants an introduction page.

Markdown may have YAML front matter, but the manifest remains the source for the
guide title and summary. Legacy IMASUS fields such as `title`, `module_slug`,
`lang`, and `volume` are accepted during migration; identity fields are
validated against the manifest when present. They are not required in new
content.

## Locale fallback

The requested locale is tried first, followed by the installation profile's
shared fallback chain. When fallback content is found, the page renders it with
a visible language notice and records bookmarks against the actual content
locale. When no translation exists anywhere in that chain, the detail URL
returns 404. Locale selectors only offer translations that really exist for the
guide.

## Adding, reordering, hiding, and removing guides

1. Add a directory containing the localized Markdown documents.
2. Add one guide entry to `manifest.yml` and place it in the intended order.
3. Put its cover below `public/` and reference the application-relative URL.
4. Restart the Rails process; the manifest is validated when Guides loads.

Reorder entries to change presentation order. Set `published: false` to preview
a future removal safely. To remove the guide completely, delete its manifest
entry and content directory. No application-code change is involved.

Validation rejects duplicate IDs, unknown or missing section documents,
unsupported locales, unsafe or missing paths, missing covers, malformed front
matter, and unknown manifest keys with the location of the problem.
