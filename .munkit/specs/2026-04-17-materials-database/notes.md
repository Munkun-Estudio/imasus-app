# Notes: 2026-04-17-materials-database

## Implementation slice plan (agreed with user on 2026-04-21)

The spec shipped across five PRs on `feat/materials-database` and was fully
merged by 2026-04-21:

- **PR (a) — data layer (merged).** Migrations, models, seed loaders,
  reconciled YAML seeds, YARD. No user-facing routes yet.
- **PR (a.5) — media layer (merged).** `MaterialAsset` model (macro/microscopy/video kinds),
  local-folder importer + rake task, Seacell-7 duplicate merge at the parser.
  Inserted between (a) and (b) so the index/detail PRs can assume asset
  accessors are present. Decided 2026-04-21.
- **PR (b) — public index (merged).** Materials index page, chip-filter rail, URL binding,
  search box.
- **PR (c) — preview sidebar (merged).** Turbo Frame inline preview over the index.
- **PR (d) — detail page (merged).** Full detail view, glossary term highlighting, SEO meta.

## Completion status (2026-04-21)

- The materials-database spec is now fully landed. The last PRs in the slice
  sequence merged on 2026-04-21, so the spec's data layer, media layer, public
  index, preview sidebar, and detail page are all on `main`.
- The implementation-plan entry in `.munkit/context.md` is marked complete to
  reflect that spec 4 is no longer in-flight.

## PR (a.5) decisions (2026-04-21)

