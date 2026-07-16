# Notes: 2026-07-15-application-configuration-foundation

## Initial discovery

- Installation assumptions currently enter through `config/application.rb`,
  locale files, helpers, layouts, mailers, JavaScript, `fly.toml`, seed paths,
  and resource-specific model constants.
- The configuration boundary should be introduced with the current values as
  defaults before consumers are migrated in later specs.
- Rails credentials/environment variables already own operational secrets; the
  new contract should reference them, not duplicate them.

## Open questions

- Resolved in `.munkit/DECISIONS.md` on 2026-07-16: strict versioned YAML files
  under `config/profiles`, selected by `APP_PROFILE`, without ERB or nested
  environment overrides.
- The single application API is `Rails.configuration.site`, backed by immutable
  `Data` values. The loader itself has no Rails dependency, so the standalone
  diagnostic can validate a broken profile before application boot.

## Implementation

- `config/profiles/imasus.yml` explicitly captures the current identity, four
  locales, enabled resource modules, content paths, public URLs, and analytics
  script.
- `SiteConfig` rejects unknown/missing keys, unsupported versions, unsafe profile
  names, duplicate or incompatible locales, non-boolean module flags, unsafe or
  missing content directories, invalid URLs, ERB, and secret-like keys.
- `config/application.rb` now derives the existing I18n locale configuration from
  the profile. Other consumers migrate in their focused sprint specs.
- `bin/site-config` prints the effective non-secret configuration and exits 1 for
  invalid profiles.
- Contract, precedence, extension, adopter, and secret-handling guidance lives in
  `docs/configuration.md`.

## Validation

- `bin/site-config`
- Invalid-profile diagnostic exit status
- `bin/rails zeitwerk:check`
- Focused tests: 19 runs, 75 assertions
- Full suite: 838 runs, 3,633 assertions, 0 failures, 0 errors
- RuboCop: no offenses in changed Ruby files
