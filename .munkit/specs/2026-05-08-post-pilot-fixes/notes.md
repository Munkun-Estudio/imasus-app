# Notes: 2026-05-08-post-pilot-fixes

Diagnosis, scratch space, and open questions for the post-pilot bug-fix slice.

---

## 1. Material translation fallback — diagnosis

### Symptom

Reproduced from a real user report on
`https://app.imasus.eu/materials/pyratex-musa-1`:

- In `en`: description, sensorial qualities, what-problem-it-solves and
  interesting-properties sections all render with English content.
- In `es`: those four sections (heading + body) are entirely missing from the
  page; only the right-hand sidebar (supplier, availability, raw material,
  tags) survives.

### Root cause

Two read helpers in `app/helpers/materials_helper.rb` bypass the
`Translatable` concern's fallback chain and use `_in(locale)` directly:

```ruby
def material_prose(material, attribute)
  value = material.public_send(:"#{attribute}_in", I18n.locale) ||
          material.public_send(:"#{attribute}_in", Material::BASE_LOCALE)
  return nil if value.to_s.strip.empty?
  ...
end

def material_meta_description(material)
  value = material.description_in(I18n.locale) ||
          material.description_in(Material::BASE_LOCALE)
  ...
end
```

`_in(locale)` returns the raw stored value with no fallback. The `||` falls
through only on `nil`, but the form save path is persisting **empty strings**
into the other locales' JSONB slots when the facilitator edits in English.
An empty string is truthy, so `||` does not fall through, and
`value.to_s.strip.empty?` then makes the helper return `nil` → the show view
silently hides the section (`<% next unless prose %>` at
`app/views/materials/show.html.erb:114`).

The view-side fix is a one-character change per helper:

```ruby
value = material.public_send(:"#{attribute}_in", I18n.locale).presence ||
        material.public_send(:"#{attribute}_in", Material::BASE_LOCALE)
```

### Why fix the save path too

The `Translatable` setter (`translatable.rb:55-59`) writes whatever the form
hands it. If the form posts an empty string for the locale being edited, the
column accumulates `{ "es" => "", "it" => "" }` noise. That noise is the
ultimate cause of the regression — once it's in the column, any read site
that doesn't use `.presence` will trip over it. Two layers of defence:

- **Read side:** treat blank as missing (this spec).
- **Save side:** drop blank values from the incoming hash before merging, so
  the JSONB only contains slots the editor actually filled in.

### Open question — backfill

Existing rows already contain empty-string slots from prior saves. With the
read-side fix, this is harmless: those rows render via the English fallback
correctly. We are explicitly **not** backfilling in this spec; it can be a
small follow-up rake task if the noise becomes a maintenance issue.

---

## 2. Published project — challenge card

### Current state

On `app/views/published_projects/show.html.erb:19-25`, the challenge is a
small uppercase-code pill (just `challenge.code`, e.g. "C6"). On the
challenges index, `app/views/challenges/_card.html.erb` renders a much
richer card: code + category pill, the question as a clickable link, color
band on the left, bookmark toggle.

### Plan

Reuse `app/views/challenges/_card.html.erb` as a shared partial. Add a local
that switches between two modes:

- **Default mode (`mode: :preview`)** — current behaviour: question link uses
  `data-turbo-frame="preview"`, bookmark toggle visible. Used on the
  challenges index.
- **Public mode (`mode: :public`)** — question link goes to
  `challenges_path` (or anchored to the challenge if cheap), no
  `data-turbo-frame` attribute, bookmark toggle hidden. Used on the
  published-project page.

Pass the mode via `render "challenges/card", challenge:, mode: :public` from
the published-project view.

### Open question — link target on public mode

The brief specifies "navigates to `/challenges`". Options:

1. Plain `challenges_path` — simplest, lands at the index top.
2. `challenges_path(anchor: dom_id(challenge))` — index scrolled to that
   challenge, requires the index card to carry the matching DOM id.

Default to option 1 unless option 2 is trivial when implementing.

---

## 3 & 4. Published project — images and paragraphs

### Repro plan

Cannot inspect a real participant's project (no admin access to their data).
Reproduction has to happen locally:

1. Boot dev server, sign in as a participant in a workshop.
2. Create a project, run through publication flow.
3. In the process summary Trix editor:
   - Type two short paragraphs separated by a blank line, save, publish, view
     `/published/:slug` — does the rendered output show two paragraphs?
   - Repeat with a single Enter (line break, not paragraph break).
   - Insert one or two images via Trix's attach button, save, publish, view.
