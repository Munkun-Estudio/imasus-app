# Generic library schema

## What

Define a bounded, generic Library Item domain to replace the IMASUS-specific
Materials schema. Installation content declares item types and their supported
fields, while common searchable, filterable, localized attributes retain a
stable database contract. Migrate every current Material and relationship.

## Why

Materials are the most domain-specific part of the data model: columns,
validations, categories, imports, and assets reflect one catalogue. Reuse requires
flexible cards without turning the application into an unbounded CMS.

## Acceptance Criteria


- [ ] The v1 Library Item contract documents stable identity, item type, localized
  core fields, taxonomy, links, structured custom fields, publication state, and
  audit timestamps.
- [ ] Item-type schemas use a documented finite set of field kinds and validate
  required values, cardinality, localization, and safe rendering constraints.
- [ ] Frequently queried identity, publication, ordering, and taxonomy data remain
  indexable; custom data does not require a database migration per installation.
- [ ] Every current Material, translation, category, project/log reference,
  bookmark, import identity, and attachment migrates without data loss.
- [ ] Compatibility adapters or redirects keep current IMASUS workflows and public
  URLs working during the transition, with a documented rollback path.
- [ ] Migration verification compares record counts, stable IDs, relationships,
  localized values, and attachments before old storage can be retired.

## Out of Scope


- Arbitrary nested page layouts, executable field definitions, or user-defined
  database tables.
- Presentation and asset rendering beyond the compatibility required to verify
  the data migration; that belongs to the following spec.

## Notes

Depends on configuration, locales, and the module registry. Treat the existing
Materials dataset as a migration fixture, not as the generic schema definition.
