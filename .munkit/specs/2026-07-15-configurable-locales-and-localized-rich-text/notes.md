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

## Open questions

- Prototype Action Text storage options and verify attachment migration/rollback
  on a database copy before selecting the design.
- Decide whether translated public slugs are part of v1; stable non-translated
  identifiers are safer for compatibility.
