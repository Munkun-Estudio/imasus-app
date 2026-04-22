# Challenge cards

## What

A public, multilingual catalogue of the ten IMASUS industry challenges (C1–C10)
that participants pick from when scoping project work, plus the **sidebar
information-architecture refactor** that the new Challenges item triggers:

- A `Challenge` model carrying a fixed `code` (`C1`–`C10`), a `category`
  (`material` / `design` / `system` / `business`), and translatable `question`
  and `description` fields.
- A public challenges page at `/challenges` listing all ten challenges grouped
  by category, rendered through a reusable `ChallengeCard` component.
- A sidebar **drawer** at `/challenges/:code/preview` (lowercased code) that
  opens when a card is clicked — challenges are short and meant to be
  skimmed, so there is no standalone show page. See `DECISIONS.md`
  (2026-04-22 — "Challenges are read in a sidebar drawer").
- Curator CRUD for admin and facilitator, following the inline-edit / locale-tabs
  pattern the glossary spec established.
- **Sidebar restructure** to the Hub + Workshops + Resources layout decided on
  2026-04-22 (see `DECISIONS.md`): drops the Log and Prototype placeholders,
  renames none (but reorders), swaps Materials from red to light-blue, groups
  Materials / Training / Challenges / Glossary under a small-caps "Resources"
  label, and slots Challenges in at `04` with the mint swatch.

No authentication required — challenge content is public (see `context.md` —
"Visibility and privacy").

## Why

Challenges are the framing device for every project: a participant creating a
project picks one of the ten challenges as their starting question. Spec 10
(`projects-and-teams`) needs `Challenge` to exist as a real, linkable object
before projects can carry an optional `challenge_id`. This spec stands up that
object and its public surface.

The card component is also a downstream primitive: the home page (spec 7) will
feature challenges, and published project pages (spec 12) will show the
challenge that framed the work. Building the card once, here, is cheaper than
rebuilding it in three places.

The sidebar IA refactor ships alongside because adding Challenges is what
forced the rethink. Doing it as a separate chore would leave this spec briefly
wedged into the old 7-swatch layout with a conceptually misplaced item.
Rationale for the chosen IA is recorded in `DECISIONS.md` (2026-04-22).

## Acceptance Criteria

### Data model

- [ ] `Challenge` with `code`, `category`, and JSONB translatable fields:
      `question_translations`, `description_translations`. Each holds
      `{ en, es, it, el }` keys.
- [ ] Reuse the existing `Translatable` concern (introduced with the glossary
      spec) for locale-aware readers (`question`, `description`) with
      `I18n.fallbacks`. Do not fork or duplicate the concern.
- [ ] `code` is unique, uppercase, matches `/\AC([1-9]|10)\z/`. It is the
      URL-facing identifier (lowercased in routes).
- [ ] `category` is a string column; inclusion validation against
      `%w[material design system business]`.
- [ ] Validations: presence and format of `code`; case-insensitive uniqueness
      of `code`; presence and inclusion of `category`; presence of base-locale
      (`en`) `question` and `description`.
- [ ] Default ordering by numeric part of `code` (so `C2` comes before `C10`).

### Seed

