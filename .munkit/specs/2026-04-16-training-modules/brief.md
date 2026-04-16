# Training Modules

## What

Render the four Lottozero training modules from static markdown files, with locale switching, section navigation, and a markdown rendering pipeline. Training modules are not ActiveRecord models — they are plain Ruby objects that read from the filesystem.

The content already exists in the IMASUS Bridgetown site repo and will be copied into this project. Each markdown file has YAML frontmatter with module metadata (title, slug, locale, available sections/languages).

## Why

This is the first real feature. It involves zero database work, no migrations, and no Active Storage — making it the ideal candidate to exercise the full workflow (tests gate → implementation → YARD → docs → code review) end-to-end for the first time.

It also establishes the I18n pattern in practice: training modules are the first multilingual content, and the locale switcher from spec 1 (app-shell-and-navigation) gets its first real use.

## Content Structure

Source: Bridgetown repo at `imasus/src/training-modules/`. To be copied into `content/training-modules/` in this project.

```
content/training-modules/
  {module-slug}/
    {locale}/
      training-module.md
      case-study.md
      toolkit.md
  {locale}/
    about.md          ← per-locale "about training" page
```

**4 modules:** zero-waste-design, design-for-recyclability, design-for-modularity, design-for-longevity.
**3 sections each:** training-module, case-study, toolkit.
**4 locales:** en, es, it, el.
**4 about pages:** one per locale (general introduction to the training programme).
**616 image files** under `assets/training-modules/media/` in the Bridgetown repo, referenced by raw `<img>` tags in the markdown (not standard markdown image syntax).

Each markdown file has YAML frontmatter:

```yaml
layout: training_module_reader
title: "Zero Waste Design"
module_slug: "zero-waste-design"
module_title: "Zero Waste Design"
lang: "en"
volume: "training-module"
available_modules: ["design-for-longevity", "design-for-modularity", "design-for-recyclability", "zero-waste-design"]
available_languages: ["en", "it", "es", "el"]
available_volumes: ["training-module", "toolkit", "case-study"]
```

## Acceptance Criteria

- [ ] Markdown content is copied into `content/training-modules/` following the existing directory structure.
- [ ] A `TrainingModule::Loader` PORO exists that can enumerate all modules, their available locales, and their sections. It reads from the filesystem and parses YAML frontmatter.
- [ ] A `TrainingModule::Section` value object (or similar) holds the parsed metadata and body for a given module/section/locale.
- [ ] A markdown rendering helper converts the content for display. Choose Kramdown (already a Ruby stdlib-adjacent dependency) or Redcarpet — whichever is lighter. The renderer must handle: headings, paragraphs, lists, bold/italic, links, images, code blocks.
- [ ] **Embedded image handling:** the source markdown contains raw `<img>` tags with `src="/assets/training-modules/media/..."` paths and inline `style` attributes (widths in inches). The renderer must:
  - Allow these `<img>` tags through (not strip them).
  - Rewrite `src` paths to point to the correct location in the Rails app (e.g., `/content/training-modules/media/...` served as static files, or an asset path).
  - Strip or replace inline `style` attributes with responsive CSS classes (the inch-based widths from the DOCX conversion are not usable in a web context).
  - Add `loading="lazy"` to all images.
- [ ] The 616 media files from `imasus/src/assets/training-modules/media/` are copied into this project alongside the markdown content and served as static files (e.g., from `public/` or via a controller). They are static assets, not Active Storage attachments.
- [ ] `TrainingModulesController` with `index` and `show` actions.
  - `index` lists all 4 modules with their titles and available sections.
  - `show` renders a specific module/section/locale combination.
- [ ] Routes: `GET /training` (index), `GET /training/:slug/:section` (show). Locale comes from the app-wide locale param/cookie (spec 1).
- [ ] **Locale switcher** on the training view links to the same module/section in another locale. Available locales come from the frontmatter's `available_languages` field.
- [ ] **Chapter navigation** (Previous / Next) between sections within a module: training-module → case-study → toolkit. Section order comes from frontmatter's `available_volumes` field.
- [ ] **Module navigation** between the 4 modules (sidebar or tab-style). Order comes from frontmatter's `available_modules` field.
- [ ] The "about training" page (`content/training-modules/{locale}/about.md`) is rendered at `GET /training` as an introduction above or before the module list.
- [ ] All UI strings (nav labels, "Previous", "Next", section names) use `t(...)` in all 4 locales.
- [ ] YARD documentation on all public methods of `TrainingModule::Loader` and related classes.
- [ ] Tests cover:
  - Loader enumerates modules, sections, and locales correctly.
  - Loader returns `nil` for missing content (unknown slug, unavailable locale). It does not raise — callers (the controller) are responsible for handling nil with a 404.
  - Controller renders index and show successfully.
  - Locale switching links are present and point to the correct path.
  - Chapter navigation links are present and correct at boundary cases (first section has no "Previous", last has no "Next").

## Out of Scope

- Progress tracking (requires auth — spec 8+).
- Glossary hotspots / inline term highlighting (spec 5, which adds a Stimulus controller that retroactively enriches training content).
- Video teasers (content dependency — not available yet).
- Search within training content.

## Implementation Notes

- The mockup's `TrainingView.tsx` shows a tabbed interface with module cards. That's a UI reference, not a requirement — the Rails views should feel editorial, not dashboard-like (see design context in `context.md`).
- The frontmatter `layout` field (`training_module_reader`) is a Bridgetown concept and can be ignored in Rails. The useful fields are `module_slug`, `lang`, `volume`, `available_modules`, `available_languages`, `available_volumes`.
- Consider caching parsed markdown in development (file mtime check) and production (indefinite, bust on deploy). The content is static — no database needed.
- The PORO loader can live at `app/models/training_module/loader.rb` following Rails autoload conventions, or at `app/lib/training_module/loader.rb` if you prefer to separate non-AR objects. Decide during implementation.