- **Model name: `MaterialAsset`** (not `MaterialMedia` — `media` fights Rails'
  inflector since it's both singular and plural).
- **Shape**: `belongs_to :material`, `kind` enum
  `{ macro: 0, microscopy: 1, video: 2 }`, integer `position` (used to order
  microscopies `m1 → 0`, `m2 → 1`, `m3 → 2`), `has_one_attached :file`.
- **Material accessors**: `#macro_asset`, `#microscopies` (ordered by position),
  `#video_asset`.
- **Importer source: local folder**. SMEs keep originals on Drive; they
  `rclone`/sync to a local directory and a rake task walks it. No Drive API
  dependency.
- **Asset nomenclature** (from SME Drive structure):
  - Folder name (e.g. `Lifematerials-Kapok/`) lowercased equals the Material
    slug (`lifematerials-kapok`).
  - `<FolderName>.png|jpg` → macro (hero).
  - `<FolderName>-m1.tif`…`-mN.tif` → microscopies, `m1` = max zoom.
  - `<FolderName>.mp4` → video.
- **Pre-processing expected before import**: TIF/PNG → JPG, downscale macros
  to ~3000–4000 px long edge, microscopies to ~2000–3000 px, then ImageOptim.
  Originals stay on Drive.
- **Seacell-7 duplicate**: parser currently creates `pyratex-seacell-7` and
  `pyratex-seacell-7-1` because the SME listed the product twice (Bamboo +
  Seaweed headings). It is one product; fix the parser to merge duplicates by
  `trade_name`, combining their `origin_type` tag lists onto one row. Material
  count drops from 58 to 57.

## PR (a.5) outcomes

- `MaterialAsset` model + migration shipped with a partial unique index
  ensuring at most one macro and one video per material, and a full unique
  index on `(material_id, kind, position)` guarding microscopy slots.
- Custom validators mirror the DB constraints so errors come back as form
  messages, not `RecordNotUnique` exceptions: `file_must_be_attached` and
  `singleton_kind_not_duplicated`.
- `Material` gains `#macro_asset`, `#microscopies` (ordered by position), and
  `#video_asset` convenience accessors plus a `has_many :assets` with
  `dependent: :destroy`.
- `MaterialsSourceParser#entries` now merges duplicate trade names into a
  single entry, unioning their tag lists across facets. The Bamboo/Seaweed
  Seacell-7 duplicate collapses into one row carrying both `plants` and
  `seaweed` origin tags. Seed count: 57.
- `lib/material_assets_importer.rb` + `rake material_assets:import[path]`:
  walks a local folder that mirrors the Drive layout, classifies files by the
  `-mN` suffix (microscopy) / extension (image vs video), finds the matching
  `Material` by folder-name-lowercased slug, and upserts `MaterialAsset`
  rows. Idempotent; reports created / updated counts and lists skipped
  folders / ignored files.
- `lib/material_assets_preprocessor.rb` + `rake material_assets:prepare[source,output,macro,micro,quality]`:
  normalises either a single material folder or a whole synced root into an
  importer-ready mirror. Defaults: macro long edge `3600`, microscopy long
  edge `2400`, JPEG quality `90`. Images become stripped sRGB JPGs; videos
  copy through unchanged.
- Focused coverage for PR (a.5) now includes model, importer, seed, and
  preprocessor tests; keep using the naming contract tests as the guardrail
  before running bulk media ingestion.

## PR (b) plan — public index + chip-filter rail + URL + search

On a fresh branch `feat/materials-index`, targeting `main` after PR #9 merged.

### URL contract

- `GET /materials?origin_type=plants,fungi&textile_imitating=denim&application=clothing&q=cypress`
- Unknown chip slugs silently ignored (spec AC).
- Default ordering: `position ASC`.

### Filter semantics

- Within a facet: OR (any selected chip matches).
- Across facets: AND.
- Search: case-insensitive `ILIKE` on `trade_name` and the current-locale key of
  `description_translations` (e.g. `description_translations->>'en'`). Combined
  with chip filters via AND.

### Per-chip counts

- Shown next to every chip. Count = number of materials in the current filtered
  result set that carry that tag. One grouped query over `MaterialTagging` for
  the current result set.

### Card contents (no assets yet)

- Primary photo: `material.macro_asset.file` if present, else placeholder.
- `trade_name`, supplier (`supplier_name`, linked if `supplier_url`), availability
  badge, `material_of_origin`, up to 2 tag chips (first `application`, then fall
  back to `origin_type` / `textile_imitating` as needed).

### `card-media` Stimulus controller (minimal for now)

- Targets: the card root element.
- Uses IntersectionObserver — play `<video>` on enter, pause on leave.
- Honours `prefers-reduced-motion` — no autoplay when user opts out.
- Falls back silently when the card has no `<video>` and no multi-photo rotator.
- System test asserts the controller is wired (`data-controller="card-media"`
  on the card) rather than actual playback.

### I18n

- All chrome strings (`materials.index.title`, `.search_placeholder`,
  `.clear_all`, `.empty_state`, `.facets.origin_type.title` etc.,
  `.availability.<status>`) in `en` with stubs for `es`, `it`, `el`.
- Tag names are already translatable via the `Translatable` concern.

### Tests

- **Request tests** covering:
  - `GET /materials` renders all 57 seeded materials in `position` order.
  - `?origin_type=plants,fungi` filters to the union.
  - `?origin_type=plants&application=clothing` applies AND across facets.
  - Unknown chip slug (`?origin_type=spaceship`) is ignored, no error.
  - `?q=cypress` narrows by `trade_name` match.
  - `?q=…` with Spanish locale queries the `es` key (verify by creating a
    fixture with only `es` description).
  - Empty-state copy appears when no rows match.
- **System test** (Capybara): visit, toggle two chips in different facets,
  verify grid narrows; toggle again to clear; assert reduced-motion respects
  the data attribute.
- **Helper tests** for the chip-URL builder (toggle adds/removes slug,
  preserves other params).

### YARD

- `MaterialsController#index` + any new helpers.
- New model scope(s) if I add them (e.g. `Material.for_facets(slugs_by_facet)`).

### Deferred to later slices

- Preview sidebar eye icon and its Turbo Frame partial → **(c)**.
- Detail page `/materials/:slug` + glossary highlighting + SEO meta → **(d)**.

## PR (c) plan — preview sidebar

On a fresh branch `feat/materials-preview-sidebar`, targeting `main` after
PR #10 merged.

### Routes

- `resources :materials, only: [ :index, :show ]` with a `member` route
  `get :preview`. Gains `/materials/:slug` (stub in this PR, fleshed out in
  PR (d)) and `/materials/:slug/preview`.
- `param: :slug` so paths use the stable URL slug; `Material#to_param`
  already returns the slug.

### `MaterialsController#preview`

- Finds the material by slug or raises `ActiveRecord::RecordNotFound`
  (unknown slug → 404, like glossary show).
- Renders `materials/preview` partial **without the application layout**
  (pattern from `GlossaryTermsController#popover`).
- Response targets the `<turbo-frame id="preview">` mounted in
  `application.html.erb` beside the existing `modal` slot.

### `MaterialsController#show` (stub only in this PR)

- Finds by slug or 404. Renders a minimal placeholder view (hero, trade
  name, "coming soon" note) so the preview's "Open full page →" link has
  a target. PR (d) replaces the view with the full editorial layout and
  owns glossary highlighting + SEO meta.

### Preview partial contents

Per brief AC:

- Hero: `material.macro_asset.file` via `image_variant_tag(:detail)` if
  present; otherwise mint placeholder.
- `trade_name` heading.
- Supplier (link if `supplier_url`), availability badge, `material_of_origin`.
- One-paragraph `description_in(I18n.locale)` with base-locale fallback.
- Tag chips (reuse the chip styling from the index rail, read-only — no
  toggle URL).
- "Open full page →" link to `material_path(material.slug)`.
- Header has an X close button (`data-action="preview-sidebar#close"`)
  labelled via i18n.

### Layout slot

`application.html.erb` gets a sibling to the `modal` frame:

```erb
<%= turbo_frame_tag "preview" %>
```

The frame starts empty. Turbo swaps content on link click; closing clears
`innerHTML` (same pattern as `modal_controller.js`).

### Eye icon on the card

- Added to the top-right corner of the card image in `_card.html.erb`.
- Always visible (no hover-only — mobile parity).
- `data-turbo-frame="preview"`, `aria-label` from i18n.
- `data-role="open-preview"` marker for tests.

### Preview-sidebar Stimulus controller

`preview_sidebar_controller.js`:

- On `connect`: saves `document.activeElement`, moves focus to the
  dialog, listens for Escape at document level.
- `close()`: clears the frame (`frame.innerHTML = ""`), removes the
  Escape listener, restores the saved focus.
- `backdrop(event)`: closes only when the click target is the backdrop
  (mirrors `modal_controller.js`).
- No mobile drag-down — brief says "if cheap; otherwise an X button".
  X button covers mobile.

### Responsiveness

- Desktop (`sm+`): right-anchored panel, `max-w-md`, full-height, sits
  above the grid via a fixed-position container inside the partial.
- Mobile: bottom sheet, ~85vh, rounded top corners.
- One Tailwind-driven partial with responsive classes; no JS branching.

### ARIA

- `role="dialog"`, `aria-modal="false"` (it's a peek, the index stays
  interactive).
- `aria-labelledby` pointing at the trade-name heading's id.

### Tests

- **Request tests** covering:
  - `GET /materials/:slug/preview` → 200, renders trade name + description
    + "Open full page" link, no `<html>` wrapper (layout=false).
  - `GET /materials/unknown/preview` → 404.
  - `GET /materials/:slug` → 200 (minimal stub view).
  - `GET /materials/unknown` → 404.
- **System test**: visit `/materials`, click eye icon, assert preview
  frame populated; press Escape, assert frame cleared; click eye icon
  again, click "Open full page →", assert navigation to detail page.

### I18n

- `materials.preview.close` → "Close preview" (+ stubs).
- `materials.preview.open_full_page` → "Open full page →" (+ stubs).
- `materials.show.coming_soon` → placeholder copy for the stub detail
  view; PR (d) removes/replaces this key.

### Overlay-slots pattern → MEMORY.md

After PR (c), add a short Key Patterns entry noting:

> Two layout-level Turbo Frame slots live in `application.html.erb`:
> `modal` (confirm-and-dismiss flows, e.g. glossary delete) and
> `preview` (peek-and-dismiss flows, e.g. material preview sidebar).
> Dismissal is always by clearing `innerHTML`. Prefer a new slot only
> when the interaction semantics differ meaningfully — otherwise reuse.

### Deferred to PR (d)

- Full editorial detail page content (sensorial_qualities,
  what_problem_it_solves, interesting_properties, structure, micrograph
  gallery).
- Glossary-term highlighting on detail-page long-form prose.
- Localised `<title>` + `<meta description>` SEO meta.
- Removal of the `materials.show.coming_soon` stub key.

## PR (c) outcomes

- Routes: `resources :materials, only: [:index, :show], param: :slug`
  with a `get :preview` member. Gains `/materials/:slug` and
  `/materials/:slug/preview`.
- `MaterialsController#preview` renders the preview partial with
  `layout: false` (same pattern as `GlossaryTermsController#popover`);
  `#show` is a minimal stub that PR (d) will replace.
- `application.html.erb` now carries two overlay slots side-by-side —
  `modal` (confirm) and `preview` (peek). Memory note recorded.
- `_preview.html.erb` renders the hero (`image_variant_tag(:detail)`),
  trade name, supplier, availability badge, locale-aware description,
  read-only tag chips per facet, and an "Open full page →" link marked
  `data-turbo-frame="_top"` so it navigates the whole page out of the
  frame.
- Preview dialog wears `role="dialog"` + `aria-modal="false"`; heading
  id is slug-scoped so multiple prior previews in the DOM never collide.
- `preview_sidebar_controller.js` mirrors `modal_controller.js`:
  Escape (document-level `keydown.esc@document`), backdrop click, and
  the X button all call `close()`, which clears the frame's innerHTML
  and restores focus to the triggering card eye icon.
- `_card.html.erb` gains an eye-icon `link_to` targeting
  `preview_material_path` with `data-turbo-frame="preview"` and a
  localised `aria-label`. Always visible (no hover-only gating, for
  mobile parity).
- I18n: `materials.preview.{close,open_label,open_full_page}` and
  `materials.show.{back_to_index,coming_soon}` in `en` with mirrored
  stubs in `es`, `it`, `el`. The `coming_soon` key is scoped to the
  stub and will be removed in PR (d).
- Tests: 8 new request tests (eye-icon wiring, preview 200/404, dialog
  ARIA, no-layout render, show 200/404); 2 new system tests (open +
  Escape dismiss, follow "Open full page →"). Full suite: 290 runs /
  1965 assertions / green. 5 system runs / 16 assertions / green.
- Self-review note: initial system test for navigation away from the
  preview failed because the link stayed trapped in the `preview`
  frame; fixed by `data-turbo-frame="_top"`. Caught the pattern before
  the PR went up and documented it in the MEMORY overlay-slots entry.

## PR (b) outcomes

- `MaterialsController#index` parses per-facet CSV params, drops unknown
  facets/slugs, and combines chip filters (OR within facet, AND across
  facets) via `MaterialTagging` subqueries. Search ILIKEs `trade_name` plus
  the current-locale key of `description_translations` with
  `sanitize_sql_like` + named binds.
- Controller eager-loads `assets: { file_attachment: :blob }` so the 57
  cards render in constant queries — caught by self-review.
- `MaterialsHelper#materials_chip_toggle_url` / `#materials_chip_active?`
  power the chip rail; drops empty facets from URLs and preserves the
  search query on every toggle.
- `_card.html.erb` uses `image_variant_tag(..., preset: :card)` when a
  macro asset is present; silently shows the mint placeholder background
  otherwise so the grid never has visual holes while media import lags.
- `card_media_controller.js` plays any `<video>` inside the card on
  IntersectionObserver entry and honours `prefers-reduced-motion`.
  Degrades silently when the card has no video.
- Chrome i18n: full `en`, mirror stubs for `es`, `it`, `el` (page title,
  lead, search placeholder, clear-all, empty state, facet titles,
  availability labels). Tag names keep flowing through Translatable with
  English fallback.
- 18 request tests + 9 helper tests + 3 system tests; full suite:
  282 runs / 1835 assertions / green. System tests green.
- Per-chip counts are computed over the current filtered set (not the
  "what would toggling this add" interpretation) per the spec plan
  section above.

## PR (d) plan — detail page + glossary highlight + SEO meta

On a fresh branch `feat/materials-detail-page`, targeting `main` after
PR #11 merged. Replaces the current `show.html.erb` stub (trade_name +
"coming soon" copy under `materials.show.coming_soon`) with the full
editorial layout.

