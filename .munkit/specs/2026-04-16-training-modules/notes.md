# Training Modules — Notes

Implementation notes, discoveries, and scratch space. Update as work progresses.

## Content source

- Bridgetown repo: `/Users/pablo/projects/imasus/src/training-modules/`
- 52 files total: 4 modules × 4 locales × 3 sections = 48, plus 4 locale-level `about.md` files.
- All markdown files have YAML frontmatter with module metadata (title, slug, locale, available sections/languages).
- Frontmatter `layout` field is Bridgetown-specific — ignore in Rails.

## File structure after copy

```
content/training-modules/
  design-for-longevity/{en,es,it,el}/{training-module,case-study,toolkit}.md
  design-for-modularity/{en,es,it,el}/{training-module,case-study,toolkit}.md
  design-for-recyclability/{en,es,it,el}/{training-module,case-study,toolkit}.md
  zero-waste-design/{en,es,it,el}/{training-module,case-study,toolkit}.md
  {en,es,it,el}/about.md
```

## Embedded Images — The Hidden Trap

The markdown is not clean markdown. It contains 168 raw `<img>` tags across 32 files, pointing to 616 image files under `imasus/src/assets/training-modules/media/`. The images follow the path pattern:

```
/assets/training-modules/media/{module-slug}/{locale}/{section}/media/image{N}.{jpg,jpeg,png}
```

The `<img>` tags have inline `style` attributes with widths in inches (e.g., `style="width:5.16816in;height:3.54601in"`) — these come from DOCX-to-markdown conversion and need to be stripped or replaced with responsive classes.

**Strategy:** copy image files into `public/content/training-modules/media/...`, rewrite `src` paths in the renderer to match, strip inline styles, add `loading="lazy"` and responsive width classes.

## Loader Contract

The loader returns `nil` for missing content. It does not raise. The controller handles nil with a 404. This keeps the loader simple and testable.

## Open Questions

- Markdown renderer choice: Kramdown is already a transitive dependency of Rails (via Action Text / mail gems — verify). If so, no new gem needed.
- Caching strategy: in production, parsed content is immutable between deploys. Could use `Rails.cache.fetch` with a key based on file path + mtime, or simply memoize in-process.
- PORO location: `app/models/training_module/` vs `app/lib/training_module/`. Rails autoloading works for both under Zeitwerk.
- Should we optimise the 616 training images as part of this spec (resize, compress, convert to WebP) or serve them as-is and optimise later? Serving as-is is simpler but could be slow on first load.
