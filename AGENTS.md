# Contributor Agent Instructions

This is a reusable Rails application for collaborative workshops. Keep shared
code installation-neutral: organisation identity, enabled resource modules,
locales, and editorial content belong in versioned profiles and manifests.

## Read First

- `README.md` for the product and local setup.
- `CONTRIBUTING.md` for the contribution workflow.
- `docs/configuration.md` for the installation-profile contract.
- `docs/adoption.md` before changing adopter-facing defaults.
- `docs/deployment.md` before changing runtime configuration.

## Engineering Conventions

- Prefer Rails conventions and existing dependencies.
- Add or update Minitest coverage before changing shared behaviour.
- Keep user-facing strings translated through `I18n`.
- Use semantic brand tokens rather than installation-specific colours in shared
  views.
- Keep credentials and environment-specific values outside the repository.
- Preserve stable IDs and URLs during schema or content migrations.

## Git and Validation

- Use one focused branch per worktree and avoid overlapping edits.
- Keep pull requests small and explain the user impact and validation performed.
- Run targeted tests while iterating and `bin/ci` for cross-cutting changes.
- Do not commit generated assets, local databases, uploads, logs, or secrets.
