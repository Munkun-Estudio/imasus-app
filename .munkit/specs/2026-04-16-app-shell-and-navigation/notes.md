# App Shell and Navigation — Notes

Implementation notes, discoveries, and scratch space. Update as work progresses.

## References

- Mockup `AppShell.tsx`, `VerticalNav.tsx`, `Footer.tsx` in `/Users/pablo/projects/imasus_app_mockup/src/components/`
- Mockup `tailwind.config.js` for palette token names
- Brand palette from design brief: Dark Green #1F3D3F, Navy #252645, Red #FA3449, Mint #AFE0C7, Light Blue #AFCEDE, Light Pink #FFC2D7

## Resolved: Font Hosting

General Sans is not on Google Fonts. **Self-hosted** from `app/assets/fonts/` — woff2 files (light 300, medium 500, bold 700) copied from the Bridgetown site at `/Users/pablo/projects/imasus/frontend/fonts/general-sans/`. Declared via `@font-face` in `app/assets/tailwind/application.css` and set as default `--font-sans` in the Tailwind `@theme` block.

## Resolved: EU Funding Notice

Used the official Erasmus+ disclaimer from the Bridgetown training modules `about.md`: "Funded by the European Union. Views and opinions expressed are however those of the author(s) only and do not necessarily reflect those of the European Union or the European Education and Culture Executive Agency (EACEA). Neither the European Union nor EACEA can be held responsible for them." Translated into all 4 locales.

## Partner Logos

Copied from Bridgetown site `src/images/partners/` to `app/assets/images/`: INMA (CSIC), Lottozero, ECHN, Munkun. EU funded badge from `src/images/EU_funded.png`.

## Implementation Decisions

- **Tailwind CSS v4** installed via `tailwindcss-rails` gem. Brand palette tokens defined in `@theme` block (CSS-based config, no JS config file).
- **Mobile nav:** hamburger menu with overlay sidebar. Z-index stack: backdrop z-30, header z-40, sidebar z-50.
- **Locale strategy:** `?locale=` param + cookie persistence + `around_action :set_locale` in `ApplicationController`. Falls back to `I18n.default_locale` (:en).
- **Routes:** `resources :X, only: :index` for all 6 placeholder sections. Named helpers: `materials_path`, `training_index_path`, `workshops_path`, `log_index_path`, `prototype_index_path`, `glossary_index_path`.
- **Active nav item:** `nav-active` CSS class applied via `ApplicationHelper#nav_link_classes` using `current_page?`.
- **Sidebar partial:** `shared/_sidebar.html.erb` with inline SVG icons (Heroicons mini).
- **Footer partial:** `shared/_footer.html.erb` with gradient background, EU notice, partner names, copyright.

## Replaced Custom CSS

The original landing page used custom CSS variables and hand-written styles in `application.css`. These were replaced by Tailwind utility classes. The old `application.css` is now a stub for any future non-Tailwind styles.