### Page structure

Single-column editorial layout, prose column max-width ~768 px, hero
breaking out a little wider.

1. **Back link** → `materials_path`, top-left, subdued.
2. **Hero** — macro at `preset: :hero` (1600×900 cap). Mint placeholder
   block when no macro is attached, so empty-state looks intentional.
3. **Header** — `trade_name` (H1), supplier line (linked if
   `supplier_url`), availability badge, `material_of_origin`, tag chips
   grouped by facet (same chip styling as the preview sidebar).
4. **Prose sections**, in reading order, each hidden when its
   locale-fallback value is blank:
   1. `description`
   2. `sensorial_qualities`
   3. `what_problem_it_solves`
   4. `interesting_properties`
   5. `structure`
5. **Micrograph gallery** — grid of microscopies at `preset: :detail`,
   each wrapped in `<a href=rails_blob_url(...) target=_blank
   rel=noopener>` so the native browser view handles zoom. Section
   hides entirely when `material.microscopies` is empty.

### Prose rendering pipeline

```erb
<%= glossary_highlight(
      sanitize(
        simple_format(material.description_in(I18n.locale) ||
                      material.description_in(Material::BASE_LOCALE)),
        tags: %w[p br]
      )
    ) %>
```

- `simple_format` paragraph-breaks → `<p>`.
- `sanitize` allow-list restricted to `p`/`br` (seeded prose is plain
  text).
