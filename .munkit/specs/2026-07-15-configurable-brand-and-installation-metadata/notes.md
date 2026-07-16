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

- Define the smallest semantic token set after inventorying actual roles (brand,
  surface, text, accent, success, warning, danger), not individual current hues.
- Confirm which legal copy is profile content and which clauses belong to the
  reusable software distribution.
