# Glossary

## What

A public, multilingual glossary of terms used across IMASUS workshop content, with:

- A `GlossaryTerm` model carrying translated `term`, `definition`, `examples`, plus a `category`.
- A public glossary page at `/glossary` with sticky A–Z navigation and category filter pills, and an individual term page at `/glossary/:slug`.
- A reusable Stimulus popover component that wraps glossary terms where they appear in rendered rich-text content and reveals the definition on activation.

No authentication required — glossary content is public (see `context.md` — "Visibility and privacy").

## Why

Workshop content — training modules, materials, challenges — uses specialised vocabulary from materials science, imagineering, and industrial design. Participants come from mixed disciplinary backgrounds and need a shared lexicon. Embedding term highlighting in place, rather than forcing participants to leave the page to consult a glossary, keeps learning in context and respects reading flow.

This is also the first **reusable public-content slice** after training modules: it validates the I18n storage pattern, seed-driven data flow, and Stimulus-based UI primitives that materials (spec 4) and log entries (spec 11) will reuse.

## Acceptance Criteria

### Data model

- [x] `GlossaryTerm` with `slug`, `category`, and JSONB translatable fields: `term_translations`, `definition_translations`, `examples_translations`. Each holds `{ en, es, it, el }` keys.
- [x] A reusable `Translatable` concern exposes locale-aware readers (`term`, `definition`, `examples`) backed by the `*_translations` columns, with `I18n.fallbacks` applied on missing keys. The concern is generic enough to be reused by materials (spec 4) and challenges (spec 6).
- [x] `examples` holds zero-to-many example phrases per locale (array-valued in JSONB).
- [x] `slug` is unique, URL-safe, derived from the base-locale (`en`) `term`.
- [x] `category` is a string column; inclusion validation against `%w[methodology application industry science]`.
- [x] Validations: presence of base-locale `term` and `definition`; presence and inclusion of `category`; case-insensitive uniqueness of base-locale `term`.

### Seed

- [x] `db/seeds/glossary_terms.yml` holds ≥ 10 representative terms covering all four categories, with `en` filled and at least stub values for `es`, `it`, `el` to exercise the pipeline.
- [x] A seed loader reads the YAML and is idempotent (find-or-initialize by slug).

### Public pages

- [x] `GET /glossary` renders the index: sticky A–Z jumpnav, category pills, and the current filtered term list.
- [x] Letters with no terms are visually de-emphasised or hidden; category pills reflect the non-empty categories in the seed.
- [x] `GET /glossary/:slug` renders the full term page (term, definition, examples, category, link back to index). Usable as a shareable URL and as the popover's "view full entry" target.
- [x] Both pages are indexable (no `noindex`, meaningful `<title>` and `<meta description>`, localised).

### Inline popover (Stimulus)

- [x] `app/javascript/controllers/glossary_popover_controller.js` — Stimulus controller bound to wrapped term occurrences.
- [x] `GlossaryHighlighter` helper / ViewComponent wraps matches of known glossary terms in rendered rich-text content with `data-controller="glossary-popover"` and `data-glossary-popover-slug-value="…"`. Matching is case-insensitive; define and document a single strategy for repeats on the same page (e.g., first occurrence only).
- [x] The helper is applied in three surfaces: training-module content, material descriptions, and workshop help/guidance texts. Not applied globally to every Action Text render.
- [x] Activation is **click** only. Trigger is a keyboard-reachable element (Tab to focus, Enter/Space to open); popover is dismissible via Escape and outside click. No hover-activation (touch-device conflicts, selection interference).
- [x] Popover content: term, short definition in the current locale, link to `/glossary/:slug`.
- [x] Visible focus ring on the trigger; popover contents announced to assistive tech via appropriate ARIA (`role`, `aria-labelledby`, focus management on open/close).
- [x] Matching skips content inside code blocks and link anchors (no double-wrapping, no hijacking existing links).

### I18n

- [x] All UI strings (page headings, empty states, popover labels, category names) go through `t(…)`. `en` filled; `es`, `it`, `el` can be stubs.
- [x] Switching the request locale swaps `term`, `definition`, and `examples` per the decided storage.