- `glossary_highlight` wraps known terms last, returns a safe buffer.

Extract a `material_prose(material, field)` helper to avoid repeating
the pipeline five times in the view.

### Video: deferred

Cards on the index already autoplay clips. A still hero on the reading
page is calmer and matches the editorial tone. Ship video on the detail
page as a follow-up only if SMEs or usability testing ask for it.

### Micrograph full-size: new-tab link, not lightbox

Each `:detail` variant sits inside `<a target=_blank rel=noopener>`
linking to the blob URL. No lightbox Stimulus controller in this PR —
escalate to a modal viewer later if participants want prev/next/zoom.

### SEO meta

- `content_for :title` → `@material.trade_name`; layout interpolates
  the site suffix.
- Add `<meta name="description">` slot to the application layout if
  missing. Detail page sets it via `content_for :meta_description` to
  the first ~155 chars of the locale-fallback description, stripped of
  HTML.
- Page is indexable; no `noindex` directive.

### I18n

- **Remove** `materials.show.coming_soon` in all four locale files.
- Keep `materials.show.back_to_index`.
- Add `materials.show.sections.description`, `.sensorial_qualities`,
  `.what_problem_it_solves`, `.interesting_properties`, `.structure`,
  `.micrographs` for section headings.
- Add `materials.show.micrograph_alt` (interpolated alt text with
  material name + index).
