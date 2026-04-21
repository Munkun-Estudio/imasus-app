# Notes: 2026-04-17-materials-database

## Implementation slice plan (agreed with user on 2026-04-21)

The spec ships across four PRs on `feat/materials-database`:

- **PR (a) — data layer (this PR).** Migrations, models, seed loaders, reconciled
  YAML seeds, YARD. No user-facing routes yet.
- **PR (b) — public index.** Materials index page, chip-filter rail, URL binding,
  search box.
- **PR (c) — preview sidebar.** Turbo Frame inline preview over the index.
- **PR (d) — detail page.** Full detail view, glossary term highlighting, SEO meta.

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
