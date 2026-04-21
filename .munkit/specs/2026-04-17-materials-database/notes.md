# Notes: 2026-04-17-materials-database

## Implementation slice plan (agreed with user on 2026-04-21)

The spec ships across five PRs on `feat/materials-database`:

- **PR (a) — data layer (merged pending).** Migrations, models, seed loaders,
  reconciled YAML seeds, YARD. No user-facing routes yet.
- **PR (a.5) — media layer.** `MaterialAsset` model (macro/microscopy/video kinds),
  local-folder importer + rake task, Seacell-7 duplicate merge at the parser.
  Inserted between (a) and (b) so the index/detail PRs can assume asset
  accessors are present. Decided 2026-04-21.
- **PR (b) — public index.** Materials index page, chip-filter rail, URL binding,
  search box.
- **PR (c) — preview sidebar.** Turbo Frame inline preview over the index.
- **PR (d) — detail page.** Full detail view, glossary term highlighting, SEO meta.

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
- 21 new tests (15 model, 5 importer, 1 seed). Full suite: 256 runs /
  956 assertions / green.

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