- `en` filled; `es`/`it`/`el` mirror with English copy pending
  translation.

### Tests (gate before implementation)

- **Request tests** on `GET /materials/:slug`:
  - 200 with `@material.trade_name` as H1 text
  - `<meta name="description">` rendered with a non-blank content attr
  - unknown slug → 404 (regression over what PR (c) already asserted
    for the preview route — now on the show path)
  - `I18n.with_locale(:es) { get material_path(...) }` renders the
    Spanish description when present, base-locale when not
  - no "translation missing" leakage in any rendered section heading
  - sections hidden when locale-fallback value is blank (fixture
    material carrying only `description_translations`)
- **Glossary-highlight integration** — create a `GlossaryTerm`, create
  a material whose description contains its `display_term`, assert the
  rendered HTML wraps the token with the term's popover trigger
  element.
- **System test**:
  - visit `/materials/:slug`, verify H1, supplier link, availability
    badge, one prose section, at least one tag chip
  - micrograph gallery renders N thumbnails when fixture has N
    microscopies, each thumbnail's link points to the blob URL
  - "Back to materials" link lands on `/materials`

### YARD

- `MaterialsController#show` — 404 behaviour, locale swap.
- `material_prose(material, field)` helper — pipeline contract.

### Deferred past this PR

- Hero-as-video / autoplay on the detail page.
- Lightbox viewer for micrographs (prev/next, zoom).
- Related-materials rail ("more from this facet", "same supplier").
- Share button for copying canonical URL.
- Content-pass to fill sparse `sensorial_qualities` entries.

