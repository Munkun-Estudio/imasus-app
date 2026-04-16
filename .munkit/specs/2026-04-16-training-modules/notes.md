# Training Modules — Notes

Implementation notes, discoveries, and scratch space.

## Content source

- Bridgetown repo: `/Users/pablo/projects/imasus/src/training-modules/`
- 52 markdown files: 4 modules × 4 locales × 3 sections = 48, plus 4 locale-level `about.md` files.
- 308 media files under `imasus/src/assets/training-modules/media/` (spec said 616 — overcounted).
- All markdown files have YAML frontmatter with module metadata (title, slug, locale, available sections/languages).
- Frontmatter `layout` field is Bridgetown-specific — ignored in Rails.

## Decisions made during implementation

- **Markdown renderer:** Kramdown (added as explicit gem — not a transitive Rails dependency). Default `kramdown` input mode, not GFM (which requires separate `kramdown-parser-gfm` gem).
- **PORO location:** `app/models/training_module/` — Zeitwerk autoloads this cleanly under the `TrainingModule` namespace.
- **Image hosting:** Files served as static assets from `public/content/training-modules/media/`. Renderer rewrites `src="/assets/..."` to `src="/content/..."`.
- **Image cleanup:** Inline `style` attributes (inch-based widths from DOCX conversion) stripped. `loading="lazy"` added to all `<img>` tags.
- **HTML sanitization:** Views use `sanitize` with an explicit tag/attribute allowlist instead of `raw`, to prevent XSS from DOCX conversion artifacts.
- **Route constraints:** `slug` and `section` params constrained to `/[a-z0-9-]+/` to prevent path traversal.
- **Section order:** Comes from frontmatter `available_volumes` field, which is `["training-module", "toolkit", "case-study"]` — note: toolkit comes before case-study.
- **Caching:** Not implemented yet. Content is static and fast enough to read per-request for now. Can add `Rails.cache.fetch` with file mtime keys later.
- **404 handling:** Controller renders `public/404.html` for missing content, not `head :not_found`.

## File structure

```
content/training-modules/
  design-for-longevity/{en,es,it,el}/{training-module,case-study,toolkit}.md
  design-for-modularity/{en,es,it,el}/{training-module,case-study,toolkit}.md
  design-for-recyclability/{en,es,it,el}/{training-module,case-study,toolkit}.md
  zero-waste-design/{en,es,it,el}/{training-module,case-study,toolkit}.md
  {en,es,it,el}/about.md

public/content/training-modules/media/
  {module-slug}/{locale}/{section}/media/image{N}.{jpg,jpeg,png}
```

## Loader contract

The loader returns `nil` for missing content. It does not raise. The controller handles nil with a 404.
