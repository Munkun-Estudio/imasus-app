# Post-pilot fixes

## What

Fix two clusters of bugs discovered during real-user pilot testing:

1. **Material detail page collapses sections in non-English locales** when a
   facilitator has edited the entry in English. Sections that have no
   translation should fall back to English content instead of disappearing.
2. **Participant-published project page** (`/published/:slug`) has three
   distinct issues:
   - The challenge is rendered as a small "C6"-style code pill instead of the
     full challenge card visitors see on the challenges index.
   - User-uploaded images do not render correctly in some cases.
   - Multi-paragraph text in the process summary sometimes appears as a
     single paragraph.

## Why

Pilot facilitators and participants have started using the app end-to-end. The
material translation regression makes Spanish/Italian/Greek visitors see a
near-empty material page, which undermines the database's value as a shared
multilingual reference. The published project page is the public artefact a
team produces from a workshop — image and paragraph rendering issues plus the
weak challenge framing all degrade the perceived quality of that artefact for
external visitors. These are pilot-feedback fixes, not new features, and should
ship as one tightly-scoped PR.

## Acceptance Criteria

### 1. Material translation fallback

- [ ] On `/materials/:id` in any non-English locale (`es`, `it`, `el`), every
      translatable section that has a value in **either** the current locale
      or English renders, with content displayed in the available language.
- [ ] When a translatable attribute is blank in the current locale (`nil`,
      empty string, or whitespace-only), the section falls back to the
      English value and renders it. Section heading and content both appear.
- [ ] When a translatable attribute is blank in **all** locales, the section
      is hidden entirely (current behaviour preserved).
- [ ] The same fallback rule applies to the meta-description used for the
      page's `<meta name="description">` tag.
- [ ] Fix covers all five translated attributes: `description`,
      `interesting_properties`, `structure`, `sensorial_qualities`,
      `what_problem_it_solves`.
- [ ] Editing a material in one locale does not write empty strings into the
      other locale slots in the JSONB column. Slots that the editor leaves
      blank stay absent (or are removed) rather than being persisted as `""`.
- [ ] Tests cover: (a) read fallback when the current-locale slot is an empty
      string, (b) read fallback when the slot is missing entirely, (c) save
      path does not introduce blank-string slots for other locales.

### 2. Published project — challenge card

- [ ] On `/published/:slug`, the challenge is rendered using the same visual
      challenge card used on the challenges index (`challenges/_card.html.erb`).
- [ ] On the published page, the card's primary click target navigates to
      `/challenges` (the index page), not to the turbo-frame preview drawer.
- [ ] The bookmark toggle is **hidden** when the card is rendered on the
      published page.
- [ ] All other behaviour and content of the card on the challenges index
      remains unchanged (preview drawer, bookmark toggle, color-coded border,
      category pill).
- [ ] The shared partial accepts a clearly-named option to switch between
      these two click/bookmark modes; the published page passes the new mode
      and the challenges index keeps its current default.

### 3. Published project — user-uploaded images

- [ ] Inline images embedded in the participant's process summary render
      correctly on `/published/:slug`: visible, sensible dimensions, not
      broken.
- [ ] When a participant picks a process-log entry with image attachments
      via the publication wizard, those images are persisted into
      `process_summary` and rendered on the published page. The body and
      caption rendering correctly while the images are missing — the
      original symptom — must no longer happen.
- [ ] The hero image continues to render as it does today.
- [ ] A reproduction case is captured in `notes.md` with the minimal
      authoring steps that triggered the bug, so the fix can be verified.

### 4. Published project — paragraph rendering

- [ ] When the stored process-summary HTML contains multiple paragraphs,
      they render visibly separated on `/published/:slug`.
- [ ] When the stored HTML is a single paragraph, content still renders;
      this spec does not retroactively break long single-paragraph blocks
      into multiple paragraphs.
- [ ] The fix is the smallest one that resolves the reported symptom: CSS
      adjustment if `prose` styling is collapsing margins, or a rendering
      adjustment if the issue is in how ActionText output is wrapped.
- [ ] The reproduction case (what the participant typed and what the stored
      HTML looks like) is recorded in `notes.md`.

### Cross-cutting

- [ ] All four fixes ship in **one** Munkit spec and **one** PR.
- [ ] No new translatable strings are introduced beyond those needed by
      the challenge-card reuse (none expected; the card already uses `t(...)`).
- [ ] Each behaviour change is covered by a Minitest test that fails before
      the fix and passes after.

## Out of Scope

- Backfilling existing materials whose JSONB columns already contain
  empty-string slots from prior saves. The read-side fix already handles
  these; cleanup can happen later if needed.
- Rewriting the participant editor to enforce paragraph breaks or sanitize
  uploaded image dimensions at authoring time.
- Adding new images or content surfaces to the published page.
- Changing the challenges index page itself (other than supporting the new
  mode option on the shared card partial).
- Adding analytics or dashboards for pilot feedback.

## Notes

- The translation bug's root cause is the read helper using `_in(locale)`
  with `||` short-circuiting on empty strings (which are truthy). See
  `notes.md` for the diagnosis and proposed fix shape.
- The challenge card on the published page is a public-facing surface for
  anonymous visitors, which is why the bookmark toggle is hidden there.