### Navigation

- [x] Sidebar has a "Glossary" item linking to `/glossary`, visible to all visitors.

### Curator CRUD (admin + facilitator)

- [x] `resources :glossary_terms` in routes, with `new`, `create`, `edit`, `update`, `destroy` guarded by `require_role :admin, :facilitator`. Public `index` / `show` stay open.
- [x] Role-gated affordances on `/glossary` and `/glossary/:slug`: an "Add term" button on the index and per-term "Edit" / "Delete" buttons, rendered only when `current_user&.admin?` or `current_user&.facilitator?`.
- [x] Each term row on the index is a Turbo Frame. "Edit" swaps the frame to an edit form in place; saving renders the updated row; cancel restores the read-only row.
- [x] "Add term" navigates to a dedicated `/glossary_terms/new` page with the full form (not inline).
- [x] The form uses **locale tabs**: the user's current locale is the default-active tab and first in the tab order; remaining locales follow `en → es → it → el`, skipping whichever is current. Unsaved input in inactive tabs is preserved when switching.
- [x] "Delete" opens a Turbo modal confirmation. Confirming destroys the record and removes the row via Turbo Stream. Cancelling closes the modal with no side effects.
- [x] Server-side validation errors render inline within the Turbo Frame / modal — no full-page reload, no flash for field-level errors.
- [x] On successful create / update / destroy, a localised flash communicates the outcome.

### Tests (Minitest — tests gate implementation)

- [x] Model: validations, slug generation, uniqueness, locale-aware readers.
- [x] Request/controller: index renders letters and category pills; category filter narrows the list; unknown slug → 404.
- [x] Helper / component: highlights known terms, ignores terms inside code blocks and link anchors, respects the repeat strategy.
- [x] System test: visit `/glossary`, filter by category, jump by letter; open a popover on a training-module page, dismiss with Escape; switch locale and see translated definition.
- [x] Role guards: unauth visitor and participant cannot hit `new`/`create`/`edit`/`update`/`destroy` (redirect / 403); admin and facilitator can.
- [x] Curator flows (system tests): facilitator edits a term inline (Turbo Frame swap), creates a new term via the dedicated page, deletes a term via the Turbo modal. Participant does not see any curator affordance on the page.
- [x] Locale-tab behaviour: current locale starts active and first; switching tabs preserves unsaved input.

### YARD

- [x] `GlossaryTerm` public methods and the highlighter helper are documented (purpose, params, return). English.

### Docs

- [x] Add a one-liner to `.munkit/MEMORY.md` under **Key Patterns** pointing at the `Translatable` concern, since materials (spec 4) and challenges (spec 6) will follow it.
- [x] If `.munkit/context.md` has stale text about the I18n translatable-fields approach being TBD, update it to reference the JSONB + `Translatable` decision recorded in `DECISIONS.md`.

## Out of Scope

- Approval workflow, soft-delete, or audit log for curator actions — we trust admin and facilitators.
- Automated extraction of glossary terms from training-module markdown (research work, deferred).
- Full-text search or incremental search box — A–Z jumpnav + category pills are sufficient for the initial content volume.
- Cross-linking between related terms ("see also").
- Export (PDF / markdown).

## Dependencies

- Spec 1 (`app-shell-and-navigation`) — layout, sidebar, I18n plumbing, Tailwind tokens, typography.
- Spec 2 (`training-modules`) — needed only as a host surface to prove the popover works in real rich content.

Downstream: materials (spec 4), log entries (spec 11), project-publication (spec 12) will each opt into the glossary popover for their rich text.

## Notes

- The popover is the first reusable Stimulus UI primitive in the app. Keep the controller API generic — material embeds and training references will need similar activation patterns.
- The `Translatable` concern introduced here is precedent-setting: materials and challenges will reuse it. Keep its API minimal and well-documented.
- Consider whether `GlossaryHighlighter` lives as a helper or a `ViewComponent` — Action Text rendering integration points may favor one over the other. Either is defensible; record the choice in `notes.md` when the decision is made.
