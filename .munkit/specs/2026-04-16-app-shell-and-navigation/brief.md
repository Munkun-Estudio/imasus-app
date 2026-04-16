# App Shell and Navigation

## What

Build the shared application shell that every page renders inside: a responsive sidebar navigation with 7 sections, a footer with EU funding notice and partner logos, the IMASUS brand palette as Tailwind tokens, General Sans typography, and the I18n foundation for four locales.

This spec produces the layout skeleton — no feature content yet. Each navigation item lands on an empty placeholder page. The home view already exists (`HomeController#index`) and will render inside the new shell.

## Why

Every subsequent spec nests inside this shell. Building it first means:

- Navigation structure is settled before content is added.
- Tailwind palette tokens are defined once and reused everywhere.
- I18n plumbing is in place so the first feature (training modules) can use `t(...)` from the start, avoiding a retrofit.
- Responsive behaviour (desktop sidebar → mobile top bar) is tested in isolation before complexity grows.

## Acceptance Criteria

- [ ] Application layout wraps all pages in a shell with sidebar navigation and footer.
- [ ] Sidebar has 7 navigation items: Home, Materials DB, Training, Workshops, Log, Prototype, Glossary. Each links to a named route.
- [ ] Active navigation item is visually distinguished.
- [ ] Desktop (≥1024px): fixed left sidebar, main content area fills remaining width.
- [ ] Mobile (<1024px): sidebar collapses to a top bar with a hamburger menu that toggles the sidebar as an overlay. A Stimulus controller handles the open/close toggle.
- [ ] Footer displays: IMASUS project name, EU funding notice (exact text from the Bridgetown site footer — see notes), partner organisations (CSIC, Lottozero, ECHN, Munkun), copyright. Logo assets are sourced from the mockup repo's `public/` directory or the Bridgetown site.
- [ ] Tailwind config defines brand palette tokens: `imasus-dark-green` (#1F3D3F), `imasus-navy` (#252645), `imasus-red` (#FA3449), `imasus-mint` (#AFE0C7), `imasus-light-blue` (#AFCEDE), `imasus-light-pink` (#FFC2D7). No hard-coded hex in templates.
- [ ] General Sans font loaded (with Arial fallback). Applied as the default body font.
- [ ] I18n: `config/locales/` has `en.yml`, `es.yml`, `it.yml`, `el.yml`. At minimum, navigation item labels and the footer text are translated in all four locales.
- [ ] A locale switcher is present in the shell (header or footer) and changes the UI language. Locale is set via a `?locale=` URL param, persisted in a cookie, and restored via an `around_action` in `ApplicationController` that sets `I18n.locale`.
- [ ] Placeholder controller and view exist for each of the 7 sections (home already exists; the other 6 return a heading with the section name).
- [ ] Routes are RESTful where applicable. Named route helpers exist for all 7 sections.
- [ ] Tests cover: shell renders with sidebar and footer; each navigation link resolves; locale switch works; mobile breakpoint behaviour (system test if needed).

## Out of Scope

- Feature content for any section (materials, training, etc.) — those come in their own specs.
- Authentication and role-based navigation visibility — spec 8.
- The "Saved Materials" right rail / drawer — comes with saved-materials spec.
- Paint-swatch / Pantone-chip nav styling from the original whiteboard vision — this is the functional build. Visual refinement can come later.

## Implementation Notes

- The mockup uses a `VerticalNav` component with coloured "swatch" chips. For the Rails build, start with a clean, accessible sidebar using the brand palette. The editorial/swatch aesthetic is a design improvement, not a structural requirement.
- The mockup's `AppShell` provides a useful reference for the three-column layout (sidebar / main / optional right rail), but the right rail slot can be empty until the saved-materials spec.
- Use a Stimulus controller for the mobile menu toggle (open/close sidebar as overlay).
- Locale strategy is decided: `?locale=el` param + cookie persistence + `around_action` in `ApplicationController`. No subdomain routing.
