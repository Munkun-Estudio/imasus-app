# Notes: 2026-07-15-configurable-brand-and-installation-metadata

## Initial discovery

- Product copy and domains occur in locale files, legal copy, invitation
  fallbacks, controller comments, mail surfaces, metadata, and deployment files.
- The initial audit found `imasus-*` presentation utilities across dozens of
  templates and JavaScript controllers; semantic aliases can provide a staged
  migration while preserving the existing palette.
- `fly.toml` fixes the Fly app and volume names; these are installation examples,
  not values that shared runtime code should infer.

## Open questions

- Resolved in `.munkit/DECISIONS.md` on 2026-07-16: the bounded theme roles are
  `primary`, `secondary`, `accent`, `success`, `info`, and `soft`, emitted as
  validated CSS custom properties and consumed through semantic Tailwind
  utilities.
- Legal clauses remain localized installation content. Reserved I18n
  interpolations (`app_name`, `short_name`, `organization`, `project_url`, and
  `analytics_host`) remove embedded product identity without pretending the
  legal terms themselves are universal.

## Implementation

- The profile now defines metadata description, support URL, logo/mark/email/
  social/favicon assets, six theme roles, and non-secret default sender identity.
- Asset paths are validated at boot. Asset-pipeline names resolve under
  `app/assets/images`; leading-slash paths resolve under `public`. Optional
  values omit their tags and logo surfaces fall back to accessible short-name
  text.
- Application and public layouts, social metadata, navigation logos, footer
  identity/links, mail defaults, broadcast email branding, analytics, production
  fallback host, Active Storage CORS defaults, authentication copy, and legal
  identity use `Rails.configuration.site`.
- All shared `imasus-*` colour utilities were migrated to six semantic
  `brand-*` roles. The IMASUS profile values match the former palette exactly.
- The four locale catalogs now use profile-backed identity placeholders instead
  of embedded product names.
- `docs/branding.md` documents the adopter-facing asset, theme, I18n, mail, and
  optional-service conventions.

## Validation

- Focused branding/configuration/shared-surface tests: 74 runs, 403 assertions
- Full Rails suite: 850 runs, 3,714 assertions, 0 failures, 0 errors
- System suite: 22 runs, 140 assertions, 0 failures, 0 errors
- Seeds replant: workshop, glossary, challenges, tags, and materials succeeded
- RuboCop: 200 files, no offenses
- Brakeman 8.0.4: 0 security warnings (1 existing ignored warning)
- Repository search: no installation name/domain or legacy `imasus-*` colour
  utilities remain in reusable application code
- Local `bin/ci` dependency audit is red because the existing lockfile now has
  newly published advisories. This spec does not update unrelated dependencies;
  GitHub CI regenerates the public dependency lock before auditing.
