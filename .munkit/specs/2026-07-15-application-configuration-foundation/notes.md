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

- Choose the configuration serialization and validation mechanism during this
  spec, then record the choice in `.munkit/DECISIONS.md` before implementation.
- Decide whether profile selection is a file path, profile name, or both after
  checking deployment and test ergonomics.
