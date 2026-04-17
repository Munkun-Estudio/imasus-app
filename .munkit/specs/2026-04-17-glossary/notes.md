# Notes: 2026-04-17-glossary

Scratch space for working through this spec. Delete when done.

---

## Decided

Local, spec-scoped decisions. The curator UI block and the JSONB translatable-fields approach have been promoted to `DECISIONS.md`. These remaining choices are implementation-level and reflected directly in the AC in `brief.md`.

- **Category schema:** `category` is a plain string column with an inclusion validation. Initial values: `methodology`, `application`, `industry`, `science`. Kept flexible — a fifth category is a one-line change to the validator, no migration. Rejected alternatives: enum (rigid), `GlossaryCategory` model (overkill for four fixed-ish values).
- **Seed source:** `db/seeds/glossary_terms.yml`. Hand-curated YAML with ≥ 10 entries covering the four categories, `en` filled and at least stub values for `es`, `it`, `el`. Re-running the seed is idempotent (find-or-initialize by slug). Rejected: CSV (bad fit for multi-locale nested values), extraction from training markdown (research work, deferred).
- **Popover scope:** training modules, materials, and workshop help/guidance texts. The helper is applied explicitly in those three surfaces — not globally to every Action Text render — so the rules stay predictable.
- **Popover activation:** click only. Hover was rejected because it creates mobile/tablet conflicts (touch devices emulate hover unreliably) and interferes with text selection on desktop. Focus-activation without click would surprise keyboard users expecting Enter/Space. Click with full keyboard reachability (Tab to focus, Enter/Space to open, Escape to dismiss, outside-click to dismiss) covers pointer, touch, and keyboard cleanly.
- **Highlighter: first occurrence only (per call).** `GlossaryHighlighter` wraps only the first occurrence of each term on the page. Later occurrences render as plain text. Reason: multiple triggers for the same term create visual noise in longer reading flows (training modules can be several screens) and the popover is a reading aid, not a reference index — one entry point per concept is enough. Exposed as a constructor argument (`first_occurrence_only:`) so future surfaces can opt out if needed.
- **Highlighter: longest-match-first on overlap.** The regex sorts term keys by length descending before alternation, so a multi-word term ("Creative Tension Engine") wins over a standalone shorter term ("Engine") appearing inside it. Word-boundary anchors (`\b`) prevent partial-word matches (e.g. "frameworkless" does not trigger "framework").
- **Highlighter: skip ancestors.** Matches are ignored inside `<a>`, `<code>`, and `<pre>`. The XPath excludes descendants of those elements rather than post-filtering, so the pass is one iteration over the eligible text nodes. This avoids hijacking existing links and keeps code samples literal.
- **Highlighter runs AFTER sanitize.** In `training/show.html.erb` we call `glossary_highlight(sanitize(@rendered_body, …))`. Running before sanitize would strip the `data-controller` / `data-glossary-popover-slug-value` attributes we emit. Running after is safe because the button HTML is generated from a controlled template over already-sanitized input: the match text passes through `ERB::Util.html_escape`, and the slug comes from validated DB data, not user input.
- **Delete: Turbo modal, not `data-turbo-confirm`.** The brief explicitly rules out the browser-native confirm dialog. A dedicated `GET /glossary/:slug/delete_confirmation` renders a partial wrapped in `turbo_frame_tag "modal"`, and the layout exposes a top-level `<turbo-frame id="modal">` slot. Dismissal is Escape / backdrop click / Cancel, all via a tiny `modal_controller.js` that clears the frame's `innerHTML`. Accessible, styleable, and consistent with the editorial tone.
- **Locale-tabs form: panels stay in DOM.** Switching tabs toggles `hidden` on panels rather than swapping content. Unsaved input in inactive locales is preserved across tab switches and survives validation re-renders. Keyboard nav (ArrowLeft/Right/Home/End) follows the WAI-ARIA authoring practices for tabs.
- **Popover fetched on first open, cached on the controller instance.** Avoids inlining every term's definition into the document (bad for large training pages) and avoids a fetch per open of the same term. `_open` tracker is a class-level static so opening a new popover auto-closes the previous one.
- **Popover wiring scope: training/show only so far.** The helper is ready to wrap material descriptions and workshop help/guidance copy, but those surfaces don't exist yet in a form that would benefit from it (materials DB is the next spec; workshop help text is a future spec). Leaving the wiring point for those to pick up when they build their content renderers.

## Deferred (flagged by self-review, intentionally not done in this PR)

- **System tests for curator flows** and JS-level tests for locale-tab preservation / Turbo-stream update/destroy branches. The brief's AC lists these; controller-level coverage is in place. A follow-up spec for system-test infrastructure (Capybara + headless Chrome) is the right place since it would set up infra for other specs too.
- **Highlighter caching.** `GlossaryTerm.all.to_a` runs once per request (view-instance memoised). Fine for tens of terms today; revisit with `Rails.cache.fetch(key_with_version: GlossaryTerm.all)` when `log entries` and `material descriptions` start calling the helper and pages render many at once.
- **SQL-driven sort on `/glossary`.** Currently Ruby-side `sort_by`. Brief allows this. Migrate to `order(Arel.sql("LOWER(term_translations->>'en')"))` if the term count grows past a few hundred.
- **Popover HTTP caching.** `GET /glossary/:slug/popover` has no `fresh_when` / `Cache-Control`. One DB hit per open. Optimise if traffic warrants.

## Ideas

-

## Research

-
