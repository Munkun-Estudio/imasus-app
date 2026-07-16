# Notes: 2026-07-15-configurable-locales-and-localized-rich-text

## Initial discovery

- `config/application.rb` fixes available locales to `en es it el`; most forms
  correctly ask `I18n.available_locales`, so changing the central source removes
  part of the coupling.
- `Workshop` declares four separate Action Text associations (`agenda_en`,
  `agenda_es`, `agenda_it`, `agenda_el`), and the controller permit list and form
  repeat those names.
- `Material`, `Challenge`, and `GlossaryTerm` use JSONB translations through the
  existing `Translatable` concern but fix English as `BASE_LOCALE`.

## Implemented design

- Installation profiles now provide ordered `locales.available`, `default`,
  `fallback`, and one display label per enabled locale.
- `LocalizedRichText` stores a polymorphic record, field name, and locale, with
  one Action Text `content` association. `HasLocalizedRichText` provides exact
  reads, assignment, deterministic fallback, and missing-content behaviour.
- The expand-first migration copies each existing agenda body and its Active
  Storage attachment references into localized storage while retaining the
  legacy Action Text row. This keeps old app instances readable while Fly runs
  `db:prepare` before replacing them. The down migration syncs the latest
  localized body and attachments back to `agenda_<locale>` before removing the
  new storage.
- Stable public slugs remain untranslated. Workshop slug discovery follows
  configured locale order, while validations that need a source language use
  the configured fallback locale.
- The English-only glossary expression index was removed because a database
  constraint cannot dynamically follow the selected installation profile.
  Case-insensitive source-term uniqueness remains an application validation.
- Training metadata is loaded from the configured fallback chain and exposes
  only enabled locales.

## Verification

- Development migration: four existing agenda rows produced four
  `LocalizedRichText` records while all four deployment-compatibility rows
  remain readable by the previous application version.
- Migration rollback and re-apply both complete successfully.
- Migration test verifies the legacy row remains readable during expansion,
  body and embedded blob references are copied, and post-deploy edits sync back
  into the original row on rollback.
- Configuration tests cover one locale, the existing four-locale IMASUS
  profile, and an additional `fr` locale with configured ordering.
- `rails test`: 859 runs, 3,759 assertions, no failures.
- `rails test:system`: 22 runs, 140 assertions, no failures.
- RuboCop: 205 Ruby files inspected, no offenses.
- Brakeman: zero security warnings.
- Test seed replant completed successfully under the IMASUS profile.