## PR (d) outcomes

Shipped on `feat/materials-detail-page`. Replaces the show stub with the
full editorial layout; closes the last slice of the materials-database
spec.

- **Model constant** — `Material::TRANSLATED_ATTRIBUTES` lists the five
  prose fields in reading order, so the view iterates instead of
  repeating the pipeline.
- **Helpers** — `material_prose` runs
  `*_in(locale) || *_in(BASE_LOCALE) → simple_format → sanitize(p/br) →
  glossary_highlight`, returns `nil` when blank so the section hides.
  `material_meta_description` strips/squishes/truncates the fallback
  description to 155 chars for the meta slot.
- **Layout meta slot** — `application.html.erb` renders
  `<meta name="description">` only when `content_for?(:meta_description)`,
  strips tags and squishes at render time as defence-in-depth.
- **View structure** — back link → hero (`preset: :hero`, mint
  placeholder when no macro) → header (H1, supplier chip with
  `open_supplier` fallback label when URL present but name absent,
  availability badge, `material_of_origin`, tag chips grouped per facet
  via `[data-role="detail-facet"][data-facet="<facet>"]`) → prose
  sections wrapped in `[data-role="section-<attribute>"]` → micrograph
  gallery `[data-role="micrograph-gallery"]`, each thumbnail a
  `target=_blank` link to `rails_blob_url(micrograph.file)`.
- **Controller** — `set_material` eager-loads `assets: { file_attachment:
  :blob }, tags: {}` to cover both hero and gallery; added YARD on
  `#show` explaining 404 and locale behaviour.
- **I18n** — removed `materials.show.coming_soon` in all four locales;
  added `materials.show.sections.{description,sensorial_qualities,
  what_problem_it_solves,interesting_properties,structure,micrographs}`,
  `micrograph_alt`, `open_supplier`, `tags_heading`. `es`/`it`/`el`
  translations landed in this PR (not placeholders).
- **Tests**
  - Request: 13 assertions covering H1, back link, per-attribute section
    data-role presence/hiding, locale read via `?locale=es`
    (ApplicationController's `set_locale` around_action reads params, so
    `I18n.with_locale` blocks around `get` do *not* work — pass locale
    as a URL param), base-locale fallback, translation-missing leakage
    check, meta description non-blank, `<title>` match, tag-chip markup,
    glossary popover wrapping inside `[data-role="section-description"]`,
    empty micrograph gallery hidden.
  - System (11 runs total including existing): H1 + prose + back link,
    back link navigates to index, supplier link present when
    `supplier_url` set (uses Pyratex Musa 1 which has URL but no
    supplier_name — forced the `open_supplier` fallback label).