- [ ] `db/seeds/challenges.yml` holds all ten challenges with placeholder
      `en` content drawn from the WIP DOCX/PDF brief (context.md — "Content
      sources"), plus stub `es`/`it`/`el` values to exercise the pipeline.
      Placeholder copy is acceptable; the real text will replace it once the
      source document is finalised.
- [ ] A seed loader reads the YAML and is idempotent (find-or-initialize by
      `code`).
- [ ] Category assignment across the ten challenges is recorded in the YAML
      and covers all four categories.

### Public pages

- [ ] `GET /challenges` renders the index: challenges grouped into four
      sections by `category`, in a stable category order
      (`material → design → system → business`). Each section shows its
      challenges via the `ChallengeCard` component.
- [ ] Empty categories (none expected in the seed) are hidden rather than
      shown as empty headers.
- [ ] `GET /challenges/:code/preview` renders the drawer partial into the
      layout's `<turbo-frame id="preview">` slot (no application layout).
      Renders code, category label, localised question (prominent), and
      localised description. Dismissed via the existing
      `preview_sidebar_controller` (Escape, backdrop, close button).
- [ ] Lookup is case-insensitive on `code`. Unknown code → 404.
- [ ] No standalone `GET /challenges/:code` show page. Deep-linking to a
      single challenge is deferred; see `DECISIONS.md` (2026-04-22).

### `ChallengeCard` component

- [ ] A reusable ERB partial at `app/views/challenges/_card.html.erb`
      (the app has no `view_component` gem; glossary's partial-based
      approach is the established pattern). Takes a `Challenge` and renders:
      `code`, category label, localised `question`, and a link to the
      challenge page. The card is the whole clickable surface.
- [ ] Visually distinguishes category via the following palette mapping,
      using IMASUS tokens from spec 1 (no reds, per 2026-04-22 decision):
      - `material` → dark-green
      - `design` → navy
      - `system` → light-blue
      - `business` → light-pink
      Treatment should feel like "lighter siblings of the sidebar palette" —
      subtle tints or accent bars, not fills so heavy that the card
      competes with the sidebar swatches. No novelty decoration.
- [ ] Keyboard reachable with a visible focus ring; link target is the full
      card, but nested interactive elements (if added later) keep their own
      focus order.
- [ ] Used by `GET /challenges`. Reserved for reuse by the home page
      (spec 7) and published project pages (spec 12) — do not inline the
      markup elsewhere.

### I18n

- [ ] All UI strings (page headings, category labels, empty states, curator
      affordances) go through `t(…)`. `en` filled; `es`, `it`, `el` can be
      stubs.
- [ ] Switching the request locale swaps `question` and `description` per the
      `Translatable` concern's behaviour.
- [ ] Category labels are translated via `t(…)` keyed on the category string.

### Sidebar IA refactor

- [ ] `nav_items` in `app/helpers/application_helper.rb` is restructured
      into the six-item layout:
      - `00 home` — white/bordered *(unchanged)*
      - `01 workshops` — `bg-imasus-dark-green` *(colour unchanged, position
        moves from 03 to 01)*
      - `02 materials` — `bg-imasus-light-blue` *(was `bg-imasus-red`)*
      - `03 training` — `bg-imasus-navy` *(unchanged)*
      - `04 challenges` — `bg-imasus-mint` *(new; mint freed up by Prototype
        drop)*
      - `05 glossary` — `bg-imasus-light-pink` *(unchanged)*
- [ ] Sidebar partial (`app/views/shared/_sidebar.html.erb`) renders a
      small-caps **Resources** label above the Materials → Glossary block.
      The label itself is a static string (translatable via
      `t("nav.resources_group")`), not an interactive item.
- [ ] `log` and `prototype` placeholder routes, controllers, views, i18n
      keys, and controller tests are removed. Specifically:
      - `config/routes.rb` — drop `resources :prototype, only: :index` and
        the equivalent `log` resource.
      - `app/controllers/prototype_controller.rb`,
        `app/controllers/log_controller.rb` — removed.
      - `app/views/prototype/`, `app/views/log/` — removed.
      - `config/locales/{en,es,it,el}.yml` — drop `nav.log` and
        `nav.prototype` keys.
      - `test/controllers/prototype_controller_test.rb`,
        `test/controllers/log_controller_test.rb` — removed.
      - `test/integration/shell_layout_test.rb` — updated to assert the new
        six-item layout and Resources label, not the old seven-item one.
- [ ] `swatch_dark_bg?` in `application_helper.rb` is reviewed against the
      new palette assignments — light-blue on Materials means the helper
      should still flag `navy` + `dark-green` as dark (unchanged); confirm
      by test.
- [ ] Sidebar visual acceptance: dividers/spacing distinguish the three
      zones (Hub, Community, Resources) even without interactive chrome;
      the Resources label is readable but visually subordinate to the nav
      swatches themselves.

### Challenges navigation item

- [ ] "Challenges" links to `/challenges`; visible to all visitors;
      reachable by keyboard with the same focus/active treatment as other
      nav items.

### Curator CRUD (admin + facilitator)

- [ ] `resources :challenges, only: [:index, :edit, :update], param: :code`
      plus a `member { get :preview }` route. `edit` and `update` guarded by
      `require_role :admin, :facilitator`. Public `index` and `preview` stay
      open. **No `new`, `create`, or `destroy`** — the challenge set is
      fixed at ten; accidental deletion or creation would be worse than
      editing.
- [ ] Role-gated affordances on the `/challenges` index and inside the
      preview drawer: an "Edit" button on each card and inside the drawer,
      rendered only when `curator?` returns true. No "Add challenge"
      affordance on the index — the ten are seeded.
- [ ] Editing uses the same inline Turbo Frame pattern as glossary: the card
      swaps to an edit form in place; saving renders the updated card;
      cancel restores the read-only card.
- [ ] The form uses the established **locale tabs** pattern from glossary and
      materials: current locale default-active and first, remaining locales
      in `en → es → it → el` order. Unsaved input in inactive tabs preserved.
- [ ] Server-side validation errors render inline within the Turbo Frame —
      no full-page reload, no flash for field-level errors.
- [ ] On successful update, a localised flash communicates the outcome.

### Tests (Minitest — tests gate implementation)

- [ ] Model: validations (code format, uniqueness, category inclusion),
      locale-aware readers, numeric ordering by `code`.
- [ ] Seed loader: idempotent; running twice leaves ten challenges.
- [ ] Request/controller: index groups by category; unknown code → 404;
      show renders localised content and switches with locale.
- [ ] Component (partial): renders code, category label, localised question,
      and a link to the challenge page; is the full clickable surface;
      applies the correct per-category palette token.
- [ ] Role guards: unauth visitor and participant cannot hit
      `new`/`create`/`edit`/`update` (redirect / 403); admin and facilitator
      can.
- [ ] Curator flow (system test): facilitator edits a challenge inline
      (Turbo Frame swap), saves, sees updated card. Participant does not see
      any curator affordance.
- [ ] Locale-tab behaviour: current locale starts active and first;
      switching tabs preserves unsaved input.
- [ ] Sidebar IA test (integration): the sidebar renders six items in the
      agreed order with the agreed palette classes; the Resources label
      appears above Materials; no `log` or `prototype` items or routes
      exist. Update `test/integration/shell_layout_test.rb` accordingly.

### YARD

- [ ] `Challenge` public methods and the `ChallengeCard` component are
      documented (purpose, params, return). English.

### Docs

- [ ] Mark spec 6 ✅ in `.munkit/context.md` "Implementation Plan" once
      merged.
- [ ] The sidebar IA pattern is already recorded in `.munkit/MEMORY.md`
      and `.munkit/DECISIONS.md` (2026-04-22). Review both when merging to
      confirm the implemented reality matches the recorded decisions; fix
      either side if they drift.
- [ ] If the `ChallengeCard` introduces a reusable pattern (e.g. a shared
      "record card" base), add a one-liner to `.munkit/MEMORY.md` under
      **Key Patterns**.

## Out of Scope

- Real challenge copy — the WIP DOCX/PDF is not final. Placeholder `en`
  content plus locale stubs is enough for this spec; content replacement is
  a separate data task.
- Adding or removing challenges — the set is fixed at ten. No `new` /
  `destroy` curator actions.
- Cross-linking between challenges and materials, training modules, or
  glossary terms. Those relationships land with projects (spec 10) and
  process log (spec 11).
- Tagging, filtering by property, or search. Four categories × ten
  challenges do not need it.
- Challenge imagery / hero visuals. If later needed, they slot in once the
  image-hosting strategy (spec 3) is fully bedded in on another content
  type.
- Evaluation, scoring, or recommending challenges to participants.
- Role-aware Home (dashboard) — specified in `DECISIONS.md` (2026-04-22)
  and belongs to spec 7 (`home-page`). This spec only removes the old
  Log/Prototype *top-level* surfaces; it does not build the dashboard
  surface that eventually replaces the "Your work" role they hinted at.

## Dependencies

- Spec 1 (`app-shell-and-navigation`) — layout, sidebar, I18n plumbing,
  Tailwind tokens, typography. This spec materially changes spec 1's
  sidebar deliverable; decision recorded separately in `DECISIONS.md`
  (2026-04-22), not a retroactive edit of spec 1.
- Spec 5 (`glossary`) — `Translatable` concern, locale-tabs form pattern,
  inline Turbo-Frame edit pattern, ERB-partial component convention.

Downstream:

- Spec 7 (`home-page`) — featured challenges reuse the `_card.html.erb`
  partial; also inherits the role-aware dashboard scope from the
  2026-04-22 decision.
- Spec 10 (`projects-and-teams`) — `Project` optionally `belongs_to
  :challenge`.
- Spec 12 (`project-publication`) — published project page shows the
  framing challenge, reuses the `_card.html.erb` partial.
