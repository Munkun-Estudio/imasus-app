# Materials database

## What

A public, multilingual, editorial browse experience for the IMASUS sustainable-materials catalogue. Participants land on `/materials`, skim a card grid that **moves** (short clips play as cards scroll into view; photos cycle on each card), narrow the catalogue with **chip-style multi-select filters**, peek at a material via a **preview sidebar** without leaving the grid, and open a permanent `/materials/:slug` detail page for deep reading and sharing.

No curator CRUD in this spec — content ships as a seed reconciled from `docs/materials-db.csv` and `docs/DB-materials-humanized-texts.md`. A follow-up `materials-curator` spec will add in-app editing when the consortium wants live authoring.

## Why

The materials database is the first piece of workshop content that participants browse to look for **inspiration** — not information to be consulted like a reference. The UX has to earn attention, not just present data. Scrolling cards that autoplay short clips, editorial cover imagery, and chip filters that let participants narrow by "what's it made from", "what does it replace", and "what could I use it for" match the way students actually shop for ideas.

This is also the spec that validates three downstream patterns:

- **Active Storage + `ImageVariants`** (from spec 3) applied to real content for the first time.
- **`Translatable` concern reuse** (from spec 5) on a second model, confirming the pattern travels.
- **A faceted chip-filter + preview-sidebar interaction vocabulary** that log-entry material embeds, challenge cards, and project-publication pages will reuse.

The data in `docs/` is messy, partial, and non-authoritative. This spec treats it as **raw material, not source of truth**: we seed best-effort from what's there, model from what participants need, and let missing fields gracefully hide.

## Acceptance Criteria

### Data model

- [x] A single `Material` model. No `MaterialOrigin`, no `MaterialSubtype` model — origin and variant information live as plain string / array fields or as tags.
- [x] Plain-string fields: `slug` (unique, URL-safe, derived from `trade_name`), `trade_name`, `supplier_name`, `supplier_url`, `material_of_origin` (e.g. "Cypress", "Mushroom" — granular, displayed on the card + detail, not a filter chip).
- [x] Translatable JSONB fields (reusing the `Translatable` concern from the glossary spec): `description_translations`, `interesting_properties_translations`, `structure_translations`, `sensorial_qualities_translations`, `what_problem_it_solves_translations`. Each holds `{ en, es, it, el }`. Missing locales fall back via `I18n.fallbacks`.
- [x] Enum `availability_status` with values `commercial`, `in_development`, `research_only`. Drives a small badge on the card and derives from the source docs' "availability / not available" hints at seed time.
- [x] Integer `position` for curated ordering on the index (editorial control, not alphabetical). Lower = earlier in the grid.
- [x] Validations: presence of `trade_name` and `slug`; case-insensitive uniqueness of `slug`; presence of `availability_status`; presence of base-locale (`en`) `description`. Nothing else is required — the UI tolerates sparse records.

### Tags (multi-facet, multi-select)

- [x] A `Tag` model with `slug`, `facet` (enum: `origin_type`, `textile_imitating`, `application`), and a translatable `name_translations` JSONB field. Uniqueness is `(facet, slug)`.
- [x] A `MaterialTagging` join (`material_id`, `tag_id`) with a unique index on the pair.
- [x] `Material has_many :taggings, has_many :tags through: :taggings`. Convenience scopes `tags_for(:origin_type)` / `:textile_imitating` / `:application`.
- [x] Three facets, seeded vocabulary:
  - `origin_type`: Plants, Fungi, Animals, Recycled materials, Seaweed, Bacteria, Protein, Microbial.
  - `textile_imitating`: Leather, Denim, Silk, Conventional nylon, Conventional polyester, Wool, Conventional cotton, Synthetic fibres, Synthetic rubber, Conventional linen, …  (derive from the source docs).
  - `application`: Clothes, Accessories, Footwear, Filling, Home textiles, Automotive, Technical textiles, Safety equipment, … (derive from the source docs).

### Media attachments (Active Storage)

- [x] `has_many_attached :photos` — card rotator + detail page gallery.
- [x] `has_one_attached :clip` — short MP4 / WebM, autoplayed muted/looped on the card when the card is in the viewport. Direct-served from S3, no variant pipeline (tracked in `notes.md` as a follow-up if needed).
- [x] `has_many_attached :micrographs` — SEM / ESEM imagery shown on the detail page, with their existing `ImageVariants`-powered thumbnail/medium/large variants.
- [x] All attachments are optional. Cards and detail sections render graceful placeholders when attachments are absent.

### Seed