- **Final suite** — 305 runs, 2027 assertions, 0 failures; RuboCop clean;
  Brakeman clean.

### Gotchas captured

- Locale in controller tests must be URL-param, not block: the
  `around_action :set_locale` in `ApplicationController` reads
  `params[:locale] || cookies[:locale]` and overrides anything set
  outside the request.
- `assert_select` takes the message as a **positional** argument, not a
  keyword. `assert_select sel, 0, message: "..."` raises ArgumentError.

## PR (d) design iteration (2026-04-21)

After first sight of the detail page the user flagged three issues that
warranted a follow-up pass still inside PR (d):

1. Index card didn't link to the detail page — only the preview icon was
   actionable.
2. Layout was text-heavy for a catalogue page; needed to put media
   front-and-centre and reserve space for the full micrograph set + the
   product video.
3. Meta data (supplier, origin, availability, tag chips) was a loose
   inline row with no labels — hard to read, chips looked disconnected.

**Decisions:**

- **Covering-link card** — whole-card hit target via a stretched
  pseudo-element on the title `<a>` (`before:absolute before:inset-0`).
  The preview affordance and supplier link stay independently clickable
  by placing them on a higher stacking level (`relative z-10` or
  `absolute ... z-10`). No JS, no event-propagation hacks.
- **Gallery** — replaces the old top-of-page hero + bottom-of-page
  micrograph grid with a single side-by-side gallery: large main viewer
  on the left, vertical thumbnail strip on the right (stacks to rows on
  mobile). Default active item is **video if present, else macro**,
  even though the video lives at the bottom of the thumbnail order
  per user sketch intent. Thumbnails run in priority order: video →
  macro → microscopies by `position`.
- **Thumbnail swap** — `material-gallery` Stimulus controller. All
  media elements render inside the viewer; the controller toggles
  `hidden` and pauses any off-screen `<video>` so only the active one
  can play. Data contract: `data-material-gallery-target="media"` +
  `data-media-key` on each media element, matching
  `data-media-key` on the `data-material-gallery-target="thumb"`
  buttons. Thumbnails carry `data-gallery-active="true|false"` rather
  than an `active` CSS class so tests don't couple to styling.
- **Meta sidebar** — three-row `<dl>` with Heroicons + label + value:
  supplier (external-link-arrow when it's a link), availability (pill
  badge), raw material. Each row marked with `data-role="meta-…"` for
  stable test selectors.
- **Tag groups** — chips are now grouped under a facet heading
  (reusing the index facet titles — `materials.index.facets.<facet>.title`)
  rather than a flat list. Wrapper marker
  `[data-role="detail-facet-group"][data-facet="<facet>"]`, with the
  existing `[data-role="detail-facet"][data-facet]` UL kept inside for
  backwards-compatibility with older selectors.
- **Section icons** — one Heroicon per prose section (document-text,
  sparkles, light-bulb, beaker, squares-2x2). Inlined via a tiny
  `heroicon(name, options)` helper in `IconsHelper`; paths captured
  verbatim from the outline variant on heroicons.com.

**Tests:**

- Card covering link — every card contains an `<a>` to
  `material_path(slug)`.
- Gallery absence when no assets, presence when 1+ assets, thumbnail
  stack only when 2+ assets, default-active video-over-macro, default
  macro when no video. Attaching files in tests uses `assets.build` +
  `file.attach` before `save!` (the `file_must_be_attached` validator
  rejects `create!` with no attachment).
- Meta sidebar rows present for supplier / availability / origin.
- Tag group wrapper + facet heading + chip UL nested correctly.
- System test: attach macro + microscopy, visit page, assert macro is
  default active, click the microscopy thumb, assert active flips and
  the macro media element gains `.hidden`.