4. Inspect the stored `action_text_rich_texts.body` for each case.

### Hypotheses

**Images**
- Trix stores attachments as `<figure data-trix-attachment="...">` with the
  Active Storage signed id. ActionText resolves them via
  `app/views/active_storage/blobs/_blob.html.erb` (or the default
  `actiontext/contents/_content` template). On the published page, the body
  is rendered with `<%= @project.process_summary %>` inside a `prose` div.
- Likely culprits: missing variant template, `image_variant_tag` not used,
  or the layout's CSP / image proxy preventing the Active Storage redirect
  URL from rendering.

**Paragraphs**
- Trix wraps blocks in `<div>`, not `<p>`. The `prose` Tailwind plugin
  styles `<p>` margins, not generic `<div>`. If the body markup is
  `<div>...</div><div>...</div>` rather than `<p>...</p><p>...</p>`, those
  blocks may visually collapse depending on prose configuration.
- Action Text's default `actiontext/contents/_content.html.erb` wraps the
  body in `<div class="trix-content">`. The combination of `prose` +
  `trix-content` may need a small CSS tweak to give block-level whitespace,
  or we render with `actiontext/content` rather than the bare rich text.

These are hypotheses to verify during repro, not pre-decided fixes.

### Open question — paragraph fix scope

If repro shows the issue is purely cosmetic (block elements without
margins), a CSS-only fix in the published-page view is the right answer.
If repro shows participants are entering content as one logical paragraph,
no rendering change can split it — flag in `notes.md` and don't try to
"fix" it server-side.

---

## Open questions summary

- Backfill of empty-string locale slots: out of scope, revisit if needed.
- Public-mode card link target: `/challenges` vs anchored — pick the
  cheaper option during implementation.
- Paragraph fix: CSS vs content-shape — defer until reproduction is in
  hand.

## Implementation findings (resolved during this spec)

- **Save-side compaction** lives in `Translatable` itself, not in `Material`.
  All models using the concern now drop blank-string locale slots before
  validation via a shared `_compact_translatable_blanks` callback. This
  also fixes the same latent issue for `Tag`, `Challenge`, `GlossaryTerm`,
  and `Workshop`, even though the immediate report was about `Material`.
- **Public-mode card link target** picked option 1: plain `challenges_path`.
  Anchored navigation would have required the index card to render the
  matching DOM id at all viewport sizes; not worth the extra complexity for
  a single visitor click.
- **Curator edit button** is also hidden in `:public` mode on the challenge
  card. The published page is for anonymous visitors; staff who need to edit
  the challenge can do it from the challenges index.
- **Paragraph rendering**: removed the redundant `prose prose-stone max-w-none`
  wrapper around `process_summary`. ActionText already wraps its output in
  `<div class="trix-content">`, and the application stylesheet's `trix-content`
  rules (`> * + * { margin-top: 1rem }`) provide the spacing. Stacking
  `prose` on top introduced no value for `<div>`-based Trix paragraphs and
  risked subtle conflicts.
- **Image rendering**: added scoped CSS for `figure.attachment` inside
  `.trix-content` — clamps `<img>` to container width, centers it, restores
  the figure margins that Tailwind preflight strips, and styles the caption.
  This fixes both "image overflows the column" and "image looks unstyled".
- **Inline images uploaded via the publication wizard's log-entry picker
  were being dropped entirely** (text body of the entry survived, image
  attachments did not). Root cause: `publication_wizard_controller.js` was
  injecting `<action-text-attachment sgid="…">` markup via `editor.loadHTML`,
  but Trix's HTML parser does not recognise that element — `@rails/actiontext`
  only handles upload events, not parser registration — so the attachments
  were silently stripped before form submit. Fix: emit the
  `<figure data-trix-attachment="{json}">` markup that Trix recognises
  natively (the same shape `to_trix_html` produces when re-opening saved
  content). The picker now exposes blob `filesize`, `width`, `height`, and
  `previewable` so the JSON has everything Trix expects.
- **No backfill** of existing materials. The read-side fix already handles
  legacy blank-string slots. New writes will be compacted by the
  `before_validation` callback.

## Follow-up candidates (not in this spec)

- Rake task to scrub blank-string locale slots from existing rows. Optional
  cleanup; not load-bearing now that the read- and save-side fixes are in.
- Editor-side guidance / placeholder for participants on how the published
  page lays out their content.
- Reproduction stayed at the Rails-runner level; before next pilot cycle,
  consider a system test that boots a real browser, attaches a hero image,
  embeds an inline image in Trix, publishes, and asserts both render.