- [x] `db/seeds/materials.yml` holds ~30 canonical entries reconciled from `docs/materials-db.csv` + `docs/DB-materials-humanized-texts.md`. Entries with only English prose are loaded as-is; locales that aren't present in the source are simply not set, and the `Translatable` fallback handles the rest. Obvious stubs (empty humanized-doc sections) are skipped rather than imported blank.
- [x] `db/seeds/material_tags.yml` holds the tag vocabulary per facet, with translatable names.
- [x] `Material.seed_from_yaml!` and `Tag.seed_from_yaml!` are idempotent (find-or-initialize by slug) and safe to re-run.
- [x] No images, clips, or micrographs are seeded — assets land in a separate content-ingestion pass (tracked in `notes.md`).

### Public index (`GET /materials`)

- [x] Editorial card grid, responsive (1 / 2 / 3 columns at the app's usual breakpoints).
- [x] Each card shows: primary photo (placeholder if absent), `trade_name`, supplier, `material_of_origin`, an availability-status badge, and up to two tag chips.
- [x] **Card media behaviour** — a Stimulus controller (`card-media`):
  - When a card enters the viewport (IntersectionObserver): if a `clip` attachment exists, start playing it muted + looping. When it leaves, pause.
  - Photos cycle on a slow interval (or on hover on devices with a pointer) when no clip is present and the card has more than one photo.
  - Reduced-motion preference (`prefers-reduced-motion`) is respected: no autoplay, no cycling.
- [x] **Chip-filter rail** above the grid — three chip groups, one per facet (`origin_type`, `textile_imitating`, `application`). Each chip toggles on / off. Multi-select within a facet = OR; across facets = AND. Active chips show a visible toggled state and a count of matches. A "Clear all" control resets the rail.
- [x] Filter state is URL-bound (`?origin_type=plants,fungi&application=clothes`) so URLs are shareable and the back button works.
- [x] A simple search input on the rail performs case-insensitive `ILIKE` on `trade_name` and on the current-locale `description` JSONB key. Combined with chip filters via AND.
- [x] Empty-state copy when filters match no materials ("No materials match your filters. Try clearing some chips.").
- [x] Default ordering on the index is `position ASC`.

### Preview sidebar (eye icon)

- [x] Each card shows an **eye icon** affordance. Clicking it opens a **slide-in preview sidebar** populated by a Turbo Frame (`<turbo-frame id="preview">` mounted in the layout).
- [x] Desktop: right-hand panel overlaying the grid (grid stays visible and scrollable in the remainder). Mobile: bottom sheet covering ~85% of the viewport.
- [x] Sidebar content: hero photo or first frame of the clip, `trade_name`, supplier, availability badge, one-paragraph `description`, tag chips, and an "Open full page →" link to `/materials/:slug`.
- [x] Dismissal: Escape, backdrop click (desktop) / drag-down (mobile, if cheap; otherwise an X button), the X button, or clicking the same eye icon again. Focus returns to the triggering card on close.
- [x] Only one preview is open at a time. Opening another replaces the current content (Turbo Frame swap).
- [x] ARIA: the sidebar is `role="dialog"` with `aria-modal="false"` (it's a peek, not a modal) and a labelled heading.

### Public detail (`GET /materials/:slug`)

- [x] Editorial layout — hero photo or clip, `trade_name`, supplier + link, availability badge, tag chips, `material_of_origin`.
- [x] Sections render conditionally and collapse when empty:
  - `description`
  - `sensorial_qualities` (warm / soft / breathable prose from the humanized doc — a differentiator the CSV lacks).
  - `what_problem_it_solves`
  - `interesting_properties`
  - `structure`
  - Micrograph gallery (renders only when `micrographs` are attached; uses `ImageVariants` thumbnails, opens to a full-size view).
- [x] Glossary-term highlighting is applied to the long-form prose sections (`description`, `sensorial_qualities`, `what_problem_it_solves`, `interesting_properties`, `structure`), via the `glossary_highlight` helper from spec 5.
- [x] Unknown slug → 404.
- [x] Localised `<title>` and `<meta description>`; indexable.

### Navigation

- [x] The existing "Materials DB" sidebar item now routes to `/materials` (currently wired to the stub `materials/index`).

### I18n

- [x] All chrome strings (filter rail labels, chip group headings, "Open full page", empty states, availability badges, "Clear all", search placeholder, preview sidebar close label, section headings on the detail page) go through `t(…)`. `en` filled; `es`, `it`, `el` stubbed (same pattern as the glossary spec).
- [x] Switching the request locale swaps the translatable fields (description, sensorial qualities, etc.) where the target-locale value exists; falls back to `en` otherwise, with no "translation missing" leakage in user-visible copy.
- [x] Tag names are localised via the `Translatable` concern's reader.

### Tests (Minitest — tests gate implementation)

- [x] Model: validations (trade_name, slug, availability_status, base-locale description); slug generation; uniqueness; `tags_for(facet)` scope; locale-aware reader fallback.
- [x] `Tag` model: uniqueness per `(facet, slug)`; translatable name reader.
- [x] Seed: `Material.seed_from_yaml!` and `Tag.seed_from_yaml!` are idempotent (running twice doesn't duplicate); unknown tag slugs in a material entry raise a clear error.
- [x] Request: `GET /materials` renders every seeded material; chip filters narrow correctly (single-facet OR, cross-facet AND); `?origin_type=plants,fungi` reflects in the rendered chip state; unknown chip values are ignored; search narrows by `trade_name`; unknown slug on `/materials/:slug` returns 404.
- [x] Request: `GET /materials/:slug/preview` (the Turbo Frame target) renders the preview partial without the application layout; unknown slug → 404.
- [x] Controller test: locale swap changes the rendered description on the detail page.
- [x] Glossary-highlight integration: the detail page wraps known glossary terms as popover triggers.
- [x] System test: visit `/materials`, toggle two chips in different facets, verify the grid narrows; open a preview sidebar, verify content and Escape dismissal; navigate from preview to detail page; verify an in-view card starts playing its clip (pragmatic: assert the `<video>` element has `autoplay` / the controller has connected, not actual playback).

### YARD

- [x] Public methods on `Material`, `Tag`, and any new helper (`materials_filter_url`, `card_media` Stimulus bridge helpers if we add any) documented in English.

### Docs

- [x] `.munkit/MEMORY.md` **Key Patterns** gets a one-liner for the **chip-filter rail** and for the **preview-sidebar** interaction, since log-entry material embeds (spec 11) and challenge cards (spec 6) will reuse both.
- [x] `.munkit/context.md` "Implementation Plan" entry for spec 4 is marked complete when the PR merges.
- [x] `.munkit/specs/2026-04-17-materials-database/notes.md` records: the reconciled seed strategy, the chip-filter OR/AND semantics, the decision to treat the source docs as non-authoritative, and deferred items (asset ingestion, video variants, full-text search, curator CRUD).

## Out of Scope

- **Curator CRUD.** Follow-up `materials-curator` spec when the consortium wants in-app editing. For now, content is seed-driven.
- **Real image / clip / micrograph ingestion.** Attachment machinery ships with the spec; bulk asset download + `ActiveStorage` backfill is a separate content pass.
- **Video variants / transcoding.** Direct-serve uploaded MP4 / WebM for now. A `video-variants` spec can add an ffmpeg pipeline if bandwidth becomes an issue.
- **Full-text search (pg_trgm / tsvector).** Simple `ILIKE` covers the current catalogue size (~30 entries). Escalate when it stops being enough.
- **Material-embed-in-log-entry cards.** Belongs with the process-log spec (spec 11). The detail page is designed so the embed card can reuse its hero + one-paragraph description, but the embed itself is not in this spec.
- **"See also" cross-linking, comparison view, saved / favourited materials.** All deferrable.
- **Approval workflow, soft-delete, audit log.** Out of scope regardless of when curator CRUD arrives.

## Dependencies

- Spec 1 (`app-shell-and-navigation`) — sidebar, layout, Tailwind tokens, I18n plumbing.
- Spec 3 (`image-hosting-strategy`) — Active Storage + S3 + `ImageVariants` concern and `image_variant_tag` helper.
- Spec 5 (`glossary`) — `Translatable` concern, `glossary_highlight` helper, Turbo Frame / modal patterns, locale-aware fallback behaviour.

Downstream: home page (spec 7) pulls a "featured materials" row from here; log entries (spec 11) embed materials as cards in rich text; project-publication (spec 12) surfaces referenced materials on the public page.

## Notes

- **Source docs are raw material, not authority.** Model from what participants need, not from what the CSV columns or the humanized-doc hierarchy imply. Where the two disagree, favour the UX; where both are sparse, let the field be blank.
- **The chip-filter rail is the first faceted-filter UI in the app.** Keep the Stimulus controller generic enough that challenge cards (spec 6) and the project catalogue (spec 14) can reuse it by passing a different facet list. Document the URL-param shape so downstream specs can link to pre-filtered views.
- **The preview sidebar is the second Turbo-Frame-based floating surface** after the glossary delete-confirmation modal. Confirm in `notes.md` whether we promote the layout-level frame slot pattern (`<turbo-frame id="modal">`, `<turbo-frame id="preview">`) to a generic **overlay slots** memory entry after this spec.
- **Seed images late, on purpose.** The assets are heavy and not downloaded yet. Build the page around empty-state placeholders so the design stays honest about the state of the content.
- **`material_of_origin` stays a plain string** (not a tag) because chips for ~25 distinct origins would overwhelm the rail; it still appears on the card and detail page for context, and is searchable via the search input.
- **Glossary-term highlighting inherits from spec 5** and applies only on the detail page's long-form prose — the card grid and preview sidebar stay clean.