- Final suite: 312 runs, 2180 assertions, 0 failures. RuboCop clean;
  Brakeman clean.

**Deferred (explicitly):**

- Real video posters — the video thumb currently overlays a play icon
  on the macro image; when the importer starts extracting real posters
  we'll swap that in.
- Lightbox/fullscreen for the main viewer.
- Pinch-to-zoom on micrographs.

## PR (a) outcomes

### Source-of-truth decision

`docs/materials-db.md` is the **non-authoritative authoring source**. The SME
edits it in plain Markdown; `db/seeds/materials.yml` is the **reconciled,
committed seed**. The `lib/materials_source_parser.rb` plus
`rake materials:reconcile_seed` task bridge them idempotently.

The earlier CSV and humanized-texts doc were abandoned after researchers said
spreadsheets weren't workable for them. No authoritative import from Notion.

### Tag vocabulary (SME-pending feedback)

Three facets, English names only for now; other locales fall back via
`Translatable`:

- `origin_type` (8): plants, fungi, animals, recycled_materials, seaweed,
  bacteria, protein, microbial.
- `textile_imitating` (12): leather, denim, silk, wool, felt, mesh,
  conventional_cotton, conventional_linen, conventional_nylon,
  conventional_polyester, synthetic_fibres, synthetic_rubber.
- `application` (10): clothing, accessories, footwear, filling, home_textiles,
  furniture, automotive, technical_textiles, safety_equipment, art.

User will ship PR (a), then collect SME feedback on the `application` list.

### Parser reconciliation decisions

- **Multi-match on applications.** One bullet in the source ("Footwear and
  accessories") legitimately maps to two tags. `match_all_vocabulary` collects
  every match per bullet.
- **Specificity-ordered patterns.** `safety_equipment` / `automotive` patterns
  come before `technical_textiles`; over-broad textile→home_textiles fallback
  was removed to prevent false positives on e.g. Cypress Denim.
- **Duplicate slug disambiguation.** "Pyratex Seacell 7" appears twice in the
  source (under Bamboo and Seaweed headings). Parser suffixes the second with
  `-1`, mirroring the source's own anchor convention (`{#pyratex-seacell-7-1}`).
- **Availability heuristic over full body.** "work in progress" and Zaragoza
  researcher signals appear across fields (`retails`, `interesting_facts`), not
  just `availability`. Scanning the full body moved the distribution from
  51/6/1 to 43/11/4 commercial/in_development/research_only.

### Deferred to later PRs or the SME pass

- `sensorial_qualities` remains sparsely populated — source prose is unlabeled;
  needs a dedicated content pass.
- Spanish / Italian / Greek translations: deferred; base-locale English is
  required, others fall back.
- Chip-filter OR/AND semantics per spec (within-facet OR, across-facet AND)
  live in PR (b) — no indexes added specifically for that yet; will revisit
  after profiling the index query.
- Overlay-slots pattern note for `MEMORY.md` deferred to end of PR (c) as
  agreed.

### Code-review (self) notes

- Removed dead `attr_accessor :tagging_ids_to_keep` — leftover from an earlier
  refactor, written but never read.
- All three migrations reversible, indexed, FK-constrained, with NOT NULL +
  defaults on JSONB translation columns.
- Case-insensitive slug uniqueness on Material paired with `LOWER(slug)`
  index (matches `GlossaryTerm` pattern).
- 39 new tests across 5 files, 235 runs total, green.

## Open Questions

- Do we want an admin curator UI for Materials (mirror of Glossary) or is the
  reconcile-seed workflow enough? Answer from spec: curator UI is out of scope
  for now; reconcile-seed is the editing path.

## Ideas

- A `rake materials:lint` task that flags entries missing
  `sensorial_qualities` or with suspicious availability heuristics, to drive
  the SME content pass.

## Research

- `GlossaryTerm` was the reference model for slug-on-create, seed loader
  shape, and base-locale validation.
